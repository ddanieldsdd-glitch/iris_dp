import Foundation
import FlutterMacOS
import ModelIO

/// Pasa un USDZ (Polycam, Scaniverse, RoomPlan, Object Capture) a OBJ, que
/// es lo que sabe abrir el visor. Lo hace ModelIO, del propio sistema. El
/// OBJ conserva la malla; las texturas del USDZ no pasan.
final class IrisUsdzPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "iris/usdz",
      binaryMessenger: registrar.messenger
    )
    registrar.addMethodCallDelegate(IrisUsdzPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "toObj", let path = call.arguments as? String else {
      return result(FlutterMethodNotImplemented)
    }
    // Un escaneo puede tardar varios segundos en cargar.
    DispatchQueue.global(qos: .userInitiated).async {
      let outcome = Self.convert(path)
      DispatchQueue.main.async { result(outcome) }
    }
  }

  private static func failure(_ code: String, _ message: String) -> FlutterError {
    FlutterError(code: code, message: message, details: nil)
  }

  private static func convert(_ path: String) -> Any {
    let source = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: path) else {
      return failure("missing", "No se encuentra el archivo.")
    }
    guard MDLAsset.canExportFileExtension("obj") else {
      return failure("unsupported", "Este sistema no puede convertir USDZ.")
    }
    let folder = FileManager.default.temporaryDirectory
      .appendingPathComponent("iris_usdz_\(UUID().uuidString)", isDirectory: true)
    do {
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      let target = folder.appendingPathComponent(
        source.deletingPathExtension().lastPathComponent + ".obj"
      )
      let asset = MDLAsset(url: source)
      guard asset.count > 0 else {
        return failure("empty", "El USDZ no trae ninguna malla.")
      }
      try asset.export(to: target)
      return target.path
    } catch {
      return failure("export", error.localizedDescription)
    }
  }
}
