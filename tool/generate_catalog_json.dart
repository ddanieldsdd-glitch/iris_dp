// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:iris_dp/features/equipment/data/catalog_data.dart';

/// Genera assets/catalog/*.json desde catalog_data.dart
void main() {
  final dir = Directory('assets/catalog');
  if (!dir.existsSync()) dir.createSync(recursive: true);

  File('assets/catalog/manifest.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(kEmbeddedManifest.toJson()),
  );
  File('assets/catalog/cameras.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ')
        .convert(kEmbeddedCameras.map((e) => e.toJson()).toList()),
  );
  File('assets/catalog/lenses.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ')
        .convert(kEmbeddedLenses.map((e) => e.toJson()).toList()),
  );
  File('assets/catalog/lights.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ')
        .convert(kEmbeddedLights.map((e) => e.toJson()).toList()),
  );

  print('Generated catalog: '
      '${kEmbeddedCameras.length} cameras, '
      '${kEmbeddedLenses.length} lenses, '
      '${kEmbeddedLights.length} lights');
}
