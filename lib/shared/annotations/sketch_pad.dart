import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'annotation_document.dart';
import 'annotation_raster.dart';
import 'sketch_sheet_screen.dart';

export 'sketch_sheet_screen.dart' show SketchSheetPurpose;

/// Un dibujo hecho en el lienzo: la imagen y sus trazos, para poder seguir
/// dibujando otro día.
class SketchResult {
  final Uint8List png;
  final AnnotationDocument document;

  const SketchResult({required this.png, required this.document});
}

/// Archivo de trazos que acompaña a la imagen de un dibujo.
String sketchSidecarPath(String imagePath) => '$imagePath.trazos.json';

/// ¿Es [imagePath] un dibujo que se puede volver a abrir en el lienzo?
bool isEditableSketch(String imagePath) =>
    File(sketchSidecarPath(imagePath)).existsSync();

/// Los trazos de un dibujo guardado; vacío si no los tiene.
AnnotationDocument readSketchDocument(String imagePath) {
  final file = File(sketchSidecarPath(imagePath));
  if (!file.existsSync()) return const AnnotationDocument();
  try {
    return AnnotationDocument.decode(file.readAsStringSync());
  } catch (_) {
    return const AnnotationDocument();
  }
}

/// Guarda los trazos junto a la imagen ya almacenada en [imagePath].
Future<void> writeSketchDocument(
  String imagePath,
  AnnotationDocument document,
) => File(sketchSidecarPath(imagePath)).writeAsString(document.encode());

/// Pinta [document] sobre papel blanco y lo devuelve en PNG.
Future<Uint8List> renderSketchPng(
  AnnotationDocument document, {
  Size size = const Size(1600, 900),
}) => AnnotationRaster.toPng(document, size: size);

/// Abre el folio de dibujo ([SketchSheetScreen]). Devuelve el dibujo al
/// guardar; nulo si se cierra sin guardar.
Future<SketchResult?> showSketchPad(
  BuildContext context, {
  required String title,
  AnnotationDocument initial = const AnnotationDocument(),
  double aspectRatio = 16 / 9,
  SketchSheetPurpose purpose = SketchSheetPurpose.storyboard,
  ImageProvider? onionSkin,
  String? onionSkinLabel,
}) async {
  final result = await SketchSheetScreen.open(
    context,
    title: title,
    document: initial,
    purpose: purpose,
    aspectRatio: aspectRatio,
    exportPng: true,
    onionSkin: onionSkin,
    onionSkinLabel: onionSkinLabel,
  );
  final png = result?.png;
  if (result == null || png == null) return null;
  return SketchResult(png: png, document: result.document);
}
