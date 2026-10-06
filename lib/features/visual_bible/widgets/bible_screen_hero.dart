import 'dart:io';

import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/visual_bible/bible_point_extras.dart';
import '../../../shared/visual_bible/bible_section_fields.dart';
import 'bible_point_images.dart';
import 'bible_point_panel.dart';

/// Colores que se ofrecen para representar una pantalla.
const kBibleScreenColors = [
  '#0A84FF',
  '#30B0C7',
  '#34C759',
  '#A2845E',
  '#FFD60A',
  '#FF9F0A',
  '#FF453A',
  '#FF375F',
  '#BF5AF2',
  '#8E8E93',
];

enum _HeroAction { image, removeImage, rename, color, reset }

/// Cabecera común de las pantallas de la biblia: una tarjeta con el título
/// en grande sobre la imagen que el usuario elija para representarla, y un
/// menú con lo que se puede hacer con la pantalla entera.
///
/// Cada acción del menú solo aparece si se da su manejador.
class BibleScreenHero extends ConsumerWidget {
  final int projectId;
  final int bibleId;
  final String sectionId;
  final String title;
  final String kicker;
  final BibleScreenHeroValue value;

  /// Guarda la imagen y el color de la cabecera.
  final ValueChanged<BibleScreenHeroValue>? onChanged;

  /// Cambia el nombre de la pantalla.
  final ValueChanged<String>? onRename;

  /// Reinicia la pantalla. La confirmación la pide la cabecera.
  final VoidCallback? onReset;

  const BibleScreenHero({
    super.key,
    required this.projectId,
    required this.bibleId,
    required this.sectionId,
    required this.title,
    this.kicker = 'Biblia de fotografía',
    this.value = const BibleScreenHeroValue(),
    this.onChanged,
    this.onRename,
    this.onReset,
  });

  static const double height = 220;

  bool get _hasMenu => onChanged != null || onRename != null || onReset != null;

  Future<void> _pickImage(BuildContext context) async {
    final picked = await showMoodboardImagePicker(
      context,
      projectId: projectId,
      bibleId: bibleId,
      sectionId: sectionId,
      selected: [if (value.imageId != null) value.imageId!],
      single: true,
    );
    if (picked != null) {
      onChanged!(value.withImage(picked.isEmpty ? null : picked.first));
    }
  }

  Future<void> _rename(BuildContext context) async {
    final controller = TextEditingController(text: title);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nombre de la pantalla'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Cambiar'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && name != title) onRename!(name);
  }

  Future<void> _pickColor(BuildContext context) async {
    // Cadena vacía = quitar el color; `null` = cancelar.
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Color de la pantalla'),
        content: SizedBox(
          width: 280,
          child: Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              for (final hex in kBibleScreenColors)
                InkWell(
                  key: ValueKey('screen_color_$hex'),
                  onTap: () => Navigator.pop(ctx, hex),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(BibleScreenHeroValue(colorHex: hex).argb!),
                      border: Border.all(
                        width: 2,
                        color: value.colorHex == hex
                            ? Colors.white
                            : Colors.transparent,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          if (value.colorHex != null)
            TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: const Text('Sin color'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    if (picked != null) {
      onChanged!(value.withColor(picked.isEmpty ? null : picked));
    }
  }

  Future<void> _confirmReset(BuildContext context) async {
    final palette = context.palette;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reiniciar «$title»'),
        content: const SizedBox(
          width: 420,
          child: Text(
            'Se borra todo lo escrito en esta pantalla y los puntos que '
            'hayas añadido, y vuelven sus puntos de partida. Los textos que '
            'comparte con otra pantalla también se vacían.\n\n'
            'Se conservan el nombre, la imagen y el color de la pantalla, '
            'las imágenes del moodboard, los actos del proyecto y los '
            'elementos con ficha propia (bloques de color, esquemas de luz, '
            'pruebas de cámara).\n\n'
            'No se puede deshacer.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: palette.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reiniciar pantalla'),
          ),
        ],
      ),
    );
    if (ok == true) onReset!();
  }

  void _run(BuildContext context, _HeroAction action) {
    switch (action) {
      case _HeroAction.image:
        _pickImage(context);
      case _HeroAction.removeImage:
        onChanged!(value.withImage(null));
      case _HeroAction.rename:
        _rename(context);
      case _HeroAction.color:
        _pickColor(context);
      case _HeroAction.reset:
        _confirmReset(context);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = value.imageId;
    if (id == null) return _band(context, null);
    return StreamBuilder<List<MoodboardImage>>(
      stream: ref.watch(databaseProvider).watchMoodboardImages(projectId),
      builder: (context, snap) {
        String? path;
        for (final image in snap.data ?? const <MoodboardImage>[]) {
          if (image.id == id) path = image.imagePath;
        }
        return _band(context, path);
      },
    );
  }

  Widget _band(BuildContext context, String? path) {
    final palette = context.palette;
    final file = path == null ? null : File(path);
    final hasImage = file != null && file.existsSync();
    final label = BiblePointPanel.labelStyle(palette);
    final accent = value.argb == null ? palette.accent : Color(value.argb!);

    PopupMenuItem<_HeroAction> item(
      _HeroAction action,
      IconData icon,
      String text, {
      Color? color,
    }) => PopupMenuItem(
      value: action,
      child: Row(
        children: [
          Icon(icon, size: 16, color: color ?? palette.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              text,
              style: color == null ? null : TextStyle(color: color),
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BiblePointPanel.radius),
        child: SizedBox(
          height: hasImage ? height : 132,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasImage) ...[
                Image.file(file, fit: BoxFit.cover),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.15),
                        Colors.black.withValues(alpha: 0.82),
                      ],
                    ),
                  ),
                ),
              ] else
                ColoredBox(
                  color: value.argb == null
                      ? palette.surfaceElevated.withValues(alpha: 0.45)
                      : Color.alphaBlend(
                          accent.withValues(alpha: 0.14),
                          palette.surfaceElevated,
                        ),
                ),
              // Filo con el color de la pantalla.
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: value.argb == null ? 1 : 3,
                  color: value.argb == null ? palette.borderBright : accent,
                ),
              ),
              Positioned(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                bottom: AppSpacing.lg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      kicker.toUpperCase(),
                      style: label.copyWith(
                        color: hasImage && value.argb == null
                            ? Colors.white70
                            : accent,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.displayMedium(palette).copyWith(
                        fontSize: 40,
                        height: 1.05,
                        letterSpacing: -0.8,
                        color: hasImage ? Colors.white : palette.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              if (_hasMenu)
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: const CircleBorder(),
                    child: PopupMenuButton<_HeroAction>(
                      tooltip: 'Opciones de la pantalla',
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.more_horiz,
                        size: 18,
                        color: Colors.white70,
                      ),
                      onSelected: (action) => _run(context, action),
                      itemBuilder: (_) => [
                        if (onChanged != null) ...[
                          item(
                            _HeroAction.image,
                            Icons.image_outlined,
                            hasImage ? 'Cambiar imagen' : 'Elegir imagen',
                          ),
                          if (hasImage)
                            item(
                              _HeroAction.removeImage,
                              Icons.hide_image_outlined,
                              'Quitar imagen',
                            ),
                          item(
                            _HeroAction.color,
                            Icons.palette_outlined,
                            'Color de la pantalla',
                          ),
                        ],
                        if (onRename != null)
                          item(
                            _HeroAction.rename,
                            Icons.edit_outlined,
                            'Cambiar nombre',
                          ),
                        if (onReset != null) ...[
                          const PopupMenuDivider(),
                          item(
                            _HeroAction.reset,
                            Icons.restart_alt,
                            'Reiniciar pantalla',
                            color: palette.error,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [BibleScreenHero] enlazado a la definición de la sección: de ella toma el
/// nombre, la imagen y el color, y en ella los guarda.
class BibleSectionHero extends ConsumerWidget {
  final int projectId;
  final int bibleId;
  final String sectionId;

  /// Nombre mientras no se conozca el de la definición.
  final String title;

  /// Vacía lo que la pantalla guarda fuera de su definición, tras reiniciar
  /// su contenido.
  final VoidCallback? onAfterReset;

  const BibleSectionHero({
    super.key,
    required this.projectId,
    required this.bibleId,
    required this.sectionId,
    required this.title,
    this.onAfterReset,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    if (bibleId <= 0) {
      return BibleScreenHero(
        projectId: projectId,
        bibleId: bibleId,
        sectionId: sectionId,
        title: title,
      );
    }
    return StreamBuilder<BibleSectionDefinition?>(
      stream:
          (db.select(db.bibleSectionDefinitions)..where(
                (d) => d.bibleId.equals(bibleId) & d.id.equals(sectionId),
              ))
              .watchSingleOrNull(),
      builder: (context, snap) {
        final def = snap.data;
        if (def == null) {
          return BibleScreenHero(
            projectId: projectId,
            bibleId: bibleId,
            sectionId: sectionId,
            title: title,
          );
        }
        return BibleScreenHero(
          projectId: projectId,
          bibleId: bibleId,
          sectionId: sectionId,
          title: def.label.trim().isEmpty ? title : def.label,
          value: BibleScreenHeroValue.read(
            BibleSectionFieldsConfig.parseValues(def.contentJson),
          ),
          onChanged: (value) => db.saveBibleSectionFieldValue(
            bibleId,
            sectionId,
            BibleScreenHeroValue.key,
            value.encode(),
          ),
          onRename: (name) =>
              db.upsertBibleSectionDefinition(def.copyWith(label: name)),
          onReset: () async {
            await db.resetBibleSectionContent(
              bibleId,
              sectionId,
              keepValueKeys: const {BibleScreenHeroValue.key},
            );
            onAfterReset?.call();
          },
        );
      },
    );
  }
}
