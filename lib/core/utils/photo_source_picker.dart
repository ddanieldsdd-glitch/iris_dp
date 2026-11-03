import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// De dónde sale una foto en el iPhone y el iPad.
enum PhotoSource { camera, library, files }

/// «Añadir desde: Cámara · Fototeca · Archivos» (IC.1).
///
/// En el iPhone y el iPad pregunta de dónde sale la foto en una hoja
/// inferior; en el Mac y Windows abre el selector de archivos de siempre.
/// Devuelve las rutas locales elegidas (temporales: quien llama las copia al
/// proyecto), o una lista vacía si se cancela.
abstract final class PhotoSourcePicker {
  /// Si el equipo tiene cámara y fototeca (iOS / Android).
  static bool get isMobile => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  /// Para las pruebas: sustituye el selector real.
  @visibleForTesting
  static Future<List<String>> Function(PhotoSource source, bool multiple)?
  debugPickOverride;

  static Future<List<String>> pickImages(
    BuildContext context, {
    bool allowMultiple = true,
    String? title,
  }) async {
    if (!isMobile && debugPickOverride == null) {
      return _pickFiles(allowMultiple);
    }
    final source = await showSourceSheet(context, title: title);
    if (source == null) return const [];
    return pickFrom(source, allowMultiple: allowMultiple);
  }

  /// La hoja con las tres opciones. Devuelve la elegida o `null`.
  static Future<PhotoSource?> showSourceSheet(
    BuildContext context, {
    String? title,
  }) {
    final palette = context.palette;
    Widget option(
      PhotoSource source,
      IconData icon,
      String label,
      String detail,
      BuildContext ctx,
    ) => ListTile(
      leading: Icon(icon, color: palette.accent),
      title: Text(label, style: AppTypography.bodyLarge(palette)),
      subtitle: Text(detail, style: AppTypography.caption(palette)),
      onTap: () => Navigator.pop(ctx, source),
    );

    return showModalBottomSheet<PhotoSource>(
      context: context,
      backgroundColor: palette.surfaceElevated,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Text(
                  title ?? 'Añadir foto',
                  style: AppTypography.titleMedium(palette),
                ),
              ),
              option(
                PhotoSource.camera,
                Icons.photo_camera_outlined,
                'Cámara',
                'Hacer una foto ahora',
                ctx,
              ),
              option(
                PhotoSource.library,
                Icons.photo_library_outlined,
                'Fototeca',
                'Elegir una o varias fotos',
                ctx,
              ),
              option(
                PhotoSource.files,
                Icons.folder_open_outlined,
                'Archivos',
                'iCloud Drive, AirDrop y otras apps',
                ctx,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<List<String>> pickFrom(
    PhotoSource source, {
    bool allowMultiple = true,
  }) async {
    final override = debugPickOverride;
    if (override != null) return override(source, allowMultiple);
    switch (source) {
      case PhotoSource.camera:
        final shot = await ImagePicker().pickImage(source: ImageSource.camera);
        return [if (shot != null) shot.path];
      case PhotoSource.library:
        if (allowMultiple) {
          final picked = await ImagePicker().pickMultiImage();
          return [for (final f in picked) f.path];
        }
        final one = await ImagePicker().pickImage(source: ImageSource.gallery);
        return [if (one != null) one.path];
      case PhotoSource.files:
        return _pickFiles(allowMultiple);
    }
  }

  static Future<List<String>> _pickFiles(bool allowMultiple) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: allowMultiple,
    );
    if (result == null) return const [];
    return [
      for (final f in result.files)
        if (f.path != null) f.path!,
    ];
  }
}
