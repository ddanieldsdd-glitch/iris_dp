import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// Imagen leída del portapapeles o descargada de una URL.
class ClipboardImagePayload {
  final Uint8List bytes;
  final String extension;

  const ClipboardImagePayload({
    required this.bytes,
    required this.extension,
  });
}

/// Resultado al intentar pegar una imagen.
enum ClipboardImageReadStatus {
  success,
  noImage,
  downloadFailed,
  invalidUrl,
  pluginUnavailable,
}

class ClipboardImageReadResult {
  final ClipboardImageReadStatus status;
  final ClipboardImagePayload? payload;

  const ClipboardImageReadResult({
    required this.status,
    this.payload,
  });
}

/// Lee imágenes del portapapeles: datos binarios, URL remota o ruta local.
abstract final class ClipboardImageReader {
  ClipboardImageReader._();

  static const _macChannel = MethodChannel('com.iris_dp/export_file_saver');
  static const _browserUserAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

  static Future<ClipboardImageReadResult> read() async {
    if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isIOS)) {
      try {
        final native = await _readNativeClipboard();
        if (native != null) return native;
      } on MissingPluginException {
        if (Platform.isMacOS) {
          return const ClipboardImageReadResult(
            status: ClipboardImageReadStatus.pluginUnavailable,
          );
        }
      }
    }

    final textData = await Clipboard.getData(Clipboard.kTextPlain);
    return _readFromText(textData?.text);
  }

  static Future<ClipboardImageReadResult?> _readNativeClipboard() async {
    try {
      final raw = await _macChannel.invokeMethod<Object?>('readClipboard');
      return _parseNativeClipboardMap(raw);
    } on PlatformException {
      return null;
    }
  }

  static Future<ClipboardImageReadResult> _readFromText(String? text) async {
    final trimmed = text?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return const ClipboardImageReadResult(
        status: ClipboardImageReadStatus.noImage,
      );
    }

    final htmlUrl = extractImageUrlFromHtml(trimmed);
    if (htmlUrl != null) {
      final downloaded = await _downloadImage(htmlUrl);
      if (downloaded != null) {
        return ClipboardImageReadResult(
          status: ClipboardImageReadStatus.success,
          payload: downloaded,
        );
      }
      return const ClipboardImageReadResult(
        status: ClipboardImageReadStatus.downloadFailed,
      );
    }

    final url = extractHttpUrl(trimmed);
    if (url != null) {
      final downloaded = await _downloadImage(url);
      if (downloaded != null) {
        return ClipboardImageReadResult(
          status: ClipboardImageReadStatus.success,
          payload: downloaded,
        );
      }
      if (_looksLikeImageUrl(url)) {
        return const ClipboardImageReadResult(
          status: ClipboardImageReadStatus.downloadFailed,
        );
      }
    }

    if (!kIsWeb && File(trimmed).existsSync()) {
      final bytes = await File(trimmed).readAsBytes();
      if (bytes.isNotEmpty) {
        return ClipboardImageReadResult(
          status: ClipboardImageReadStatus.success,
          payload: ClipboardImagePayload(
            bytes: bytes,
            extension: _extensionFromPath(trimmed),
          ),
        );
      }
    }

    return const ClipboardImageReadResult(
      status: ClipboardImageReadStatus.noImage,
    );
  }

  @visibleForTesting
  static Uri? extractHttpUrl(String text) {
    final trimmed = text.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty) {
      return uri;
    }
    final match =
        RegExp(r'https?://[^\s)\]"<>]+', caseSensitive: false).firstMatch(trimmed);
    if (match == null) return null;
    return Uri.tryParse(match.group(0)!);
  }

  @visibleForTesting
  static Uri? extractImageUrlFromHtml(String html) {
    final srcMatch = RegExp(
      r'''<img[^>]+src=["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(html);
    if (srcMatch != null) {
      return _resolveUrl(srcMatch.group(1)!);
    }

    final bgMatch = RegExp(
      r'''background-image\s*:\s*url\(["']?([^"')]+)["']?\)''',
      caseSensitive: false,
    ).firstMatch(html);
    if (bgMatch != null) {
      return _resolveUrl(bgMatch.group(1)!);
    }

    return null;
  }

  static Uri? _resolveUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('data:')) return null;
    if (trimmed.startsWith('//')) {
      return Uri.tryParse('https:$trimmed');
    }
    return extractHttpUrl(trimmed);
  }

  static Future<ClipboardImageReadResult?> _readMacClipboard() =>
      _readNativeClipboard();

  static Future<ClipboardImageReadResult?> _parseNativeClipboardMap(
    Object? raw,
  ) async {
    if (raw is! Map) return null;
    final map = Map<Object?, Object?>.from(raw);
    final kind = map['kind'] as String?;

    final imageResult = await _payloadFromNativeImage(map, kind);
    if (imageResult != null) return imageResult;

    if (kind == 'html') {
      final html = map['html'] as String?;
      final url = html != null ? extractImageUrlFromHtml(html) : null;
      if (url != null) {
        final downloaded = await _downloadImage(url);
        if (downloaded != null) {
          return ClipboardImageReadResult(
            status: ClipboardImageReadStatus.success,
            payload: downloaded,
          );
        }
        return const ClipboardImageReadResult(
          status: ClipboardImageReadStatus.downloadFailed,
        );
      }
    }
    if (kind == 'text') {
      return _readFromText(map['text'] as String?);
    }
    if (kind == 'empty') {
      return const ClipboardImageReadResult(
        status: ClipboardImageReadStatus.noImage,
      );
    }
    return null;
  }

  static Future<ClipboardImageReadResult?> _payloadFromNativeImage(
    Map<Object?, Object?> map,
    String? kind,
  ) async {
    if (kind == 'image_path') {
      final path = map['path'] as String?;
      if (path == null) return null;
      final file = File(path);
      if (!file.existsSync()) return null;
      try {
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) return null;
        return ClipboardImageReadResult(
          status: ClipboardImageReadStatus.success,
          payload: ClipboardImagePayload(
            bytes: bytes,
            extension: map['extension'] as String? ?? '.png',
          ),
        );
      } finally {
        try {
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
    }

    if (kind == 'image') {
      final bytes = _decodeBytes(map['bytes']);
      if (bytes == null || bytes.isEmpty) return null;
      return ClipboardImageReadResult(
        status: ClipboardImageReadStatus.success,
        payload: ClipboardImagePayload(
          bytes: bytes,
          extension: map['extension'] as String? ?? '.png',
        ),
      );
    }

    return null;
  }

  static Future<ClipboardImagePayload?> _downloadImage(Uri uri) async {
    try {
      final response = await http
          .get(uri, headers: _downloadHeaders(uri))
          .timeout(const Duration(seconds: 25));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return null;
      }

      final contentType =
          response.headers['content-type']?.split(';').first.trim().toLowerCase() ??
              '';
      if (!contentType.startsWith('image/') && !_looksLikeImageUrl(uri)) {
        return null;
      }

      final ext = _extensionFromContentType(contentType) ??
          _extensionFromPath(uri.path);
      return ClipboardImagePayload(
        bytes: response.bodyBytes,
        extension: ext,
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, String> _downloadHeaders(Uri uri) {
    final host = uri.host.toLowerCase();
    final headers = <String, String>{'User-Agent': _browserUserAgent};
    if (host.contains('shotdeck')) {
      headers['Referer'] = 'https://www.shotdeck.com/';
      headers['Origin'] = 'https://www.shotdeck.com';
    }
    return headers;
  }

  static bool _looksLikeImageUrl(Uri uri) {
    final path = uri.path.toLowerCase();
    final host = uri.host.toLowerCase();
    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.gif') ||
        path.endsWith('.webp') ||
        path.endsWith('.heic') ||
        path.endsWith('.avif') ||
        host.contains('shotdeck') ||
        host.contains('images.') ||
        host.contains('imgur') ||
        host.contains('pinimg');
  }

  static String? _extensionFromContentType(String contentType) {
    return switch (contentType) {
      'image/png' => '.png',
      'image/jpeg' => '.jpg',
      'image/gif' => '.gif',
      'image/webp' => '.webp',
      'image/heic' || 'image/heif' => '.heic',
      'image/avif' => '.avif',
      _ => null,
    };
  }

  static String _extensionFromPath(String path) {
    final ext = p.extension(path.split('?').first).toLowerCase();
    if (ext.isNotEmpty) return ext;
    return '.jpg';
  }

  static Uint8List? _decodeBytes(Object? raw) {
    if (raw == null) return null;
    if (raw is Uint8List) return raw;
    if (raw is ByteData) {
      return raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes);
    }
    if (raw is List<int>) return Uint8List.fromList(raw);
    return null;
  }
}
