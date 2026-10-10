import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/visual_bible/bible_section_fields.dart';
import '../../../../shared/visual_bible/bible_section_ids.dart';
import '../../../../shared/visual_bible/lighting_card_page.dart';
import '../../../../shared/visual_bible/lighting_metrics.dart';
import '../../../../shared/visual_bible/narrative_card_kind.dart';
import '../bible_point_images.dart';
import '../bible_point_panel.dart';
import '../bible_points_host.dart';
import '../narrative_deck/narrative_card_detail.dart';
import 'lighting_metrics_widget.dart';

Map<String, dynamic> lightingCardMeta(VisualBibleNarrativeCard? card) {
  final raw = card?.metaJson;
  if (raw == null || raw.isEmpty) return {};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
  } catch (_) {}
  return {};
}

LightingCardPage lightingCardPageOf(VisualBibleNarrativeCard card) =>
    LightingCardPage.of(
      kind: card.kind,
      body: card.body,
      meta: lightingCardMeta(card),
    );

/// Una ficha de Iluminación desarrollada: cabecera con su imagen, su
/// título y sus datos, y debajo sus puntos, que se añaden, se quitan y se
/// ordenan como en una pantalla de la biblia.
class LightingCardView extends ConsumerStatefulWidget {
  final int projectId;
  final int bibleId;
  final int cardId;

  /// Título fijo (p. ej. el nombre del set). Nulo: se edita el de la ficha.
  final String? fixedTitle;

  /// Métricas generales del proyecto, para comparar.
  final LightingMetrics? globalMetrics;

  /// Botones a la derecha de la cabecera.
  final List<Widget> actions;

  const LightingCardView({
    super.key,
    required this.projectId,
    required this.bibleId,
    required this.cardId,
    this.fixedTitle,
    this.globalMetrics,
    this.actions = const [],
  });

  @override
  ConsumerState<LightingCardView> createState() => _LightingCardViewState();
}

class _LightingCardViewState extends ConsumerState<LightingCardView> {
  /// Las escrituras van en fila: cada una parte de la fila más reciente,
  /// así dos cambios seguidos no se pisan.
  Future<void> _queue = Future.value();

  AppDatabase get _db => ref.read(databaseProvider);

  void _write(
    VisualBibleNarrativeCard Function(
      VisualBibleNarrativeCard fresh,
      Map<String, dynamic> meta,
      LightingCardPage page,
    )
    change,
  ) {
    _queue = _queue.then((_) async {
      final fresh = await _db.getNarrativeCard(widget.cardId);
      if (fresh == null) return;
      await _db.updateNarrativeCard(
        change(fresh, lightingCardMeta(fresh), lightingCardPageOf(fresh)),
      );
    });
  }

  static Value<String?> _encode(Map<String, dynamic> meta) =>
      Value(meta.isEmpty ? null : jsonEncode(meta));

  void _setValue(String key, String? value) => _write((fresh, meta, page) {
    if (key == LightingCardPage.bodyKey) {
      final text = value?.trim() ?? '';
      return fresh.copyWith(
        body: Value(text.isEmpty ? null : text),
        // Fija la lista de puntos la primera vez que se escribe.
        metaJson: _encode({...meta, 'page': page.toJson()}),
      );
    }
    if (key == LightingCardPage.light) {
      final metrics = LightingMetrics.fromJson(value);
      return fresh.copyWith(
        metaJson: _encode({
          ...meta,
          'light': metrics.toJson(),
          'page': page.toJson(),
        }),
      );
    }
    return fresh.copyWith(
      metaJson: _encode({
        ...meta,
        'page': page.withValue(key, value).toJson(),
      }),
    );
  });

  void _setFields(
    List<BibleSectionField> fields, {
    Set<String> dropValues = const {},
  }) => _write(
    (fresh, meta, page) => fresh.copyWith(
      // Quitar el punto del cuerpo o el de luz quita también su contenido.
      body: dropValues.contains(LightingCardPage.bodyKey)
          ? const Value(null)
          : Value(fresh.body),
      metaJson: _encode({
        ...meta,
        if (dropValues.contains(LightingCardPage.light)) 'light': null,
        'page': page.withFields(fields, dropValues: dropValues).toJson(),
      }..removeWhere((key, value) => value == null)),
    ),
  );

  Future<void> _pickCover(VisualBibleNarrativeCard card) async {
    final picked = await showMoodboardImagePicker(
      context,
      projectId: widget.projectId,
      bibleId: widget.bibleId,
      sectionId: BibleSectionId.lighting,
      selected: [
        if (card.coverMoodboardImageId != null) card.coverMoodboardImageId!,
      ],
      single: true,
    );
    if (picked == null) return;
    _write(
      (fresh, meta, page) => fresh.copyWith(
        coverMoodboardImageId: Value(picked.isEmpty ? null : picked.first),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    return StreamBuilder<VisualBibleNarrativeCard?>(
      stream: (db.select(
        db.visualBibleNarrativeCards,
      )..where((c) => c.id.equals(widget.cardId))).watchSingleOrNull(),
      builder: (context, snap) {
        final card = snap.data;
        if (card == null) return const SizedBox.shrink();
        final page = lightingCardPageOf(card);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              projectId: widget.projectId,
              card: card,
              page: page,
              fixedTitle: widget.fixedTitle,
              actions: widget.actions,
              onPickCover: () => _pickCover(card),
              onTitle: (title) => _write(
                (fresh, meta, page) => fresh.copyWith(title: title.trim()),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            BiblePointsHost(
              projectId: widget.projectId,
              bibleId: widget.bibleId,
              sectionId: BibleSectionId.lighting,
              fields: page.fields,
              values: page.values,
              onFieldsChanged: _setFields,
              onValueChanged: _setValue,
              overrides: {
                // Con el valor general del proyecto marcado, para comparar.
                for (final field in page.fields)
                  if (field.key == LightingCardPage.light)
                    field.key: BiblePointPanel(
                      label: field.label,
                      icon: Icons.wb_incandescent_outlined,
                      child: LightingMetricsWidget(
                        value: page.metrics,
                        reference: widget.globalMetrics,
                        onChanged: (next) =>
                            _setValue(LightingCardPage.light, next.encode()),
                      ),
                    ),
              },
            ),
          ],
        );
      },
    );
  }
}

/// Cabecera de ficha: la imagen a todo el ancho, con el título encima y
/// las pastillas de dato.
class _Header extends ConsumerWidget {
  final int projectId;
  final VisualBibleNarrativeCard card;
  final LightingCardPage page;
  final String? fixedTitle;
  final List<Widget> actions;
  final VoidCallback onPickCover;
  final ValueChanged<String> onTitle;

  const _Header({
    required this.projectId,
    required this.card,
    required this.page,
    required this.fixedTitle,
    required this.actions,
    required this.onPickCover,
    required this.onTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);
    final coverId = card.coverMoodboardImageId ?? page.firstImageId;
    final metrics = page.metrics;
    final ratio = metrics.ratioOption;
    final titleStyle = AppTypography.displayMedium(
      palette,
    ).copyWith(color: Colors.white, fontSize: 30, height: 1.1);

    Widget pill(Widget child) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: child,
    );
    final mono = AppTypography.mono(
      palette,
    ).copyWith(color: Colors.white, fontSize: 12);

    return StreamBuilder<List<MoodboardImage>>(
      stream: db.watchMoodboardImages(projectId),
      builder: (context, snap) {
        String? path;
        for (final image in snap.data ?? const <MoodboardImage>[]) {
          if (image.id == coverId) path = image.imagePath;
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(BiblePointPanel.radius),
          child: SizedBox(
            height: path == null ? 170 : 300,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (path != null)
                  Image.file(
                    File(path),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        ColoredBox(color: palette.surfaceElevated),
                  )
                else
                  ColoredBox(color: palette.surfaceElevated),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x33000000), Color(0xE6000000)],
                    ),
                  ),
                ),
                Positioned(
                  top: AppSpacing.md,
                  right: AppSpacing.md,
                  child: Row(
                    children: [
                      ...actions,
                      TextButton.icon(
                        onPressed: onPickCover,
                        icon: const Icon(
                          Icons.image_outlined,
                          size: 16,
                          color: Colors.white70,
                        ),
                        label: Text(
                          path == null ? 'Poner portada' : 'Cambiar portada',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
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
                        NarrativeCardKind.label(card.kind).toUpperCase(),
                        style: BiblePointPanel.labelStyle(
                          palette,
                        ).copyWith(color: palette.accent),
                      ),
                      const SizedBox(height: 4),
                      if (fixedTitle != null)
                        Text(fixedTitle!, style: titleStyle)
                      else
                        TextFormField(
                          key: ValueKey('card_title_${card.id}'),
                          initialValue: card.title,
                          style: titleStyle,
                          decoration: InputDecoration(
                            hintText: 'Título',
                            hintStyle: titleStyle.copyWith(
                              color: Colors.white38,
                            ),
                            isDense: true,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                          onChanged: onTitle,
                        ),
                      if (metrics.kelvin != null || ratio != null) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (metrics.kelvin != null)
                              pill(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: Color(
                                          0xFF000000 | metrics.color!,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text('${metrics.kelvin} K', style: mono),
                                  ],
                                ),
                              ),
                            if (ratio != null)
                              pill(
                                Text(
                                  '${ratio.label} · ${ratio.use}',
                                  style: mono,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// La ficha como página propia, para ideas de luz y referencias de cine.
class LightingCardScreen extends StatelessWidget {
  final int projectId;
  final int bibleId;
  final int cardId;
  final LightingMetrics? globalMetrics;

  /// Abre el detalle anterior (etiquetas e imágenes emparejadas).
  final VoidCallback? onOpenLegacy;

  const LightingCardScreen({
    super.key,
    required this.projectId,
    required this.bibleId,
    required this.cardId,
    this.globalMetrics,
    this.onOpenLegacy,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        title: Text(
          'Iluminación',
          style: AppTypography.bodyMedium(
            palette,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (onOpenLegacy != null)
            TextButton(
              onPressed: onOpenLegacy,
              child: const Text('Etiquetas del moodboard'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          LightingCardView(
            projectId: projectId,
            bibleId: bibleId,
            cardId: cardId,
            globalMetrics: globalMetrics,
          ),
        ],
      ),
    );
  }
}

/// Abre la ficha desarrollada de una idea de luz o una referencia de cine.
/// Desde ella se llega al detalle anterior, que conserva las etiquetas y
/// las imágenes emparejadas del moodboard.
Future<void> openLightingCard(
  BuildContext context, {
  required int projectId,
  required int bibleId,
  required int cardId,
  LightingMetrics? globalMetrics,
  Widget? technicalPanel,
  VoidCallback? onOpenLocation,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (pageContext) => LightingCardScreen(
      projectId: projectId,
      bibleId: bibleId,
      cardId: cardId,
      globalMetrics: globalMetrics,
      onOpenLegacy: () => NarrativeCardDetailPage.open(
        pageContext,
        projectId: projectId,
        bibleId: bibleId,
        cardId: cardId,
        technicalPanel: technicalPanel,
        onOpenLocation: onOpenLocation,
      ),
    ),
  ),
);
