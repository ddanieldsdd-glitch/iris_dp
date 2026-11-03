import Flutter
import QuickLook
import UIKit

/// Abre un archivo con Vista Rápida: un USDZ se ve en 3D y en AR (AR Quick
/// Look); también imágenes, PDF y vídeo.
final class IrisQuickLookPlugin: NSObject, FlutterPlugin, QLPreviewControllerDataSource {
  private var url: URL?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "iris/quicklook",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(IrisQuickLookPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "canPreview":
      guard let path = call.arguments as? String else { return result(false) }
      result(QLPreviewController.canPreview(URL(fileURLWithPath: path) as NSURL))
    case "preview":
      guard let path = call.arguments as? String,
        FileManager.default.fileExists(atPath: path),
        let root = Self.topController()
      else { return result(false) }
      url = URL(fileURLWithPath: path)
      let preview = QLPreviewController()
      preview.dataSource = self
      root.present(preview, animated: true)
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
    url == nil ? 0 : 1
  }

  func previewController(_ controller: QLPreviewController, previewItemAt index: Int)
    -> QLPreviewItem
  {
    url! as NSURL
  }

  private static func topController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    var top = scenes.flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }
}
