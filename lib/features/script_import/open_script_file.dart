import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

/// Abre el guion en la aplicación predeterminada del sistema (Preview, Word, etc.).
Future<bool> openScriptInSystemApp(String path) async {
  final uri = Uri.file(path);
  if (await canLaunchUrl(uri)) {
    return launchUrl(uri);
  }

  if (Platform.isMacOS) {
    final result = await Process.run('open', [path]);
    return result.exitCode == 0;
  }

  if (Platform.isLinux) {
    final result = await Process.run('xdg-open', [path]);
    return result.exitCode == 0;
  }

  if (Platform.isWindows) {
    final result = await Process.run('cmd', ['/c', 'start', '', path]);
    return result.exitCode == 0;
  }

  return false;
}
