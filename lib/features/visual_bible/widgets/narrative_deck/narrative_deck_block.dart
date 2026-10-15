import '../lighting/lighting_card_view.dart';
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
import '../../services/lighting_narrative_cards_service.dart';
import '../../visual_bible_model.dart';
import '../bible_form_widgets.dart';
import '../bible_navigation_scope.dart';
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
            // Una referencia de cine es una película o un grupo de stills.
            if (allowAdd && kind == NarrativeCardKind.filmRef)
              PopupMenuButton<String>(
                tooltip: 'Añadir referencia',
                onSelected: (type) => _addCard(context, ref, refType: type),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'film', child: Text('Una película')),
                  PopupMenuItem(
                    value: 'stills',
                    child: Text('Un grupo de stills'),
                  ),
                ],
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Icon(Icons.add, color: palette.accent, size: 18),
                      const SizedBox(width: 6),
                      Text('Añadir', style: TextStyle(color: palette.accent)),
                    ],
                  ),
                ),
              )
            else if (allowAdd)
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
                    childAspectRatio: 0.78,
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

  Future<void> _addCard(
    BuildContext context,
    WidgetRef ref, {
    String? refType,
  }) async {
    final db = ref.read(databaseProvider);
    final existing = await db
        .watchNarrativeCardsForSection(bibleId, sectionId, kind: kind)
        .first;
    final nextOrder = existing.isEmpty
        ? 0
        : existing.map((c) => c.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    final defaultTitle = switch (kind) {
      NarrativeCardKind.style => 'Nueva idea de luz',
      NarrativeCardKind.filmRef =>
        refType == 'stills' ? 'Grupo de stills' : 'Nueva película',
      NarrativeCardKind.locationLight => 'Localización',
      _ => 'Nueva carta',
    };
    final id = await db.insertNarrativeCard(
      VisualBibleNarrativeCardsCompanion.insert(
        bibleId: bibleId,
        sectionId: sectionId,
        kind: kind,
        title: defaultTitle,
        metaJson: Value(
          refType == 'stills' ? jsonEncode({'refType': 'stills'}) : null,
        ),
        sortOrder: Value(nextOrder),
      ),
    );
    if (!context.mounted) return;
    await openLightingCard(
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
    return openLightingCard(
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

        final story = overview?.body?.isNotEmpty == true
            ? overview!.body!
            : (data['narrativeStory'] as String?) ?? '';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BibleCrossNavChips.techTriplet(current: BibleSectionId.lighting),
            const SizedBox(height: 12),
            // La imagen y el nombre del tratamiento van en la cabecera de la
            // pantalla: aquí no se repiten.
            LayoutBuilder(
              builder: (context, constraints) {
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
                // Las métricas van a todo el ancho: enseñan todos los ratios.
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

