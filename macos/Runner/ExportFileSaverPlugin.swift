import Cocoa
import FlutterMacOS
import UniformTypeIdentifiers

/// Acceso a archivos del usuario en macOS sandbox: elegir, leer y guardar.
class ExportFileSaverPlugin: NSObject, FlutterPlugin {
  private var pendingURL: URL?
  private var pendingBookmark: Data?
  private var isDirectory = false
  private var hasSecurityScope = false

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.iris_dp/export_file_saver",
      binaryMessenger: registrar.messenger
    )
    let instance = ExportFileSaverPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      self.handleOnMainThread(call, result: result)
    }
  }

  private func handleOnMainThread(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "ping":
      result(true)
    case "pickFiles":
      pickFiles(call, result: result)
    case "beginSave":
      beginSave(call, result: result)
    case "writePending":
      writePending(call, result: result)
    case "saveFileWithBytes":
      saveFileWithBytes(call, result: result)
    case "beginDirectoryAccess":
      beginDirectoryAccess(call, result: result)
    case "writeInDirectory":
      writeInDirectory(call, result: result)
    case "finishPendingAccess":
      finishPendingAccess(result: result)
    case "cancelPending":
      cancelPending()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func clearPending() {
    if hasSecurityScope, let url = pendingURL {
      url.stopAccessingSecurityScopedResource()
    }
    pendingURL = nil
    pendingBookmark = nil
    isDirectory = false
    hasSecurityScope = false
  }

  private func storePendingAccess(url: URL, directory: Bool) {
    pendingURL = url
    isDirectory = directory
    pendingBookmark = try? url.bookmarkData(
      options: [.withSecurityScope],
      includingResourceValuesForKeys: nil,
      relativeTo: nil
    )
    if url.startAccessingSecurityScopedResource() {
      hasSecurityScope = true
    }
  }

  private func resolveWritableURL() -> URL? {
    if let url = pendingURL {
      if !hasSecurityScope, url.startAccessingSecurityScopedResource() {
        hasSecurityScope = true
      }
      return url
    }

    guard let bookmark = pendingBookmark else { return nil }

    var stale = false
    guard
      let url = try? URL(
        resolvingBookmarkData: bookmark,
        options: [.withSecurityScope, .withoutUI],
        relativeTo: nil,
        bookmarkDataIsStale: &stale
      )
    else {
      return nil
    }

    pendingURL = url
    if url.startAccessingSecurityScopedResource() {
      hasSecurityScope = true
    }
    return url
  }

  private func extractData(from args: [String: Any]) -> Data? {
    if let typed = args["bytes"] as? FlutterStandardTypedData {
      return typed.data
    }
    return nil
  }

  private func applyOpenFilters(_ dialog: NSOpenPanel, args: [String: Any]) {
    if args["imageOnly"] as? Bool == true {
      if #available(macOS 11.0, *) {
        dialog.allowedContentTypes = [.image]
      } else {
        dialog.allowedFileTypes = ["jpg", "jpeg", "png", "gif", "heic", "webp"]
      }
      return
    }

    if let extensions = args["allowedExtensions"] as? [String], !extensions.isEmpty {
      if #available(macOS 11.0, *) {
        dialog.allowedContentTypes = extensions.compactMap { UTType(filenameExtension: $0) }
      } else {
        dialog.allowedFileTypes = extensions
      }
    }
  }

  private func applySaveExtensions(_ dialog: NSSavePanel, _ extensions: [String]) {
    if extensions.isEmpty { return }
    if #available(macOS 11.0, *) {
      dialog.allowedContentTypes = extensions.compactMap { UTType(filenameExtension: $0) }
    } else {
      dialog.allowedFileTypes = extensions
    }
  }

  /// Abre panel de archivos y devuelve contenido en memoria (lectura con permiso sandbox).
  private func pickFiles(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any] else {
      result(FlutterError(code: "BAD_ARGS", message: "Missing arguments", details: nil))
      return
    }

    let dialog = NSOpenPanel()
    dialog.title = args["dialogTitle"] as? String ?? ""
    dialog.canChooseFiles = true
    dialog.canChooseDirectories = false
    dialog.allowsMultipleSelection = args["allowMultiple"] as? Bool ?? false
    dialog.showsHiddenFiles = false
    applyOpenFilters(dialog, args: args)

    guard dialog.runModal() == .OK else {
      result(nil)
      return
    }

    var picked: [[String: Any]] = []
    for url in dialog.urls {
      let accessed = url.startAccessingSecurityScopedResource()
      defer {
        if accessed {
          url.stopAccessingSecurityScopedResource()
        }
      }

      do {
        let data: Data
        if accessed {
          data = try Data(contentsOf: url)
        } else {
          // NSOpenPanel: lectura coordinada si el scope no arranca.
          var coordinatorError: NSError?
          var blockError: NSError?
          var fileData = Data()
          let coordinator = NSFileCoordinator()
          coordinator.coordinate(
            readingItemAt: url,
            options: [],
            error: &coordinatorError
          ) { readURL in
            do {
              fileData = try Data(contentsOf: readURL)
            } catch {
              blockError = error as NSError
            }
          }
          if let blockError {
            throw blockError
          }
          if let coordinatorError {
            throw coordinatorError
          }
          if fileData.isEmpty {
            throw CocoaError(.fileReadNoPermission)
          }
          data = fileData
        }

        picked.append([
          "name": url.lastPathComponent,
          "path": url.path,
          "bytes": FlutterStandardTypedData(bytes: data),
        ])
      } catch {
        result(
          FlutterError(
            code: "READ_FAILED",
            message: error.localizedDescription,
            details: url.path
          )
        )
        return
      }
    }

    result(picked.isEmpty ? nil : picked)
  }

  private func beginSave(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    clearPending()
    guard let args = call.arguments as? [String: Any] else {
      result(FlutterError(code: "BAD_ARGS", message: "Missing arguments", details: nil))
      return
    }

    let dialog = NSSavePanel()
    dialog.title = args["dialogTitle"] as? String ?? ""
    dialog.nameFieldStringValue = args["fileName"] as? String ?? ""
    dialog.canCreateDirectories = true
    dialog.showsHiddenFiles = false

    if let extensions = args["allowedExtensions"] as? [String] {
      applySaveExtensions(dialog, extensions)
    }

    guard dialog.runModal() == .OK, let url = dialog.url else {
      result(nil)
      return
    }

    storePendingAccess(url: url, directory: false)
    result(url.path)
  }

  /// Guardar en un solo paso: panel + escritura (método principal en macOS).
  private func saveFileWithBytes(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let data = extractData(from: args)
    else {
      result(FlutterError(code: "BAD_ARGS", message: "Missing bytes", details: nil))
      return
    }

    let dialog = NSSavePanel()
    dialog.title = args["dialogTitle"] as? String ?? ""
    dialog.nameFieldStringValue = args["fileName"] as? String ?? ""
    dialog.canCreateDirectories = true
    dialog.showsHiddenFiles = false

    if let extensions = args["allowedExtensions"] as? [String] {
      applySaveExtensions(dialog, extensions)
    }

    guard dialog.runModal() == .OK, let url = dialog.url else {
      result(nil)
      return
    }

    do {
      var coordinatorError: NSError?
      var blockError: NSError?
      var written = false
      let coordinator = NSFileCoordinator()
      coordinator.coordinate(
        writingItemAt: url,
        options: .forReplacing,
        error: &coordinatorError
      ) { writeURL in
        do {
          try data.write(to: writeURL, options: .atomic)
          written = true
        } catch {
          blockError = error as NSError
        }
      }
      if let blockError {
        throw blockError
      }
      if let coordinatorError {
        throw coordinatorError
      }
      if !written {
        throw CocoaError(.fileWriteNoPermission)
      }
      result(url.path)
    } catch {
      result(
        FlutterError(
          code: "WRITE_FAILED",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  private func writePending(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard !isDirectory else {
      result(
        FlutterError(
          code: "NO_PENDING",
          message: "No hay destino de guardado pendiente",
          details: nil
        )
      )
      return
    }
    guard let args = call.arguments as? [String: Any],
          let data = extractData(from: args)
    else {
      result(FlutterError(code: "BAD_ARGS", message: "Missing bytes", details: nil))
      return
    }

    guard let url = resolveWritableURL() else {
      result(
        FlutterError(
          code: "NO_PENDING",
          message: "No hay destino de guardado pendiente",
          details: nil
        )
      )
      return
    }

    do {
      try data.write(to: url, options: .atomic)
      let path = url.path
      clearPending()
      result(path)
    } catch {
      clearPending()
      result(
        FlutterError(
          code: "WRITE_FAILED",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  private func beginDirectoryAccess(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    clearPending()
    guard let args = call.arguments as? [String: Any] else {
      result(FlutterError(code: "BAD_ARGS", message: "Missing arguments", details: nil))
      return
    }

    let dialog = NSOpenPanel()
    dialog.title = args["dialogTitle"] as? String ?? ""
    dialog.canChooseDirectories = true
    dialog.canChooseFiles = false
    dialog.allowsMultipleSelection = false
    dialog.showsHiddenFiles = false

    guard dialog.runModal() == .OK, let url = dialog.url else {
      result(nil)
      return
    }

    storePendingAccess(url: url, directory: true)
    result(url.path)
  }

  private func writeInDirectory(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard isDirectory else {
      result(
        FlutterError(
          code: "NO_PENDING",
          message: "No hay carpeta de destino pendiente",
          details: nil
        )
      )
      return
    }
    guard let args = call.arguments as? [String: Any],
          let fileName = args["fileName"] as? String,
          let data = extractData(from: args)
    else {
      result(FlutterError(code: "BAD_ARGS", message: "Missing arguments", details: nil))
      return
    }

    guard let dirURL = resolveWritableURL() else {
      result(
        FlutterError(
          code: "NO_PENDING",
          message: "No hay carpeta de destino pendiente",
          details: nil
        )
      )
      return
    }

    let fileURL = dirURL.appendingPathComponent(fileName)
    do {
      try data.write(to: fileURL, options: .atomic)
      result(fileURL.path)
    } catch {
      result(
        FlutterError(
          code: "WRITE_FAILED",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  private func finishPendingAccess(result: @escaping FlutterResult) {
    clearPending()
    result(nil)
  }

  private func cancelPending() {
    clearPending()
  }
}
