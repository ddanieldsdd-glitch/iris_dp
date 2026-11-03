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
/// comprimida en `.zip`. Desde la v2 (ES.1, `docs/PLAN_ESCANEO.md`) el
/// `capture.json` lleva además la estructura: los planos de ARKit, los
/// toques de precisión y la nube de puntos dispersa.
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

/// Qué se marca con un toque de precisión.
enum MarkKind: String, CaseIterable {
  case corner, door, window, floor, ceiling

  var label: String {
    switch self {
    case .corner: return "Esquina"
    case .door: return "Puerta"
    case .window: return "Ventana"
    case .floor: return "Suelo"
    case .ceiling: return "Techo"
    }
  }

  var hint: String {
    switch self {
    case .corner: return "Toca una esquina de la pared."
    case .door: return "Toca los bordes y lo alto de la puerta."
    case .window: return "Toca los bordes, el alféizar y lo alto de la ventana."
    case .floor: return "Toca el suelo."
    case .ceiling: return "Toca el techo."
    }
  }

  var color: UIColor {
    switch self {
    case .corner: return .systemRed
    case .door: return .systemPurple
    case .window: return .systemTeal
    case .floor: return .systemBrown
    case .ceiling: return .white
    }
  }
}

/// Un toque de precisión: dónde cayó en el mundo y el plano que tocó.
private struct Mark {
  let kind: MarkKind
  let position: simd_float3
  let planeId: UUID?
  let node: SCNNode

  var json: [String: Any] {
    var out: [String: Any] = [
      "kind": kind.rawValue,
      "position": [position.x, position.y, position.z].map(rounded),
    ]
    if let planeId { out["planeId"] = planeId.uuidString }
    return out
  }
}

/// Al milímetro: el JSON no necesita más.
private func rounded(_ v: Float) -> Double { (Double(v) * 1000).rounded() / 1000 }

/// Un plano de ARKit con el giro de `planeExtent` metido en la matriz: así el
/// ancho va por la x del ancla y el fondo por la z, como pide `capture.json`.
private struct PlaneShape {
  let transform: simd_float4x4
  let center: simd_float3
  let width: Float
  let depth: Float
  private let back: simd_float4x4

  init(_ plane: ARPlaneAnchor) {
    let turn = simd_float4x4(
      simd_quatf(angle: plane.planeExtent.rotationOnYAxis, axis: simd_float3(0, 1, 0)))
    back = turn.inverse
    transform = plane.transform * turn
    center = simd_make_float3(back * simd_float4(plane.center, 1))
    width = plane.planeExtent.width
    depth = plane.planeExtent.height
  }

  /// Un punto del sistema del ancla al de este plano.
  func local(_ v: simd_float3) -> simd_float3 { simd_make_float3(back * simd_float4(v, 1)) }

  /// Los dos extremos del ancho, en el mundo: para una pared, su traza.
  var ends: (simd_float3, simd_float3) {
    let c = simd_make_float3(transform * simd_float4(center, 1))
    let axis = simd_normalize(simd_make_float3(transform.columns.0))
    return (c - axis * width / 2, c + axis * width / 2)
  }

  static func json(_ plane: ARPlaneAnchor) -> [String: Any] {
    let shape = PlaneShape(plane)
    let t = shape.transform
    var out: [String: Any] = [
      "id": plane.identifier.uuidString,
      "alignment": plane.alignment == .vertical ? "vertical" : "horizontal",
      "classification": classification(plane),
      "transform": [t.columns.0, t.columns.1, t.columns.2, t.columns.3]
        .flatMap { [$0.x, $0.y, $0.z, $0.w] }.map { Double($0) },
      "center": [shape.center.x, shape.center.y, shape.center.z].map(rounded),
      "extent": [shape.width, shape.depth].map(rounded),
    ]
    let boundary = plane.geometry.boundaryVertices.map { v -> [Double] in
      let p = shape.local(v)
      return [rounded(p.x), rounded(p.z)]
    }
    if boundary.count >= 3 { out["boundary"] = boundary }
    return out
  }

  static func classification(_ plane: ARPlaneAnchor) -> String {
    guard ARPlaneAnchor.isClassificationSupported else { return "none" }
    switch plane.classification {
    case .wall: return "wall"
    case .floor: return "floor"
    case .ceiling: return "ceiling"
    case .door: return "door"
    case .window: return "window"
    case .table: return "table"
    case .seat: return "seat"
    default: return "none"
    }
  }
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

  /// Nube de puntos vista hasta ahora, un punto por celda de 2 cm (sin
  /// duplicados): crece mientras se recorre el sitio (como Polycam sin
  /// LiDAR) y va tal cual a `points` del `capture.json`.
  private var cloud: [SIMD3<Int32>: simd_float3] = [:]
  private let cloudNode = SCNNode()
  private var lastCloudUpdate: TimeInterval = 0
  private let maxCloud = 20000
  private let cloudCell: Float = 0.02

  /// Toques de precisión («Marcar»).
  private var marks: [Mark] = []
  private var marking = false
  private var markKind: MarkKind = .corner
  private let markButton = IrisCaptureViewController.button("Marcar", filled: false)
  private let kindPicker = UISegmentedControl(items: MarkKind.allCases.map(\.label))
  private let undoMark = IrisCaptureViewController.button("Deshacer", filled: false)
  private lazy var markBar = UIStackView(arrangedSubviews: [kindPicker, undoMark])

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
    markButton.addTarget(self, action: #selector(markTapped), for: .touchUpInside)
    let buttons = UIStackView(arrangedSubviews: [cancel, shoot, markButton, done])
    buttons.spacing = 8
    buttons.distribution = .fillEqually

    kindPicker.selectedSegmentIndex = 0
    kindPicker.backgroundColor = UIColor.black.withAlphaComponent(0.55)
    kindPicker.selectedSegmentTintColor = .white
    kindPicker.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
    kindPicker.setTitleTextAttributes([.foregroundColor: UIColor.black], for: .selected)
    kindPicker.addTarget(self, action: #selector(kindChanged), for: .valueChanged)
    undoMark.addTarget(self, action: #selector(undoTapped), for: .touchUpInside)
    undoMark.setContentHuggingPriority(.required, for: .horizontal)
    markBar.spacing = 8
    markBar.isHidden = true
    sceneView.addGestureRecognizer(
      UITapGestureRecognizer(target: self, action: #selector(sceneTapped(_:))))

    for v in [warning, counter, map, ring, buttons, markBar] as [UIView] {
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
      markBar.topAnchor.constraint(equalTo: counter.bottomAnchor, constant: 8),
      markBar.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 16),
      markBar.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -16),
      markBar.heightAnchor.constraint(equalToConstant: 36),
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
    if let raw = frame.rawFeaturePoints, cloud.count < maxCloud {
      for point in raw.points where cloud.count < maxCloud {
        let cell = SIMD3<Int32>((point / cloudCell).rounded(.down))
        if cloud[cell] == nil { cloud[cell] = point }
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

  // MARK: - Marcar

  @objc private func markTapped() {
    marking.toggle()
    var c = marking ? UIButton.Configuration.filled() : UIButton.Configuration.gray()
    c.title = marking ? "Listo" : "Marcar"
    c.cornerStyle = .large
    if marking { c.baseBackgroundColor = .systemRed }
    markButton.configuration = c
    markBar.isHidden = !marking
    undoMark.isEnabled = !marks.isEmpty
    ring.isHidden = marking
  }

  @objc private func kindChanged() {
    markKind = MarkKind.allCases[max(0, kindPicker.selectedSegmentIndex)]
  }

  /// Un toque en la imagen, en modo «Marcar»: raycast sobre los planos ya
  /// detectados y, si no hay, sobre uno estimado.
  @objc private func sceneTapped(_ tap: UITapGestureRecognizer) {
    guard marking, !mapExpanded else { return }
    let at = tap.location(in: sceneView)
    var hit: ARRaycastResult?
    for target in [ARRaycastQuery.Target.existingPlaneGeometry, .estimatedPlane] {
      guard let query = sceneView.raycastQuery(from: at, allowing: target, alignment: .any)
      else { continue }
      if let first = sceneView.session.raycast(query).first {
        hit = first
        break
      }
    }
    guard let hit else {
      UINotificationFeedbackGenerator().notificationOccurred(.warning)
      show("No encuentro superficie ahí: mueve el móvil para que vea más.")
      return
    }
    let position = simd_make_float3(hit.worldTransform.columns.3)
    let node = Self.markNode(markKind)
    node.simdPosition = position
    sceneView.scene.rootNode.addChildNode(node)
    marks.append(
      Mark(
        kind: markKind, position: position,
        planeId: (hit.anchor as? ARPlaneAnchor)?.identifier, node: node))
    undoMark.isEnabled = true
    updateCounter()
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
  }

  @objc private func undoTapped() {
    guard let last = marks.popLast() else { return }
    last.node.removeFromParentNode()
    undoMark.isEnabled = !marks.isEmpty
    updateCounter()
  }

  /// Una bolita del color del tipo, siempre visible, con un palito vertical
  /// para que se vea bien dónde está.
  private static func markNode(_ kind: MarkKind) -> SCNNode {
    let material = SCNMaterial()
    material.diffuse.contents = kind.color
    material.lightingModel = .constant
    material.readsFromDepthBuffer = false
    let ball = SCNSphere(radius: 0.02)
    ball.materials = [material]
    let node = SCNNode(geometry: ball)
    node.renderingOrder = 10
    let stick = SCNCylinder(radius: 0.003, height: 0.12)
    stick.materials = [material]
    let stickNode = SCNNode(geometry: stick)
    stickNode.position.y = kind == .ceiling ? -0.06 : 0.06
    stickNode.renderingOrder = 10
    node.addChildNode(stickNode)
    return node
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
        // Las puertas y ventanas que clasifica ARKit no cierran el recinto.
        guard let plane = anchor as? ARPlaneAnchor, plane.alignment == .vertical,
          plane.planeExtent.width >= 0.3,
          !["door", "window"].contains(PlaneShape.classification(plane))
        else { return nil }
        return PlaneShape(plane).ends
      },
      marks: marks.map { ($0.position, $0.kind) }
    )
    let covered = coveredSectors(near: position)
    ring.update(covered: covered, heading: atan2(forward.x, -forward.z))
    updateCounter()

    let message = guidance(frame: frame, covered: covered, forward: forward)
    show(message ?? (marking ? markKind.hint : nil), ok: message == nil)
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

  /// [ok]: verde aunque haya texto (las pistas del modo «Marcar»).
  private func show(_ text: String?, ok: Bool? = nil) {
    let value = text ?? "Bien. Sigue recorriendo despacio."
    if warning.text != " \(value) " { warning.text = " \(value) " }
    warning.backgroundColor = (ok ?? (text == nil))
      ? UIColor.systemGreen.withAlphaComponent(0.55)
      : UIColor.systemOrange.withAlphaComponent(0.75)
  }

  /// Fotos, paredes, lo que queda abierto y los toques.
  private func updateCounter() {
    var parts = [shots.count == 1 ? "1 foto" : "\(shots.count) fotos"]
    let walls = map.wallCount
    if walls > 0 {
      parts.append(walls == 1 ? "1 pared" : "\(walls) paredes")
      let open = map.openEnds.count
      if map.closed {
        parts.append("recinto cerrado")
      } else if open > 0 {
        parts.append(open == 1 ? "1 extremo abierto" : "\(open) extremos abiertos")
      }
    }
    if !marks.isEmpty { parts.append(marks.count == 1 ? "1 marca" : "\(marks.count) marcas") }
    let text = parts.joined(separator: " · ")
    if counter.text != text { counter.text = text }
  }

  @objc private func cancelTapped() {
    finish(path: nil)
  }

  @objc private func doneTapped() {
    guard let folder, !shots.isEmpty else {
      finish(path: nil)
      return
    }
    // Los planos tal como los deja ARKit al final (ya fundidos y crecidos).
    let planes = (sceneView.session.currentFrame?.anchors ?? [])
      .compactMap { $0 as? ARPlaneAnchor }
      .map(PlaneShape.json)
    sceneView.session.pause()
    show("Guardando…")
    let manifest: [String: Any] = [
      "version": 2,
      "device": Self.deviceModel(),
      "system": UIDevice.current.systemVersion,
      "frames": shots.map(\.json),
      "planes": planes,
      "marks": marks.map(\.json),
      "points": cloud.values.flatMap { [rounded($0.x), rounded($0.y), rounded($0.z)] },
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
///
/// Las paredes se unen por sus esquinas en una línea; donde queda abierta se
/// avisa «falta pared», y cada pared lleva cuántas fotos la ven de frente.
final class CaptureMapView: UIView {
  /// Una pared en planta (x, z del mundo), ya unida a sus vecinas.
  struct Wall {
    var a: simd_float2
    var b: simd_float2
    /// Fotos que la ven de frente.
    var coverage: Int
  }

  private var position = simd_float3()
  private var forward = simd_float3(0, 0, -1)
  private var shots: [(simd_float3, simd_float3)] = []
  private var points: [simd_float3] = []
  private var walls: [Wall] = []
  private var marks: [(simd_float3, MarkKind)] = []
  /// Extremos sin unir: dónde y hacia dónde seguiría la pared.
  private(set) var openEnds: [(point: simd_float2, direction: simd_float2)] = []
  var wallCount: Int { walls.count }
  /// Tres paredes o más unidas sin ningún extremo suelto.
  var closed: Bool { walls.count >= 3 && openEnds.isEmpty }
  var expanded = false

  /// Con menos fotos de frente que esto, la pared sale en naranja.
  static let enoughCoverage = 4

  /// [points]: la nube entera cuando cambia; `nil`, la de antes.
  func update(
    position: simd_float3, forward: simd_float3,
    shots: [(simd_float3, simd_float3)], points: [simd_float3]?,
    walls: [(simd_float3, simd_float3)], marks: [(simd_float3, MarkKind)]
  ) {
    self.position = position
    self.forward = forward
    self.shots = shots
    if let points { self.points = points }
    self.marks = marks
    let flat = walls.map { (simd_float2($0.0.x, $0.0.z), simd_float2($0.1.x, $0.1.z)) }
    let joined = Self.join(flat)
    self.walls = zip(flat, joined.segments).map { raw, seg in
      Wall(a: seg.0, b: seg.1, coverage: Self.coverage(raw.0, raw.1, shots: shots))
    }
    openEnds = joined.open
    setNeedsDisplay()
  }

  private static func cross(_ u: simd_float2, _ v: simd_float2) -> Float { u.x * v.y - u.y * v.x }

  /// Une las paredes por sus esquinas: cada extremo se lleva al corte con otra
  /// pared si queda a menos de 80 cm; si sigue en línea con otra pared
  /// (dos planos de ARKit en la misma pared) cuenta como unido. Lo que no se
  /// une queda abierto.
  static func join(_ walls: [(simd_float2, simd_float2)]) -> (
    segments: [(simd_float2, simd_float2)],
    open: [(point: simd_float2, direction: simd_float2)]
  ) {
    let reach: Float = 0.8
    let parallel: Float = sin(30 * .pi / 180)
    var segments = walls
    var open: [(point: simd_float2, direction: simd_float2)] = []
    for i in walls.indices {
      let (a, b) = walls[i]
      let len = simd_length(b - a)
      guard len > 0.01 else { continue }
      let d = (b - a) / len
      for end in 0..<2 {
        let e = end == 0 ? a : b
        var best: (distance: Float, point: simd_float2)?
        var continued = false
        for j in walls.indices where j != i {
          let (c, f) = walls[j]
          let lj = simd_length(f - c)
          guard lj > 0.01 else { continue }
          let dj = (f - c) / lj
          let s = simd_dot(e - c, dj)
          let denom = cross(d, dj)
          if abs(denom) < parallel {
            // En línea con la otra pared y tocándola: el mismo muro.
            let off = abs(cross(e - c, dj))
            if abs(denom) < 0.17, off < 0.15, s > -0.3, s < lj + 0.3 { continued = true }
            continue
          }
          let t = cross(c - a, dj) / denom
          let p = a + d * t
          let along = simd_dot(p - c, dj)
          guard along > -reach, along < lj + reach else { continue }
          let distance = simd_distance(p, e)
          if distance < reach, distance < (best?.distance ?? .infinity) {
            best = (distance, p)
          }
        }
        if let best {
          if end == 0 { segments[i].0 = best.point } else { segments[i].1 = best.point }
        } else if !continued {
          open.append((e, end == 0 ? -d : d))
        }
      }
    }
    return (segments, open)
  }

  /// Fotos que ven la pared de frente: mirando a menos de 35° de su normal,
  /// entre 30 cm y 8 m, y con el centro de la foto dentro de la pared.
  static func coverage(
    _ a: simd_float2, _ b: simd_float2, shots: [(simd_float3, simd_float3)]
  ) -> Int {
    let len = simd_length(b - a)
    guard len > 0.01 else { return 0 }
    let d = (b - a) / len
    let n = simd_float2(-d.y, d.x)
    let facing = cos(35 * Float.pi / 180)
    var count = 0
    for (p, f) in shots {
      var look = simd_float2(f.x, f.z)
      let flat = simd_length(look)
      // Mirando casi al suelo o al techo no ve la pared de frente.
      guard flat > 0.5 else { continue }
      look /= flat
      let toward = simd_dot(look, n)
      guard abs(toward) > facing else { continue }
      let from = simd_float2(p.x, p.z)
      let t = simd_dot(a - from, n) / toward
      guard t > 0.3, t < 8 else { continue }
      let s = simd_dot(from + look * t - a, d)
      if s > -0.2, s < len + 0.2 { count += 1 }
    }
    return count
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
    // Paredes unidas: amarillas con cobertura, naranjas si les faltan fotos
    // de frente; verdes todas si el recinto ya cierra.
    func pt2(_ v: simd_float2) -> CGPoint { pt(simd_float3(v.x, 0, v.y)) }
    let small: [NSAttributedString.Key: Any] = [
      .font: UIFont.monospacedDigitSystemFont(ofSize: expanded ? 11 : 9, weight: .semibold),
      .foregroundColor: UIColor.white,
    ]
    ctx.setLineWidth(expanded ? 3 : 2.5)
    for w in walls {
      let colour: UIColor =
        closed ? .systemGreen
        : w.coverage < Self.enoughCoverage ? .systemOrange : .systemYellow
      ctx.setStrokeColor(colour.cgColor)
      ctx.move(to: pt2(w.a))
      ctx.addLine(to: pt2(w.b))
      ctx.strokePath()
      let mid = pt2((w.a + w.b) / 2)
      ("\(w.coverage)" as NSString).draw(at: CGPoint(x: mid.x + 3, y: mid.y + 2), withAttributes: small)
    }
    // Donde la línea queda abierta: un tramo rojo a trazos hacia donde
    // seguiría la pared.
    ctx.setStrokeColor(UIColor.systemRed.cgColor)
    ctx.setFillColor(UIColor.systemRed.cgColor)
    ctx.setLineWidth(2)
    ctx.setLineDash(phase: 0, lengths: [4, 3])
    for end in openEnds {
      let p = pt2(end.point)
      let q = pt2(end.point + end.direction * 0.8)
      ctx.move(to: p)
      ctx.addLine(to: q)
      ctx.strokePath()
      ctx.fillEllipse(in: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6))
      ("falta pared" as NSString).draw(
        at: CGPoint(x: q.x + 2, y: q.y - 6),
        withAttributes: [
          .font: UIFont.systemFont(ofSize: expanded ? 11 : 9, weight: .bold),
          .foregroundColor: UIColor.systemRed,
        ])
    }
    ctx.setLineDash(phase: 0, lengths: [])

    // Toques de precisión.
    for (p, kind) in marks {
      let c = pt(p)
      ctx.setFillColor(kind.color.cgColor)
      ctx.fillEllipse(in: CGRect(x: c.x - 4, y: c.y - 4, width: 8, height: 8))
      ctx.setStrokeColor(UIColor.black.cgColor)
      ctx.setLineWidth(1)
      ctx.strokeEllipse(in: CGRect(x: c.x - 4, y: c.y - 4, width: 8, height: 8))
    }
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

    let hint =
      expanded
      ? "Toca para cerrar · verde: ya fotografiado · número: fotos de frente a la pared"
      : "Toca para ampliar"
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
