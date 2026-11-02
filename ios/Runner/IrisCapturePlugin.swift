import ARKit
import CoreImage
import Flutter
import ImageIO
import UIKit

/// Captura guiada de localizaciones (F6.20 E6): fotos con la posición de
/// ARKit en metros, para que RealityScan en el PC saque el escaneo a escala
/// real y nivelado. Funciona sin LiDAR (seguimiento visual-inercial).
///
/// Deja una carpeta `<nombre>.iriscapture` con las fotos y `capture.json`
/// (ver `lib/features/camera_plan/rig/scan_capture.dart`) y la devuelve
/// comprimida en `.zip`.
final class IrisCapturePlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "iris/capture",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(IrisCapturePlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      result(ARWorldTrackingConfiguration.isSupported)
    case "start":
      let args = call.arguments as? [String: Any]
      let name = (args?["name"] as? String) ?? "Localización"
      start(name: name, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func start(name: String, result: @escaping FlutterResult) {
    guard ARWorldTrackingConfiguration.isSupported,
      let root = Self.topController()
    else {
      result(nil)
      return
    }
    let capture = IrisCaptureViewController(name: name) { path in
      result(path)
    }
    capture.modalPresentationStyle = .fullScreen
    root.present(capture, animated: true)
  }

  private static func topController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    var top = scenes.flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }
}

/// Una foto hecha: dónde estaba la cámara (para la guía) y lo que va al
/// `capture.json`.
private struct Shot {
  let position: simd_float3
  let forward: simd_float3
  let json: [String: Any]
}

final class IrisCaptureViewController: UIViewController, ARSessionDelegate {
  private let name: String
  private let onDone: (String?) -> Void
  private let sceneView = ARSCNView()
  private let warning = UILabel()
  private let counter = UILabel()
  private let map = CaptureMapView()
  private let ring = CoverageRingView()
  private var shots: [Shot] = []
  private var folder: URL?
  private var busy = false
  private var lastShotTime: TimeInterval = 0
  private var lastPose: (time: TimeInterval, transform: simd_float4x4)?
  private var angularSpeed: Float = 0
  private var finished = false

  /// Una foto nueva si no hay otra a menos de 15 cm y 12°.
  private let minMove: Float = 0.15
  private let minTurn: Float = 12 * .pi / 180
  /// Por encima de esto, la foto sale movida.
  private let maxAngularSpeed: Float = 0.6

  init(name: String, onDone: @escaping (String?) -> Void) {
    self.name = name
    self.onDone = onDone
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) { fatalError("no se usa") }

  override var prefersStatusBarHidden: Bool { true }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black
    sceneView.frame = view.bounds
    sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    sceneView.session.delegate = self
    sceneView.debugOptions = [.showFeaturePoints]
    sceneView.automaticallyUpdatesLighting = false
    view.addSubview(sceneView)

    warning.font = .systemFont(ofSize: 17, weight: .semibold)
    warning.textColor = .white
    warning.numberOfLines = 0
    warning.textAlignment = .center
    warning.backgroundColor = UIColor.black.withAlphaComponent(0.55)
    warning.layer.cornerRadius = 10
    warning.clipsToBounds = true

    counter.font = .monospacedDigitSystemFont(ofSize: 15, weight: .medium)
    counter.textColor = .white

    map.backgroundColor = UIColor.black.withAlphaComponent(0.55)
    map.layer.cornerRadius = 10
    map.clipsToBounds = true
    ring.backgroundColor = .clear

    let cancel = Self.button("Cancelar", filled: false)
    cancel.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
    let shoot = Self.button("Foto", filled: false)
    shoot.addTarget(self, action: #selector(shootTapped), for: .touchUpInside)
    let done = Self.button("Terminar", filled: true)
    done.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
    let buttons = UIStackView(arrangedSubviews: [cancel, shoot, done])
    buttons.spacing = 12
    buttons.distribution = .fillEqually

    for v in [warning, counter, map, ring, buttons] as [UIView] {
      v.translatesAutoresizingMaskIntoConstraints = false
      view.addSubview(v)
    }
    let g = view.safeAreaLayoutGuide
    NSLayoutConstraint.activate([
      warning.topAnchor.constraint(equalTo: g.topAnchor, constant: 12),
      warning.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 16),
      warning.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -16),
      warning.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
      counter.topAnchor.constraint(equalTo: warning.bottomAnchor, constant: 8),
      counter.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 16),
      ring.centerXAnchor.constraint(equalTo: g.centerXAnchor),
      ring.centerYAnchor.constraint(equalTo: g.centerYAnchor),
      ring.widthAnchor.constraint(equalToConstant: 180),
      ring.heightAnchor.constraint(equalToConstant: 180),
      map.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -16),
      map.bottomAnchor.constraint(equalTo: buttons.topAnchor, constant: -12),
      map.widthAnchor.constraint(equalToConstant: 150),
      map.heightAnchor.constraint(equalToConstant: 150),
      buttons.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 16),
      buttons.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -16),
      buttons.bottomAnchor.constraint(equalTo: g.bottomAnchor, constant: -12),
      buttons.heightAnchor.constraint(equalToConstant: 50),
    ])
    show("Recorre el sitio despacio. Las fotos se hacen solas.")
    updateCounter()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    UIApplication.shared.isIdleTimerDisabled = true
    let config = ARWorldTrackingConfiguration()
    config.planeDetection = [.horizontal, .vertical]
    config.isLightEstimationEnabled = true
    if let best = ARWorldTrackingConfiguration.recommendedVideoFormatForHighResolutionFrameCapturing {
      config.videoFormat = best
    }
    sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    UIApplication.shared.isIdleTimerDisabled = false
    sceneView.session.pause()
  }

  private static func button(_ title: String, filled: Bool) -> UIButton {
    var c = filled ? UIButton.Configuration.filled() : UIButton.Configuration.gray()
    c.title = title
    c.cornerStyle = .large
    return UIButton(configuration: c)
  }

  // MARK: - Sesión

  func session(_ session: ARSession, didUpdate frame: ARFrame) {
    let t = frame.camera.transform
    if let last = lastPose {
      let dt = Float(frame.timestamp - last.time)
      if dt > 0 {
        let a = simd_quatf(t), b = simd_quatf(last.transform)
        let turned: Float = (a * b.inverse).angle
        let speed: Float = turned / dt
        angularSpeed = 0.7 * angularSpeed + 0.3 * speed
      }
    }
    lastPose = (frame.timestamp, t)

    let position = simd_make_float3(t.columns.3)
    let forward = -simd_make_float3(t.columns.2)
    map.update(
      position: position,
      forward: forward,
      shots: shots.map { ($0.position, $0.forward) },
      points: frame.rawFeaturePoints?.points ?? [],
      walls: frame.anchors.compactMap { anchor in
        guard let plane = anchor as? ARPlaneAnchor, plane.alignment == .vertical else {
          return nil
        }
        let half = plane.planeExtent.width / 2
        let m = plane.transform
        let centre = simd_make_float3(m * simd_float4(plane.center, 1))
        let axis = simd_normalize(simd_make_float3(m.columns.0))
        return (centre - axis * half, centre + axis * half)
      }
    )
    let covered = coveredSectors(near: position)
    ring.update(covered: covered, heading: atan2(forward.x, -forward.z))

    let message = guidance(frame: frame, covered: covered, forward: forward)
    show(message)
    if message == nil, shouldShoot(position: position, forward: forward, time: frame.timestamp) {
      shoot(session: session)
    }
  }

  /// Lo que hay que decir, o `nil` si todo va bien.
  private func guidance(frame: ARFrame, covered: [Bool], forward: simd_float3) -> String? {
    switch frame.camera.trackingState {
    case .notAvailable:
      return "Seguimiento perdido: vuelve a una zona que ya hayas visto."
    case .limited(let reason):
      switch reason {
      case .excessiveMotion: return "Más despacio."
      case .insufficientFeatures: return "Apunta a zonas con más detalle o acércate."
      case .initializing, .relocalizing: return "Mueve el móvil despacio de lado a lado."
      @unknown default: return "Seguimiento limitado: mueve el móvil despacio."
      }
    case .normal:
      break
    }
    if angularSpeed > maxAngularSpeed { return "Más despacio: las fotos saldrían movidas." }
    if let light = frame.lightEstimate, light.ambientIntensity < 250 {
      return "Poca luz: enciende las luces de trabajo."
    }
    if (frame.rawFeaturePoints?.points.count ?? 0) < 40 {
      return "Apunta a zonas con más detalle o acércate."
    }
    if shots.count >= 20 {
      let ys = shots.map(\.position.y)
      if (ys.max() ?? 0) - (ys.min() ?? 0) < 0.25 {
        return "Sube y baja el móvil: haz otra vuelta más alta o más baja."
      }
    }
    // Con fotos alrededor, lo que falta de la vuelta.
    let done = covered.filter { $0 }.count
    if done >= 3, done < covered.count {
      let heading = atan2(forward.x, -forward.z)
      if let side = CoverageRingView.missingSide(covered: covered, heading: heading) {
        return side < 0 ? "Gira a la izquierda: falta esa parte." : "Gira a la derecha: falta esa parte."
      }
    }
    return nil
  }

  /// Sectores de 30° con alguna foto hecha a menos de 1 m de aquí.
  private func coveredSectors(near position: simd_float3) -> [Bool] {
    var out = [Bool](repeating: false, count: 12)
    for s in shots where simd_distance(s.position, position) < 1 {
      let a = atan2(s.forward.x, -s.forward.z)
      out[CoverageRingView.sector(of: a, count: out.count)] = true
    }
    return out
  }

  private func shouldShoot(position: simd_float3, forward: simd_float3, time: TimeInterval) -> Bool {
    if busy || time - lastShotTime < 0.35 { return false }
    for s in shots {
      let close = simd_distance(s.position, position) < minMove
      let turn = acos(max(-1, min(1, simd_dot(s.forward, forward))))
      if close && turn < minTurn { return false }
    }
    return true
  }

  // MARK: - Fotos

  @objc private func shootTapped() {
    shoot(session: sceneView.session)
  }

  private func shoot(session: ARSession) {
    guard !busy, let folder = ensureFolder() else { return }
    busy = true
    lastShotTime = session.currentFrame?.timestamp ?? lastShotTime
    session.captureHighResolutionFrame { [weak self] highRes, _ in
      // La respuesta no llega por fuerza en el hilo principal.
      DispatchQueue.main.async { self?.store(highRes ?? session.currentFrame, in: folder) }
    }
  }

  /// Guarda la foto (en segundo plano) y, si sale bien, su pose.
  private func store(_ frame: ARFrame?, in folder: URL) {
    guard let frame, case .normal = frame.camera.trackingState else {
      busy = false
      return
    }
    let file = String(format: "f_%05d.jpg", shots.count + 1)
    let camera = frame.camera
    let buffer = frame.capturedImage
    let timestamp = frame.timestamp
    DispatchQueue.global(qos: .userInitiated).async {
      let ok = Self.writeJpeg(buffer, to: folder.appendingPathComponent(file))
      DispatchQueue.main.async {
        defer { self.busy = false }
        guard ok else { return }
        let t = camera.transform
        let k = camera.intrinsics
        let flat = [t.columns.0, t.columns.1, t.columns.2, t.columns.3]
          .flatMap { [Double($0.x), Double($0.y), Double($0.z), Double($0.w)] }
        self.shots.append(
          Shot(
            position: simd_make_float3(t.columns.3),
            forward: -simd_make_float3(t.columns.2),
            json: [
              "file": file,
              "transform": flat,
              // fx, fy, cx, cy: la matriz de ARKit va por columnas.
              "intrinsics": [
                Double(k.columns.0.x), Double(k.columns.1.y),
                Double(k.columns.2.x), Double(k.columns.2.y),
              ],
              "width": Int(camera.imageResolution.width),
              "height": Int(camera.imageResolution.height),
              "t": timestamp,
            ]))
        self.updateCounter()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
      }
    }
  }

  /// La imagen del sensor tal cual (horizontal): las intrínsecas y la pose
  /// de ARKit están en esa orientación.
  private static func writeJpeg(_ buffer: CVPixelBuffer, to url: URL) -> Bool {
    let image = CIImage(cvPixelBuffer: buffer)
    let context = CIContext()
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
      let data = context.jpegRepresentation(
        of: image, colorSpace: space,
        options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.92])
    else { return false }
    return (try? data.write(to: url)) != nil
  }

  private func ensureFolder() -> URL? {
    if let folder { return folder }
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let stamp = ISO8601DateFormatter().string(from: Date())
      .replacingOccurrences(of: ":", with: "")
    let clean = name.components(separatedBy: CharacterSet(charactersIn: "/\\:?*\"<>|")).joined()
    let url = docs.appendingPathComponent("IRIS Capturas", isDirectory: true)
      .appendingPathComponent("\(clean) \(stamp).iriscapture", isDirectory: true)
    do {
      try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    } catch {
      return nil
    }
    folder = url
    return url
  }

  // MARK: - Interfaz

  private func show(_ text: String?) {
    let value = text ?? "Bien. Sigue recorriendo despacio."
    if warning.text != " \(value) " { warning.text = " \(value) " }
    warning.backgroundColor = text == nil
      ? UIColor.systemGreen.withAlphaComponent(0.55)
      : UIColor.systemOrange.withAlphaComponent(0.75)
  }

  private func updateCounter() {
    counter.text = shots.count == 1 ? "1 foto" : "\(shots.count) fotos"
  }

  @objc private func cancelTapped() {
    finish(path: nil)
  }

  @objc private func doneTapped() {
    guard let folder, !shots.isEmpty else {
      finish(path: nil)
      return
    }
    sceneView.session.pause()
    show("Guardando…")
    let manifest: [String: Any] = [
      "version": 1,
      "device": Self.deviceModel(),
      "system": UIDevice.current.systemVersion,
      "frames": shots.map(\.json),
    ]
    DispatchQueue.global(qos: .userInitiated).async {
      var path: String? = folder.path
      if let data = try? JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted]) {
        try? data.write(to: folder.appendingPathComponent("capture.json"))
        path = Self.zip(folder)?.path ?? folder.path
      }
      DispatchQueue.main.async { self.finish(path: path) }
    }
  }

  /// Comprime la carpeta con el coordinador de archivos del sistema (sin
  /// librerías): da un .zip junto a la carpeta.
  private static func zip(_ folder: URL) -> URL? {
    var out: URL?
    var error: NSError?
    NSFileCoordinator().coordinate(readingItemAt: folder, options: [.forUploading], error: &error) { tmp in
      let dest = folder.deletingPathExtension().appendingPathExtension("iriscapture.zip")
      try? FileManager.default.removeItem(at: dest)
      if (try? FileManager.default.copyItem(at: tmp, to: dest)) != nil { out = dest }
    }
    return out
  }

  private static func deviceModel() -> String {
    var info = utsname()
    uname(&info)
    return withUnsafeBytes(of: &info.machine) { raw in
      String(decoding: raw.prefix(while: { $0 != 0 }), as: UTF8.self)
    }
  }

  private func finish(path: String?) {
    guard !finished else { return }
    finished = true
    dismiss(animated: true) { self.onDone(path) }
  }
}

/// Minimapa cenital: recorrido, fotos con su dirección, puntos vistos y
/// paredes detectadas (planos verticales).
final class CaptureMapView: UIView {
  private var position = simd_float3()
  private var forward = simd_float3(0, 0, -1)
  private var shots: [(simd_float3, simd_float3)] = []
  private var points: [simd_float3] = []
  private var walls: [(simd_float3, simd_float3)] = []

  func update(
    position: simd_float3, forward: simd_float3,
    shots: [(simd_float3, simd_float3)], points: [simd_float3],
    walls: [(simd_float3, simd_float3)]
  ) {
    self.position = position
    self.forward = forward
    self.shots = shots
    // Se guardan como mucho 4000 puntos vistos.
    self.points.append(contentsOf: points.prefix(60))
    if self.points.count > 4000 { self.points.removeFirst(self.points.count - 4000) }
    self.walls = walls
    setNeedsDisplay()
  }

  override func draw(_ rect: CGRect) {
    guard let ctx = UIGraphicsGetCurrentContext() else { return }
    // Centrado en la cámara; 6 m de lado.
    let scale = rect.width / 6
    func pt(_ v: simd_float3) -> CGPoint {
      CGPoint(
        x: rect.midX + CGFloat(v.x - position.x) * scale,
        y: rect.midY + CGFloat(v.z - position.z) * scale)
    }
    ctx.setFillColor(UIColor.white.withAlphaComponent(0.35).cgColor)
    for p in points {
      let c = pt(p)
      ctx.fill(CGRect(x: c.x - 0.75, y: c.y - 0.75, width: 1.5, height: 1.5))
    }
    ctx.setStrokeColor(UIColor.systemYellow.cgColor)
    ctx.setLineWidth(2.5)
    for (a, b) in walls {
      ctx.move(to: pt(a))
      ctx.addLine(to: pt(b))
    }
    ctx.strokePath()
    ctx.setStrokeColor(UIColor.systemGreen.withAlphaComponent(0.8).cgColor)
    ctx.setLineWidth(1)
    for (p, f) in shots {
      ctx.move(to: pt(p))
      ctx.addLine(to: pt(p + f * 0.4))
    }
    ctx.strokePath()
    let me = pt(position)
    ctx.setFillColor(UIColor.systemBlue.cgColor)
    ctx.fillEllipse(in: CGRect(x: me.x - 4, y: me.y - 4, width: 8, height: 8))
    ctx.setStrokeColor(UIColor.systemBlue.cgColor)
    ctx.setLineWidth(2)
    ctx.move(to: me)
    ctx.addLine(to: pt(position + forward * 0.6))
    ctx.strokePath()
  }
}

/// Anillo de 360° alrededor de donde estás: en verde las direcciones ya
/// fotografiadas desde aquí; arriba es hacia donde miras.
final class CoverageRingView: UIView {
  private var covered = [Bool](repeating: false, count: 12)
  private var heading: Float = 0

  func update(covered: [Bool], heading: Float) {
    self.covered = covered
    self.heading = heading
    setNeedsDisplay()
  }

  /// El sector (de [count]) en el que cae el ángulo [angle], en radianes.
  /// Por pasos y con tipos: en una sola expresión el compilador de Swift
  /// no termina de deducirlos.
  static func sector(of angle: Float, count: Int) -> Int {
    let turn: Float = 2 * Float.pi
    var a: Float = angle.truncatingRemainder(dividingBy: turn)
    if a < 0 { a += turn }
    let index = Int(a / turn * Float(count))
    return min(max(index, 0), count - 1)
  }

  /// Hacia qué lado girar para el hueco más cercano: −1 izquierda, 1
  /// derecha, `nil` si no hay hueco.
  static func missingSide(covered: [Bool], heading: Float) -> Int? {
    let n = covered.count
    let here = sector(of: heading, count: n)
    for step in 1...(n / 2) {
      if !covered[(here + step) % n] { return 1 }
      if !covered[(here - step + n) % n] { return -1 }
    }
    return nil
  }

  override func draw(_ rect: CGRect) {
    guard let ctx = UIGraphicsGetCurrentContext() else { return }
    let n = covered.count
    let centre = CGPoint(x: rect.midX, y: rect.midY)
    let radius = min(rect.width, rect.height) / 2 - 8
    ctx.setLineWidth(10)
    let step: CGFloat = 2 * CGFloat.pi / CGFloat(n)
    let facing = CGFloat(heading)
    for i in 0..<n {
      // Ángulo del sector respecto a donde miras; arriba = adelante.
      let start: CGFloat = CGFloat(i) * step - facing - CGFloat.pi / 2
      let end: CGFloat = start + step - 0.04
      ctx.setStrokeColor(
        (covered[i] ? UIColor.systemGreen : UIColor.white.withAlphaComponent(0.25)).cgColor)
      ctx.addArc(center: centre, radius: radius, startAngle: start, endAngle: end, clockwise: false)
      ctx.strokePath()
    }
  }
}
