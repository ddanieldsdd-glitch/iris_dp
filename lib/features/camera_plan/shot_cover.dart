import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/shot_reference_import.dart';

/// La imagen que representa al plano (su storyboard o su referencia, la
/// que se eligió), recortada para una miniatura. `null` si no tiene ninguna
/// o el archivo ya no está: entonces se enseña su planta.
Widget? shotCoverThumbnail(Shot shot, {int cacheWidth = 320}) {
  final path = coverImageOf(shot);
  if (path == null || !File(path).existsSync()) return null;
  return Image.file(
    File(path),
    fit: BoxFit.cover,
    cacheWidth: cacheWidth,
    errorBuilder: (_, _, _) => const SizedBox.shrink(),
  );
}
