import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_release.dart';

/// Progreso de descarga de un instalador.
class AppUpdateDownloadProgress {
  final int receivedBytes;
  final int? totalBytes;

  const AppUpdateDownloadProgress({
    required this.receivedBytes,
    this.totalBytes,
  });

  double? get fraction {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    return receivedBytes / total;
  }
}

/// Descarga el instalador de una release remota.
Future<String> downloadAppRelease(
  AppRelease release, {
  void Function(AppUpdateDownloadProgress progress)? onProgress,
}) async {
  final uri = Uri.parse(release.downloadUrl);
  final request = http.Request('GET', uri);
  final response = await request.send();
  if (response.statusCode != 200) {
    throw Exception('Descarga fallida (${response.statusCode})');
  }

  final total = response.contentLength;
  final tempDir = await getTemporaryDirectory();
  final fileName = p.basename(uri.path);
  final destPath = p.join(tempDir.path, fileName);
  final file = File(destPath);
  final sink = file.openWrite();

  var received = 0;
  await for (final chunk in response.stream) {
    received += chunk.length;
    sink.add(chunk);
    onProgress?.call(
      AppUpdateDownloadProgress(
        receivedBytes: received,
        totalBytes: total != null && total >= 0 ? total : null,
      ),
    );
  }
  await sink.close();
  return destPath;
}

/// Abre el instalador descargado (semi-automático en escritorio).
Future<void> launchDownloadedUpdate(String filePath) async {
  if (Platform.isMacOS) {
    final result = await Process.run('open', [filePath]);
    if (result.exitCode != 0) {
      throw Exception('No se pudo abrir el instalador: ${result.stderr}');
    }
    return;
  }

  if (Platform.isWindows) {
    await _applyWindowsUpdate(filePath);
    return;
  }

  throw UnsupportedError('Actualización automática no disponible en esta plataforma');
}

Future<void> _applyWindowsUpdate(String zipPath) async {
  final tempDir = await getTemporaryDirectory();
  final stagingDir = Directory(p.join(tempDir.path, 'iris_update_staging'));
  if (stagingDir.existsSync()) {
    stagingDir.deleteSync(recursive: true);
  }
  stagingDir.createSync(recursive: true);

  final bytes = await File(zipPath).readAsBytes();
  final archive = ZipDecoder().decodeBytes(bytes);
  for (final file in archive) {
    final outPath = p.join(stagingDir.path, file.name);
    if (file.isFile) {
      final outFile = File(outPath);
      outFile.createSync(recursive: true);
      outFile.writeAsBytesSync(file.content as List<int>);
    } else {
      Directory(outPath).createSync(recursive: true);
    }
  }

  final exePath = Platform.resolvedExecutable;
  final installDir = p.dirname(exePath);
  final batPath = p.join(tempDir.path, 'iris_apply_update.bat');
  final bat = '''
@echo off
timeout /t 2 /nobreak >nul
xcopy /E /Y /I "${stagingDir.path}\\*" "$installDir\\"
start "" "$installDir\\iris_dp.exe"
del "%~f0"
''';
  await File(batPath).writeAsString(bat);

  await Process.start(
    'cmd',
    ['/c', batPath],
    mode: ProcessStartMode.detached,
  );
  exit(0);
}

bool get supportsInAppUpdate =>
    Platform.isMacOS || Platform.isWindows;
