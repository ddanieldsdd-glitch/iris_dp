import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Carpeta donde dejar capturas; solo se hacen si se pide con `SNAP_OUT`.
String? get snapshotDir => Platform.environment['SNAP_OUT'];

/// Carga las fuentes reales (las que google_fonts dejó en caché en este
/// equipo y los iconos de Material) para que la captura no salga con
/// cuadrados. Sin caché, la captura sale igual pero con la fuente de test.
Future<void> loadSnapshotFonts() async {
  if (snapshotDir == null) return;
  // En un test no hay red: que google_fonts no intente bajar nada.
  GoogleFonts.config.allowRuntimeFetching = false;
  final home = Platform.environment['HOME'];
  if (home == null) return;
  final cache = Directory('$home/Library/Application Support/com.example.irisDp');
  if (cache.existsSync()) {
    for (final file in cache.listSync().whereType<File>()) {
      final name = file.uri.pathSegments.last;
      if (!name.endsWith('.ttf')) continue;
      // «Inter_600_<hash>.ttf» → familia «Inter_600».
      final family = name.substring(0, name.lastIndexOf('_'));
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
      await loader.load();
    }
  }
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final icons = File(
      '$flutterRoot/bin/cache/artifacts/material_fonts/'
      'MaterialIcons-Regular.otf',
    );
    if (icons.existsSync()) {
      final loader = FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
      await loader.load();
    }
  }
}

/// Guarda lo que hay en pantalla como PNG en [snapshotDir]/[name].png.
Future<void> saveSnapshot(WidgetTester tester, String name) async {
  final dir = snapshotDir;
  if (dir == null) return;
  final boundary = tester.binding.rootElement!.renderObject!;
  RenderRepaintBoundary? repaint;
  void visit(RenderObject object) {
    if (repaint == null && object is RenderRepaintBoundary) {
      repaint = object;
      return;
    }
    object.visitChildren(visit);
  }

  visit(boundary);
  if (repaint == null) return;
  await tester.runAsync(() async {
    final image = await repaint!.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(dir).createSync(recursive: true);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
