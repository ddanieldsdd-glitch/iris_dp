import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// El paquete `.irisstage`: un set entero para Unreal en un solo archivo.
///
/// Es un zip con la misma escena que manda el enlace en vivo, en las mismas
/// unidades, más los archivos que allí se leen de este equipo. El plugin lo
/// monta con `iris_stage_link.import_package`, sin IRIS delante.
abstract final class UnrealStagePackage {
  static const format = 'irisstage';
  static const version = 1;
  static const extension = 'irisstage';

  /// [payload] es [UnrealStagePayload.build]. Las rutas de este equipo no
  /// viajan: el plugin las rehace al abrirlo.
  static Uint8List build({
    required Map<String, dynamic> payload,
    Uint8List? structureGlb,
    Map<String, Uint8List> scans = const {},
  }) {
    // Unreal reutiliza una malla por el nombre de su archivo: otra estructura
    // tiene que llamarse distinto.
    final structureName = structureGlb == null
        ? null
        : 'structure-${sha1.convert(structureGlb).toString().substring(0, 16)}.glb';
    final clean = Map<String, dynamic>.of(payload)
      ..remove('structure')
      ..remove('scanFolders')
      ..['full'] = true;
    final manifest = utf8.encode(
      jsonEncode({
        'format': format,
        'version': version,
        'structure': ?structureName,
        'payload': clean,
      }),
    );
    final archive = Archive()
      ..addFile(ArchiveFile('manifest.json', manifest.length, manifest));
    if (structureGlb != null) {
      archive.addFile(
        ArchiveFile(structureName!, structureGlb.length, structureGlb),
      );
    }
    for (final e in scans.entries) {
      archive.addFile(
        ArchiveFile('scans/${p.basename(e.key)}', e.value.length, e.value),
      );
    }
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  /// Como [build], en otro hilo: con escaneos pueden ser cientos de MB.
  static Future<Uint8List> buildInBackground({
    required Map<String, dynamic> payload,
    Uint8List? structureGlb,
    Map<String, Uint8List> scans = const {},
  }) => compute(_build, (payload, structureGlb, scans));

  static Uint8List _build(
    (Map<String, dynamic>, Uint8List?, Map<String, Uint8List>) job,
  ) => build(payload: job.$1, structureGlb: job.$2, scans: job.$3);

  /// Los archivos de cada escaneo que estén en [folders]: el normal y, si
  /// existe, el de todo el detalle (`_ue.glb`).
  static Future<Map<String, Uint8List>> collectScans(
    List<Map> scans,
    List<String> folders,
  ) async {
    final out = <String, Uint8List>{};
    for (final scan in scans) {
      final name = p.basename(scan['file'] as String);
      final detail = '${p.basenameWithoutExtension(name)}_ue.glb';
      for (final wanted in [name, detail]) {
        for (final folder in folders) {
          final file = File(p.join(folder, wanted));
          if (out.containsKey(wanted) || !file.existsSync()) continue;
          out[wanted] = await file.readAsBytes();
        }
      }
    }
    return out;
  }

  /// La orden para la consola de Python de Unreal.
  static String importCommand(String path) =>
      'import iris_stage_link; iris_stage_link.import_package(r"$path")';
}
