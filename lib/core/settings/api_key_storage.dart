import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Almacena la API key de Claude en el directorio de documentos de la app
/// (no se empaqueta en el bundle).
class ApiKeyStorage {
  static const _settingsFileName = 'settings.json';
  static const _claudeKeyField = 'claude_api_key';

  static Future<File> _settingsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final irisDir = Directory(p.join(dir.path, 'iris_dp'));
    if (!await irisDir.exists()) {
      await irisDir.create(recursive: true);
    }
    return File(p.join(irisDir.path, _settingsFileName));
  }

  static Future<String?> readClaudeApiKey() async {
    try {
      final file = await _settingsFile();
      if (!await file.exists()) return null;
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final key = data[_claudeKeyField] as String?;
      if (key == null || key.trim().isEmpty) return null;
      return key.trim();
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveClaudeApiKey(String key) async {
    final file = await _settingsFile();
    Map<String, dynamic> data = {};
    if (await file.exists()) {
      try {
        data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      } catch (_) {
        data = {};
      }
    }
    data[_claudeKeyField] = key.trim();
    await file.writeAsString(jsonEncode(data));
  }

  static Future<void> clearClaudeApiKey() async {
    final file = await _settingsFile();
    if (!await file.exists()) return;
    try {
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      data.remove(_claudeKeyField);
      if (data.isEmpty) {
        await file.delete();
      } else {
        await file.writeAsString(jsonEncode(data));
      }
    } catch (_) {
      await file.delete();
    }
  }

  static bool isPlaceholderKey(String key) =>
      key.isEmpty || key == 'sk-ant-xxxxx' || key.startsWith('sk-ant-xxxxx');
}
