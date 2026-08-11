import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/visual_bible/bible_section_ids.dart';
import '../../../../shared/visual_bible/narrative_card_kind.dart';
import '../../moodboard_helpers.dart';
import '../../services/lighting_narrative_cards_service.dart';
import '../../visual_bible_model.dart';
import '../bible_form_widgets.dart';
import '../bible_navigation_scope.dart';
import '../bible_paste_zone.dart';
import 'narrative_card_detail.dart';
import 'narrative_card_tile.dart';
import 'lighting_global_metrics_panel.dart';

/// Bloque del deck: cabecera + grid de cartas + CTA añadir.
class NarrativeDeckBlock extends ConsumerWidget {
  final int projectId;
  final int bibleId;
  final String sectionId;
  final String kind;
  final String title;
  final String? subtitle;
  final bool allowAdd;
  final bool allowDelete;
  final Widget Function(NarrativeCardModel card)? technicalPanelBuilder;

  const NarrativeDeckBlock({
    super.key,
    required this.projectId,
    required this.bibleId,
    required this.sectionId,
    required this.kind,
    required this.title,
    this.subtitle,
    this.allowAdd = true,
    this.allowDelete = true,
    this.technicalPanelBuilder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: AppTypography.mono(palette).copyWith(
                      fontSize: 12,
                      letterSpacing: 1.4,
                      color: palette.textTertiary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: AppTypography.bodyMedium(palette).copyWith(
                        color: palette.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (allowAdd)
              TextButton.icon(
                onPressed: () => _addCard(context, ref),
                icon: Icon(Icons.add, color: palette.accent, size: 18),
                label: Text('Añadir', style: TextStyle(color: palette.accent)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<VisualBibleNarrativeCard>>(
          stream: db.watchNarrativeCardsForSection(
            bibleId,
            sectionId,
            kind: kind,
          ),
          builder: (context, snap) {
            final cards = (snap.data ?? [])
                .map(NarrativeCardModel.fromRow)
                .toList();
            if (cards.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xB31A1A1C),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Text(
                  allowAdd
                      ? 'Aún no hay cartas. Añade la primera.'
                      : 'Sin contenido todavía.',
                  style: AppTypography.bodyMedium(palette).copyWith(
                    color: palette.textTertiary,
                  ),
                ),
              );
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final cross = w >= 900
                    ? 4
                    : w >= 600
                        ? 3
                        : 2;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: cards.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cross,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemBuilder: (context, i) {
                    final card = cards[i];
                    return NarrativeCardTile(
                      card: card,
                      onTap: () => _openCard(context, ref, card),
                      onDelete: allowDelete &&
                              card.kind != NarrativeCardKind.locationLight
                          ? () => _deleteCard(ref, card.id)
                          : null,
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  Future<void> _addCard(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final existing = await db
        .watchNarrativeCardsForSection(bibleId, sectionId, kind: kind)
        .first;
    final nextOrder = existing.isEmpty
        ? 0
        : existing.map((c) => c.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    final defaultTitle = switch (kind) {
      NarrativeCardKind.style => 'Nuevo estilo de luz',
      NarrativeCardKind.filmRef => 'Nueva referencia',
      NarrativeCardKind.locationLight => 'Localización',
      _ => 'Nueva carta',
    };
    final id = await db.insertNarrativeCard(
      VisualBibleNarrativeCardsCompanion.insert(
        bibleId: bibleId,
        sectionId: sectionId,
        kind: kind,
        title: defaultTitle,
        sortOrder: Value(nextOrder),
      ),
    );
    if (!context.mounted) return;
    await NarrativeCardDetailPage.open(
      context,
      projectId: projectId,
      bibleId: bibleId,
      cardId: id,
      technicalPanel: technicalPanelBuilder?.call(
        NarrativeCardModel(
          id: id,
          bibleId: bibleId,
          sectionId: sectionId,
          kind: kind,
          title: defaultTitle,
          sortOrder: nextOrder,
        ),
      ),
    );
  }

  Future<void> _deleteCard(WidgetRef ref, int id) async {
    await ref.read(databaseProvider).deleteNarrativeCard(id);
  }

  Future<void> _openCard(
    BuildContext context,
    WidgetRef ref,
    NarrativeCardModel card,
  ) {
    return NarrativeCardDetailPage.open(
      context,
      projectId: projectId,
      bibleId: bibleId,
      cardId: card.id,
      technicalPanel: technicalPanelBuilder?.call(card),
      onOpenLocation: card.kind == NarrativeCardKind.locationLight &&
              card.locationBasePlanId != null
          ? () => BibleNavigationScope.goToSection(
                context,
                BibleSectionId.location,
                planId: card.locationBasePlanId,
              )
          : null,
    );
  }
}

/// Hero + análisis general (carta overview o lightingData fallback).
class LightingOverviewBlock extends ConsumerStatefulWidget {
  final int projectId;
  final int bibleId;
  final Map<String, dynamic> lightingData;
  final Future<void> Function(Map<String, dynamic> patch) onUpdateLightingData;

  const LightingOverviewBlock({
    super.key,
    required this.projectId,
    required this.bibleId,
    required this.lightingData,
    required this.onUpdateLightingData,
  });

  @override
  ConsumerState<LightingOverviewBlock> createState() =>
      _LightingOverviewBlockState();
}

class _LightingOverviewBlockState extends ConsumerState<LightingOverviewBlock> {
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _seed());
  }

  Future<void> _seed() async {
    if (_seeded) return;
    _seeded = true;
    final db = ref.read(databaseProvider);
    await LightingNarrativeCardsService.ensureSeeded(
      db: db,
      bibleId: widget.bibleId,
      projectId: widget.projectId,
      lightingData: widget.lightingData,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);
    final data = widget.lightingData;

    return StreamBuilder<List<VisualBibleNarrativeCard>>(
      stream: db.watchNarrativeCardsForSection(
        widget.bibleId,
        BibleSectionId.lighting,
        kind: NarrativeCardKind.overview,
      ),
      builder: (context, snap) {
        final overview = snap.data?.isNotEmpty == true
            ? NarrativeCardModel.fromRow(snap.data!.first)
            : null;

        final badge = overview?.meta['heroBadge']?.toString() ??
            (data['heroBadge'] as String?) ??
            'ILUMINACIÓN';
        final title = overview?.title.isNotEmpty == true
            ? overview!.title
            : (data['heroTitle'] as String?) ?? 'Tratamiento de luz';
        final subtitle = overview?.meta['heroSubtitle']?.toString() ??
            (data['heroSubtitle'] as String?) ??
            '';
        final story = overview?.body?.isNotEmpty == true
            ? overview!.body!
            : (data['narrativeStory'] as String?) ?? '';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BibleCrossNavChips.techTriplet(current: BibleSectionId.lighting),
            const SizedBox(height: 12),
            _HeroBanner(
              projectId: widget.projectId,
              bibleId: widget.bibleId,
              overview: overview,
              badge: badge,
              title: title,
              subtitle: subtitle,
              palette: palette,
              db: db,
              onEditMeta: () => _editHero(context, overview, badge, title, subtitle),
              onCoverAssigned: (imageId) async {
                if (overview == null) return;
                final row = await db.getNarrativeCard(overview.id);
                if (row == null) return;
                await db.updateNarrativeCard(
                  row.copyWith(coverMoodboardImageId: Value(imageId)),
                );
                await db.assignMoodboardImageToCard(
                  imageId: imageId,
                  cardId: overview.id,
                  sectionId: BibleSectionId.lighting,
                );
              },
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 880;
                final narrative = _OverviewNarrativePanel(
                  palette: palette,
                  story: story,
                  onStoryChanged: (v) async {
                    await widget.onUpdateLightingData({'narrativeStory': v});
                    if (overview != null) {
                      final row = await db.getNarrativeCard(overview.id);
                      if (row != null) {
                        await db.updateNarrativeCard(
                          row.copyWith(
                            body: Value(v.trim().isEmpty ? null : v),
                          ),
                        );
                      }
                    }
                  },
                );
                final metrics = LightingGlobalMetricsPanel(
                  lightingData: data,
                  onUpdate: widget.onUpdateLightingData,
                );
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: narrative),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: metrics),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    narrative,
                    const SizedBox(height: 16),
                    metrics,
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _editHero(
    BuildContext context,
    NarrativeCardModel? overview,
    String badge,
    String title,
    String subtitle,
  ) async {
    final badgeCtrl = TextEditingController(text: badge);
    final titleCtrl = TextEditingController(text: title);
    final subCtrl = TextEditingController(text: subtitle);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hero de iluminación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: badgeCtrl,
              decoration: const InputDecoration(labelText: 'Badge'),
            ),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            TextField(
              controller: subCtrl,
              decoration: const InputDecoration(labelText: 'Subtítulo'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final db = ref.read(databaseProvider);
    await widget.onUpdateLightingData({
      'heroBadge': badgeCtrl.text.trim(),
      'heroTitle': titleCtrl.text.trim(),
      'heroSubtitle': subCtrl.text.trim(),
    });
    if (overview != null) {
      final row = await db.getNarrativeCard(overview.id);
      if (row == null) return;
      final meta = Map<String, dynamic>.from(overview.meta);
      meta['heroBadge'] = badgeCtrl.text.trim();
      meta['heroSubtitle'] = subCtrl.text.trim();
      await db.updateNarrativeCard(
        row.copyWith(
          title: titleCtrl.text.trim().isEmpty
              ? overview.title
              : titleCtrl.text.trim(),
          metaJson: Value(jsonEncode(meta)),
        ),
      );
    }
  }
}

class _OverviewNarrativePanel extends StatelessWidget {
  final AppPalette palette;
  final String story;
  final Future<void> Function(String value) onStoryChanged;

  const _OverviewNarrativePanel({
    required this.palette,
    required this.story,
    required this.onStoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xB31A1A1C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PUNTOS CLAVE',
            style: AppTypography.mono(palette).copyWith(
              fontSize: 11,
              letterSpacing: 1.2,
              color: palette.textTertiary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Lo más importante que vamos a destacar de la luz en el proyecto',
            style: AppTypography.bodyMedium(palette).copyWith(
              fontSize: 12,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          BibleTextField(
            label: 'Estrategia e intención narrativa',
            hint:
                'Alto contraste motivado por prácticos, dualismo de sombra, '
                'alienación mediante top-light…',
            maxLines: 8,
            initialValue: story,
            onChanged: onStoryChanged,
          ),
        ],
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final int projectId;
  final int bibleId;
  final NarrativeCardModel? overview;
  final String badge;
  final String title;
  final String subtitle;
  final AppPalette palette;
  final AppDatabase db;
  final VoidCallback onEditMeta;
  final Future<void> Function(int imageId) onCoverAssigned;

  const _HeroBanner({
    required this.projectId,
    required this.bibleId,
    required this.overview,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.palette,
    required this.db,
    required this.onEditMeta,
    required this.onCoverAssigned,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BibleTargetZone(
        hint: '⌘V hero de iluminación',
        minHeight: 220,
        onPaste: (payload) async {
          if (overview == null) return;
          final id = await MoodboardHelpers.addImageForNarrativeCard(
            db: db,
            projectId: projectId,
            bibleId: bibleId,
            cardId: overview!.id,
            sectionId: BibleSectionId.lighting,
            bytes: payload.bytes,
            extension: payload.extension,
            asCover: true,
          );
          await onCoverAssigned(id);
        },
        onMoodboardDropped: (drag) async {
          if (overview == null) return;
          await MoodboardHelpers.linkMoodboardToSection(
            db: db,
            projectId: projectId,
            payload: drag,
            sectionId: BibleSectionId.lighting,
            cardId: overview!.id,
          );
          if (drag.moodboardImageId != null) {
            await onCoverAssigned(drag.moodboardImageId!);
          }
        },
        child: SizedBox(
          height: 260,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _HeroImage(
                db: db,
                projectId: projectId,
                overview: overview,
                palette: palette,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.15),
                      Colors.black.withValues(alpha: 0.75),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: InkWell(
                  onTap: onEditMeta,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        badge.toUpperCase(),
                        style: AppTypography.mono(palette).copyWith(
                          fontSize: 11,
                          letterSpacing: 1.4,
                          color: palette.accent,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        style: AppTypography.bodyMedium(palette).copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: AppTypography.bodyMedium(palette).copyWith(
                            color: Colors.white70,
                          ),
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

class _HeroImage extends StatelessWidget {
  final AppDatabase db;
  final int projectId;
  final NarrativeCardModel? overview;
  final AppPalette palette;

  const _HeroImage({
    required this.db,
    required this.projectId,
    required this.overview,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final coverId = overview?.coverMoodboardImageId;
    if (coverId != null) {
      return FutureBuilder<MoodboardImage?>(
        future: (db.select(db.moodboardImages)
              ..where((m) => m.id.equals(coverId)))
            .getSingleOrNull(),
        builder: (context, snap) {
          final path = snap.data?.imagePath;
          if (path != null && File(path).existsSync()) {
            return Opacity(
              opacity: 0.7,
              child: Image.file(File(path), fit: BoxFit.cover),
            );
          }
          return _sectionFallback();
        },
      );
    }
    return _sectionFallback();
  }

  Widget _sectionFallback() {
    return StreamBuilder<List<MoodboardImage>>(
      stream: db.watchMoodboardImagesForSection(
        projectId,
        BibleSectionId.lighting,
      ),
      builder: (context, snap) {
        final imgs = snap.data ?? [];
        if (imgs.isNotEmpty && File(imgs.first.imagePath).existsSync()) {
          return Opacity(
            opacity: 0.55,
            child: Image.file(File(imgs.first.imagePath), fit: BoxFit.cover),
          );
        }
        return ColoredBox(color: palette.surfaceOverlay);
      },
    );
  }
}
