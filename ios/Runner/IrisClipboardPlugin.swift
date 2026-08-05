import Flutter
import UIKit

/// Portapapeles de imagen para iPad/iPhone (⌘V / pegar ref).
final class IrisClipboardPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.iris_dp/export_file_saver",
      binaryMessenger: registrar.messenger()
    )
    let instance = IrisClipboardPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "readClipboard" else {
      result(FlutterMethodNotImplemented)
      return
    }
    readClipboard(result: result)
  }

  private func readClipboard(result: @escaping FlutterResult) {
    let pasteboard = UIPasteboard.general

    if let data = pasteboard.data(forPasteboardType: "public.png") {
      result([
        "kind": "image",
        "bytes": FlutterStandardTypedData(bytes: data),
        "extension": ".png",
      ])
      return
    }

    if let data = pasteboard.data(forPasteboardType: "public.jpeg") {
      result([
        "kind": "image",
        "bytes": FlutterStandardTypedData(bytes: data),
        "extension": ".jpg",
      ])
      return
    }

    if let image = pasteboard.image, let data = image.pngData() {
      result([
        "kind": "image",
        "bytes": FlutterStandardTypedData(bytes: data),
        "extension": ".png",
      ])
      return
    }

    if let text = pasteboard.string?.trimmingCharacters(in: .whitespacesAndNewlines),
       !text.isEmpty {
      result(["kind": "text", "text": text])
      return
    }

    result(["kind": "empty"])
  }
}
