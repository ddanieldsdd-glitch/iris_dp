import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
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
  String? fileName,
}) async {
  final uri = Uri.parse(release.downloadUrl);
  final request = http.Request('GET', uri);
  final response = await request.send();
  if (response.statusCode != 200) {
    throw Exception('Descarga fallida (${response.statusCode})');
  }

  final total = response.contentLength;
  final tempDir = await getTemporaryDirectory();
  final destPath = p.join(tempDir.path, fileName ?? p.basename(uri.path));
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
  // En Mac no se pasa por aquí: se actualiza sola (ver MacAutoUpdate).
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
  final bat = windowsUpdateScript(
    stagingDir: stagingDir.path,
    installDir: installDir,
  );
  await File(batPath).writeAsString(bat);

  await Process.start(
    'cmd',
    ['/c', batPath],
    mode: ProcessStartMode.detached,
  );
  exit(0);
}

/// Lo que aplica la actualización en Windows cuando IRIS ya se ha cerrado.
///
/// Otra copia de IRIS abierta, aunque no tenga ventana, bloquea los archivos:
/// se cierra primero. Si aun así no se puede copiar, avisa, para no volver a
/// abrir la versión antigua como si nada.
@visibleForTesting
String windowsUpdateScript({
  required String stagingDir,
  required String installDir,
}) {
  final exe = '$installDir\\iris_dp.exe';
  final exeForPowerShell = exe.replaceAll("'", "''");
  return '''
@echo off
chcp 65001 >nul
"%SystemRoot%\\System32\\PING.EXE" -n 3 127.0.0.1 >nul
powershell -NoProfile -Command "Get-Process iris_dp -ErrorAction SilentlyContinue | Where-Object { \$_.Path -eq '$exeForPowerShell' } | Stop-Process -Force"
set tries=0
:copy
xcopy /E /Y /I /Q "$stagingDir\\*" "$installDir\\" >nul
if not errorlevel 1 goto done
set /a tries+=1
if %tries% geq 10 goto failed
"%SystemRoot%\\System32\\PING.EXE" -n 3 127.0.0.1 >nul
goto copy
:failed
powershell -NoProfile -Command "Add-Type -AssemblyName PresentationFramework; [void][System.Windows.MessageBox]::Show('No se pudo instalar la actualización porque hay archivos de IRIS en uso. Reinicia el equipo y vuelve a actualizar.', 'IRIS')"
:done
start "" "$exe"
(goto) 2>nul & del "%~f0"
'''
      // cmd pierde las etiquetas de un .bat que no tenga CRLF.
      .replaceAll(RegExp(r'\r?\n'), '\r\n');
}

bool get supportsInAppUpdate =>
    Platform.isMacOS || Platform.isWindows;
