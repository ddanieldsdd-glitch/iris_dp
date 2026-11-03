import ARKit
import AVFoundation
import CoreMotion
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
    case "lenses":
      // «wide»: la normal (1x), con ARKit. «ultraWide»: la 0,5x, sin ARKit
      // (ARKit solo sigue la posición con la normal).
      var lenses: [String] = []
      if ARWorldTrackingConfiguration.isSupported { lenses.append("wide") }
      if AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) != nil {
        lenses.append("ultraWide")
      }
      result(lenses)
    case "start":
      let args = call.arguments as? [String: Any]
      let name = (args?["name"] as? String) ?? "Localización"
      if (args?["lens"] as? String) == "ultraWide" {
        startWide(name: name, result: result)
      } else {
        start(name: name, result: result)
      }
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

  private func startWide(name: String, result: @escaping FlutterResult) {
    guard let root = Self.topController() else {
      result(nil)
      return
    }
    AVCaptureDevice.requestAccess(for: .video) { granted in
      DispatchQueue.main.async {
        guard granted else {
          result(nil)
          return
        }
        let capture = IrisWideCaptureViewController(name: name) { path in result(path) }
        capture.modalPresentationStyle = .fullScreen
        root.present(capture, animated: true)
      }
    }
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

  /// Nube de puntos vista hasta ahora, por identificador de ARKit: crece
  /// mientras se recorre el sitio (como Polycam sin LiDAR).
  private var cloud: [UInt64: simd_float3] = [:]
  private let cloudNode = SCNNode()
  private var lastCloudUpdate: TimeInterval = 0
  private let maxCloud = 40000

  /// Minimapa pequeño en la esquina o grande, tocándolo.
  private var mapExpanded = false
  private var smallMap: [NSLayoutConstraint] = []
  private var largeMap: [NSLayoutConstraint] = []

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
    sceneView.automaticallyUpdatesLighting = false
    sceneView.scene.rootNode.addChildNode(cloudNode)
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
    map.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(mapTapped)))
    ring.backgroundColor = .clear
    ring.isUserInteractionEnabled = false

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
      buttons.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 16),
      buttons.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -16),
      buttons.bottomAnchor.constraint(equalTo: g.bottomAnchor, constant: -12),
      buttons.heightAnchor.constraint(equalToConstant: 50),
    ])
    smallMap = [
      map.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -16),
      map.bottomAnchor.constraint(equalTo: buttons.topAnchor, constant: -12),
      map.widthAnchor.constraint(equalToConstant: 170),
      map.heightAnchor.constraint(equalToConstant: 170),
    ]
    largeMap = [
      map.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 16),
      map.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -16),
      map.topAnchor.constraint(equalTo: counter.bottomAnchor, constant: 8),
      map.bottomAnchor.constraint(equalTo: buttons.topAnchor, constant: -12),
    ]
    NSLayoutConstraint.activate(smallMap)
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

  /// El minimapa crece a casi toda la pantalla (y vuelve) al tocarlo.
  @objc private func mapTapped() {
    mapExpanded.toggle()
    NSLayoutConstraint.deactivate(mapExpanded ? smallMap : largeMap)
    NSLayoutConstraint.activate(mapExpanded ? largeMap : smallMap)
    map.expanded = mapExpanded
    UIView.animate(withDuration: 0.25) {
      self.ring.alpha = self.mapExpanded ? 0 : 1
      self.map.backgroundColor = UIColor.black.withAlphaComponent(self.mapExpanded ? 0.8 : 0.55)
      self.view.layoutIfNeeded()
    }
    map.setNeedsDisplay()
  }

  /// Guarda los puntos nuevos y, cada medio segundo, redibuja la nube en el
  /// espacio.
  private func grow(cloud frame: ARFrame) {
    if let raw = frame.rawFeaturePoints {
      for (id, point) in Swift.zip(raw.identifiers, raw.points)
      where cloud[id] != nil || cloud.count < maxCloud {
        cloud[id] = point
      }
    }
    guard frame.timestamp - lastCloudUpdate > 0.5, !cloud.isEmpty else { return }
    lastCloudUpdate = frame.timestamp
    let vertices = cloud.values.map { SCNVector3($0.x, $0.y, $0.z) }
    let source = SCNGeometrySource(vertices: vertices)
    let element = SCNGeometryElement(
      indices: Array(0..<Int32(vertices.count)), primitiveType: .point)
    element.pointSize = 4
    element.minimumPointScreenSpaceRadius = 1.5
    element.maximumPointScreenSpaceRadius = 3
    let geometry = SCNGeometry(sources: [source], elements: [element])
    let material = SCNMaterial()
    material.diffuse.contents = UIColor.cyan.withAlphaComponent(0.85)
    material.lightingModel = .constant
    geometry.materials = [material]
    cloudNode.geometry = geometry
  }

  /// Una marca verde, quieta en el espacio, donde se hizo cada foto.
  private func addShotMarker(_ transform: simd_float4x4) {
    let box = SCNBox(width: 0.08, height: 0.06, length: 0.012, chamferRadius: 0.006)
    let material = SCNMaterial()
    material.diffuse.contents = UIColor.systemGreen.withAlphaComponent(0.6)
    material.lightingModel = .constant
    box.materials = [material]
    let node = SCNNode(geometry: box)
    node.simdTransform = transform
    sceneView.scene.rootNode.addChildNode(node)
  }

  static func button(_ title: String, filled: Bool) -> UIButton {
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
    grow(cloud: frame)
    map.update(
      position: position,
      forward: forward,
      shots: shots.map { ($0.position, $0.forward) },
      points: frame.timestamp == lastCloudUpdate ? Array(cloud.values) : nil,
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
        self.addShotMarker(t)
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
    folder = Self.newFolder(name: name)
    return folder
  }

  /// `Documentos/IRIS Capturas/<nombre> <fecha>.iriscapture`.
  static func newFolder(name: String) -> URL? {
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
  static func zip(_ folder: URL) -> URL? {
    var out: URL?
    var error: NSError?
    NSFileCoordinator().coordinate(readingItemAt: folder, options: [.forUploading], error: &error) { tmp in
      let dest = folder.deletingPathExtension().appendingPathExtension("iriscapture.zip")
      try? FileManager.default.removeItem(at: dest)
      if (try? FileManager.default.copyItem(at: tmp, to: dest)) != nil { out = dest }
    }
    return out
  }

  static func deviceModel() -> String {
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

/// Minimapa cenital: lo fotografiado (abanicos verdes, lo que falta queda
/// oscuro), la nube de puntos, las paredes detectadas y dónde estás. Pequeño
/// sigue a la cámara (6 m); grande enseña todo el sitio con su cuadrícula.
final class CaptureMapView: UIView {
  private var position = simd_float3()
  private var forward = simd_float3(0, 0, -1)
  private var shots: [(simd_float3, simd_float3)] = []
  private var points: [simd_float3] = []
  private var walls: [(simd_float3, simd_float3)] = []
  var expanded = false

  /// [points]: la nube entera cuando cambia; `nil`, la de antes.
  func update(
    position: simd_float3, forward: simd_float3,
    shots: [(simd_float3, simd_float3)], points: [simd_float3]?,
    walls: [(simd_float3, simd_float3)]
  ) {
    self.position = position
    self.forward = forward
    self.shots = shots
    if let points { self.points = points }
    self.walls = walls
    setNeedsDisplay()
  }

  override func draw(_ rect: CGRect) {
    guard let ctx = UIGraphicsGetCurrentContext() else { return }
    // Pequeño: centrado en la cámara, 6 m de lado. Grande: todo lo visto.
    var centre = (x: position.x, z: position.z)
    var span: Float = 6
    if expanded {
      var minX = position.x, maxX = position.x, minZ = position.z, maxZ = position.z
      for v in points + shots.map(\.0) {
        minX = min(minX, v.x); maxX = max(maxX, v.x)
        minZ = min(minZ, v.z); maxZ = max(maxZ, v.z)
      }
      centre = ((minX + maxX) / 2, (minZ + maxZ) / 2)
      let aspect = Float(rect.width / max(rect.height, 1))
      span = max(4, max(maxX - minX, (maxZ - minZ) * aspect) * 1.15)
    }
    let scale = rect.width / CGFloat(span)
    func pt(_ v: simd_float3) -> CGPoint {
      CGPoint(
        x: rect.midX + CGFloat(v.x - centre.x) * scale,
        y: rect.midY + CGFloat(v.z - centre.z) * scale)
    }

    // Cuadrícula de 1 m.
    ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.08).cgColor)
    ctx.setLineWidth(1)
    let half = span / 2 + 1
    var gx = (centre.x - half).rounded(.down)
    while gx <= centre.x + half {
      let a = pt(simd_float3(gx, 0, centre.z - half)), b = pt(simd_float3(gx, 0, centre.z + half))
      ctx.move(to: a); ctx.addLine(to: b)
      gx += 1
    }
    var gz = (centre.z - half * 2).rounded(.down)
    while gz <= centre.z + half * 2 {
      let a = pt(simd_float3(centre.x - half, 0, gz)), b = pt(simd_float3(centre.x + half, 0, gz))
      ctx.move(to: a); ctx.addLine(to: b)
      gz += 1
    }
    ctx.strokePath()

    // Lo que ya ve alguna foto: un abanico de 60° y 2 m por foto.
    ctx.setFillColor(UIColor.systemGreen.withAlphaComponent(0.10).cgColor)
    for (p, f) in shots {
      let heading = atan2(f.z, f.x)
      let reach: Float = 2
      let spread: Float = .pi / 6
      ctx.move(to: pt(p))
      for k in 0...6 {
        let a = heading - spread + spread * 2 * Float(k) / 6
        ctx.addLine(to: pt(p + simd_float3(cos(a), 0, sin(a)) * reach))
      }
      ctx.closePath()
    }
    ctx.fillPath()

    ctx.setFillColor(UIColor.cyan.withAlphaComponent(expanded ? 0.55 : 0.4).cgColor)
    let dot: CGFloat = expanded ? 2 : 1.5
    for p in points {
      let c = pt(p)
      ctx.fill(CGRect(x: c.x - dot / 2, y: c.y - dot / 2, width: dot, height: dot))
    }
    ctx.setStrokeColor(UIColor.systemYellow.cgColor)
    ctx.setLineWidth(2.5)
    for (a, b) in walls {
      ctx.move(to: pt(a))
      ctx.addLine(to: pt(b))
    }
    ctx.strokePath()
    ctx.setStrokeColor(UIColor.systemGreen.withAlphaComponent(0.9).cgColor)
    ctx.setLineWidth(1)
    for (p, f) in shots {
      ctx.move(to: pt(p))
      ctx.addLine(to: pt(p + f * 0.4))
    }
    ctx.strokePath()
    let me = pt(position)
    ctx.setFillColor(UIColor.systemBlue.cgColor)
    ctx.fillEllipse(in: CGRect(x: me.x - 5, y: me.y - 5, width: 10, height: 10))
    ctx.setStrokeColor(UIColor.systemBlue.cgColor)
    ctx.setLineWidth(2)
    ctx.move(to: me)
    ctx.addLine(to: pt(position + forward * 0.6))
    ctx.strokePath()

    let hint = expanded ? "Toca para cerrar · verde: ya fotografiado" : "Toca para ampliar"
    (hint as NSString).draw(
      at: CGPoint(x: 8, y: rect.height - 18),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 11, weight: .medium),
        .foregroundColor: UIColor.white.withAlphaComponent(0.7),
      ])
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

/// Captura con la gran angular (0,5x). ARKit solo sigue la posición con la
/// cámara normal, así que aquí no hay mapa ni metros: las fotos salen solas
/// al girar unos grados o al andar, con el giroscopio, y RealityScan las
/// alinea sin pose (el escaneo se calibra después con una medida).
final class IrisWideCaptureViewController: UIViewController, AVCapturePhotoCaptureDelegate {
  private let name: String
  private let onDone: (String?) -> Void
  private let session = AVCaptureSession()
  private let output = AVCapturePhotoOutput()
  private let sessionQueue = DispatchQueue(label: "iris.capture.wide")
  private let motion = CMMotionManager()
  private var preview: AVCaptureVideoPreviewLayer?
  private let warning = UILabel()
  private let counter = UILabel()
  private let ring = CoverageRingView()
  private var folder: URL?
  private var frames: [[String: Any]] = []
  private var headings: [Float] = []
  private var lastShot: (time: TimeInterval, attitude: CMAttitude)?
  private var busy = false
  private var finished = false

  /// Una foto nueva al girar 10° desde la anterior, o cada 1,2 s si se anda.
  private let minTurn: Double = 10 * .pi / 180
  private let maxRotationRate: Double = 0.9

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
    let layer = AVCaptureVideoPreviewLayer(session: session)
    layer.videoGravity = .resizeAspect
    view.layer.addSublayer(layer)
    preview = layer

    warning.font = .systemFont(ofSize: 17, weight: .semibold)
    warning.textColor = .white
    warning.numberOfLines = 0
    warning.textAlignment = .center
    warning.layer.cornerRadius = 10
    warning.clipsToBounds = true
    counter.font = .monospacedDigitSystemFont(ofSize: 15, weight: .medium)
    counter.textColor = .white
    ring.backgroundColor = .clear
    ring.isUserInteractionEnabled = false

    let cancel = IrisCaptureViewController.button("Cancelar", filled: false)
    cancel.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
    let shoot = IrisCaptureViewController.button("Foto", filled: false)
    shoot.addTarget(self, action: #selector(shootTapped), for: .touchUpInside)
    let done = IrisCaptureViewController.button("Terminar", filled: true)
    done.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
    let buttons = UIStackView(arrangedSubviews: [cancel, shoot, done])
    buttons.spacing = 12
    buttons.distribution = .fillEqually

    for v in [warning, counter, ring, buttons] as [UIView] {
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
      ring.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -16),
      ring.bottomAnchor.constraint(equalTo: buttons.topAnchor, constant: -12),
      ring.widthAnchor.constraint(equalToConstant: 120),
      ring.heightAnchor.constraint(equalToConstant: 120),
      buttons.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 16),
      buttons.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -16),
      buttons.bottomAnchor.constraint(equalTo: g.bottomAnchor, constant: -12),
      buttons.heightAnchor.constraint(equalToConstant: 50),
    ])
    show("Gran angular 0,5x. Gira y anda despacio: las fotos se hacen solas.", ok: true)
    updateCounter()
    configureSession()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    preview?.frame = view.bounds
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    UIApplication.shared.isIdleTimerDisabled = true
    sessionQueue.async { self.session.startRunning() }
    motion.deviceMotionUpdateInterval = 1.0 / 30
    motion.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] m, _ in
      if let m { self?.moved(m) }
    }
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    UIApplication.shared.isIdleTimerDisabled = false
    motion.stopDeviceMotionUpdates()
    sessionQueue.async { self.session.stopRunning() }
  }

  private func configureSession() {
    sessionQueue.async {
      self.session.beginConfiguration()
      self.session.sessionPreset = .photo
      guard
        let device = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back),
        let input = try? AVCaptureDeviceInput(device: device),
        self.session.canAddInput(input), self.session.canAddOutput(self.output)
      else {
        self.session.commitConfiguration()
        DispatchQueue.main.async { self.show("No se pudo abrir la gran angular.", ok: false) }
        return
      }
      self.session.addInput(input)
      self.session.addOutput(self.output)
      self.output.maxPhotoQualityPrioritization = .balanced
      self.session.commitConfiguration()
    }
  }

  // MARK: - Movimiento

  private func moved(_ m: CMDeviceMotion) {
    let r = m.rotationRate
    let rate = sqrt(r.x * r.x + r.y * r.y + r.z * r.z)
    let heading = Float(-m.attitude.yaw)
    ring.update(covered: coveredSectors(), heading: heading)
    if rate > maxRotationRate {
      show("Más despacio: las fotos saldrían movidas.", ok: false)
      return
    }
    show(nil, ok: true)
    guard !busy else { return }
    let now = m.timestamp
    guard let last = lastShot else {
      shoot(attitude: m.attitude, time: now)
      return
    }
    if now - last.time < 0.5 { return }
    let delta = m.attitude.copy() as! CMAttitude
    delta.multiply(byInverseOf: last.attitude)
    let q = delta.quaternion
    let turned = 2 * acos(min(1, abs(q.w)))
    let a = m.userAcceleration
    let walking = sqrt(a.x * a.x + a.y * a.y + a.z * a.z) > 0.04
    if turned > minTurn || (walking && now - last.time > 1.2) {
      shoot(attitude: m.attitude, time: now)
    }
  }

  private func coveredSectors() -> [Bool] {
    var out = [Bool](repeating: false, count: 12)
    for h in headings { out[CoverageRingView.sector(of: h, count: out.count)] = true }
    return out
  }

  // MARK: - Fotos

  @objc private func shootTapped() {
    guard let m = motion.deviceMotion else { return }
    shoot(attitude: m.attitude, time: m.timestamp)
  }

  private var pendingAttitude: CMAttitude?

  private func shoot(attitude: CMAttitude, time: TimeInterval) {
    guard !busy, session.isRunning else { return }
    if folder == nil { folder = IrisCaptureViewController.newFolder(name: name) }
    guard folder != nil else { return }
    busy = true
    lastShot = (time, attitude.copy() as! CMAttitude)
    pendingAttitude = attitude.copy() as? CMAttitude
    let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
    settings.photoQualityPrioritization = .balanced
    output.capturePhoto(with: settings, delegate: self)
  }

  func photoOutput(
    _ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto,
    error: Error?
  ) {
    let data = photo.fileDataRepresentation()
    let dims = photo.resolvedSettings.photoDimensions
    DispatchQueue.main.async {
      defer { self.busy = false }
      guard error == nil, let data, let folder = self.folder else { return }
      let file = String(format: "f_%05d.jpg", self.frames.count + 1)
      guard (try? data.write(to: folder.appendingPathComponent(file))) != nil else { return }
      var frame: [String: Any] = [
        "file": file,
        "width": Int(dims.width),
        "height": Int(dims.height),
        "t": Date().timeIntervalSince1970,
      ]
      if let a = self.pendingAttitude {
        let q = a.quaternion
        frame["attitude"] = [q.w, q.x, q.y, q.z]
        self.headings.append(Float(-a.yaw))
      }
      self.frames.append(frame)
      self.updateCounter()
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
  }

  // MARK: - Interfaz

  private func show(_ text: String?, ok: Bool) {
    let value = text ?? "Bien. Sigue girando y andando despacio."
    if warning.text != " \(value) " { warning.text = " \(value) " }
    warning.backgroundColor = ok
      ? UIColor.systemGreen.withAlphaComponent(0.55)
      : UIColor.systemOrange.withAlphaComponent(0.75)
  }

  private func updateCounter() {
    counter.text = frames.count == 1 ? "1 foto · 0,5x" : "\(frames.count) fotos · 0,5x"
  }

  @objc private func cancelTapped() {
    finish(path: nil)
  }

  @objc private func doneTapped() {
    guard let folder, !frames.isEmpty else {
      finish(path: nil)
      return
    }
    motion.stopDeviceMotionUpdates()
    sessionQueue.async { self.session.stopRunning() }
    show("Guardando…", ok: true)
    let manifest: [String: Any] = [
      "version": 1,
      "lens": "ultraWide",
      "device": IrisCaptureViewController.deviceModel(),
      "system": UIDevice.current.systemVersion,
      "frames": frames,
    ]
    DispatchQueue.global(qos: .userInitiated).async {
      var path: String? = folder.path
      if let data = try? JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted]) {
        try? data.write(to: folder.appendingPathComponent("capture.json"))
        path = IrisCaptureViewController.zip(folder)?.path ?? folder.path
      }
      DispatchQueue.main.async { self.finish(path: path) }
    }
  }

  private func finish(path: String?) {
    guard !finished else { return }
    finished = true
    dismiss(animated: true) { self.onDone(path) }
  }
}
