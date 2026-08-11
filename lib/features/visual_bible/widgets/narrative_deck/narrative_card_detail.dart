import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/visual_bible/narrative_card_kind.dart';
import '../../moodboard_helpers.dart';
import '../../moodboard_reference_meta.dart';
import '../../services/lighting_narrative_cards_service.dart';
import '../../services/moodboard_lighting_link_service.dart';
import '../../visual_bible_model.dart';
import '../bible_form_widgets.dart';
import '../bible_paste_zone.dart';
import 'container_detail/container_header_tags.dart';
import 'container_detail/container_hero_with_caption.dart';
import 'container_detail/container_metrics_panel.dart';
import 'container_detail/container_palette_panel.dart';
import 'container_detail/container_stills_grid.dart';
import 'container_detail/reinforcement_blocks.dart';
import '../moodboard_drag.dart';
import 'lighting_card_tag_fields.dart';

/// Detalle editable de una carta narrativa (drill-down).
class NarrativeCardDetailPage extends ConsumerStatefulWidget {
  final int projectId;
  final int bibleId;
  final int cardId;
  final Widget? technicalPanel;
  final VoidCallback? onOpenLocation;

  const NarrativeCardDetailPage({
    super.key,
    required this.projectId,
    required this.bibleId,
    required this.cardId,
    this.technicalPanel,
    this.onOpenLocation,
  });

  static Future<void> open(
    BuildContext context, {
    required int projectId,
    required int bibleId,
    required int cardId,
    Widget? technicalPanel,
    VoidCallback? onOpenLocation,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NarrativeCardDetailPage(
          projectId: projectId,
          bibleId: bibleId,
          cardId: cardId,
          technicalPanel: technicalPanel,
          onOpenLocation: onOpenLocation,
        ),
      ),
    );
  }

  @override
  ConsumerState<NarrativeCardDetailPage> createState() =>
      _NarrativeCardDetailPageState();
}

class _NarrativeCardDetailPageState
    extends ConsumerState<NarrativeCardDetailPage> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();
  final _filmTitleCtrl = TextEditingController();
  final _filmDpCtrl = TextEditingController();
  final _filmYearCtrl = TextEditingController();
  final _captionCtrl = TextEditingController();
  NarrativeCardModel? _card;
  bool _techExpanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _summaryCtrl.dispose();
    _filmTitleCtrl.dispose();
    _filmDpCtrl.dispose();
    _filmYearCtrl.dispose();
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final row = await db.getNarrativeCard(widget.cardId);
    if (row == null || !mounted) return;
    final model = NarrativeCardModel.fromRow(row);
    setState(() {
      _card = model;
      _titleCtrl.text = model.title;
      _bodyCtrl.text = model.body ?? '';
      _summaryCtrl.text = model.meta['summary']?.toString() ?? '';
      _filmTitleCtrl.text = model.filmTitle ?? '';
      _filmDpCtrl.text = model.filmDp ?? '';
      _filmYearCtrl.text = model.filmYear ?? '';
      _captionCtrl.text = model.heroCaption ?? '';
    });
    if (model.kind == NarrativeCardKind.style &&
        model.coverMoodboardImageId != null &&
        (model.heroCaption == null || model.heroCaption!.isEmpty)) {
      final coverMeta = await MoodboardReferenceMetaStore.load(
        ref.read(databaseProvider),
        model.coverMoodboardImageId!,
      );
      if (mounted && coverMeta.technicalNotes?.trim().isNotEmpty == true) {
        _captionCtrl.text = coverMeta.technicalNotes!.trim();
      }
    }
  }

  Future<void> _saveFields() async {
    final card = _card;
    if (card == null) return;
    card.title = _titleCtrl.text.trim().isEmpty
        ? card.title
        : _titleCtrl.text.trim();
    card.body = _bodyCtrl.text.trim().isEmpty ? null : _bodyCtrl.text.trim();
    card.summary =
        _summaryCtrl.text.trim().isEmpty ? null : _summaryCtrl.text.trim();
    if (card.kind == NarrativeCardKind.style) {
      card.heroCaption =
          _captionCtrl.text.trim().isEmpty ? null : _captionCtrl.text.trim();
    }
    if (card.kind == NarrativeCardKind.filmRef) {
      card.filmTitle = _filmTitleCtrl.text;
      card.filmDp = _filmDpCtrl.text;
      card.filmYear = _filmYearCtrl.text;
    }
    final db = ref.read(databaseProvider);
    if (card.kind == NarrativeCardKind.style &&
        card.coverMoodboardImageId != null) {
      final coverId = card.coverMoodboardImageId!;
      final coverMeta = await MoodboardReferenceMetaStore.load(db, coverId);
      await MoodboardReferenceMetaStore.save(
        db,
        coverId,
        coverMeta.copyWith(technicalNotes: card.heroCaption),
      );
    }
    final row = await db.getNarrativeCard(card.id);
    if (row == null) return;
    await db.updateNarrativeCard(
      row.copyWith(
        title: card.title,
        body: Value(card.body),
        metaJson: Value(card.meta.isEmpty ? null : jsonEncode(card.meta)),
      ),
    );
    if (card.kind == NarrativeCardKind.locationLight) {
      await LightingNarrativeCardsService.syncSummaryToLocationRef(
        db: db,
        card: card,
      );
    }
    if (card.kind == NarrativeCardKind.style ||
        card.kind == NarrativeCardKind.filmRef) {
      await MoodboardLightingLinkService.linkAllTaggedImages(
        db: db,
        projectId: widget.projectId,
        bibleId: widget.bibleId,
      );
    }
    if (mounted) setState(() => _card = card);
  }

  Future<void> _setCover(int imageId) async {
    final card = _card;
    if (card == null) return;
    card.coverMoodboardImageId = imageId;
    final db = ref.read(databaseProvider);
    final row = await db.getNarrativeCard(card.id);
    if (row == null) return;
    await db.updateNarrativeCard(
      row.copyWith(coverMoodboardImageId: Value(imageId)),
    );
    await db.assignMoodboardImageToCard(
      imageId: imageId,
      cardId: card.id,
      sectionId: card.sectionId,
    );
    if (mounted) setState(() => _card = card);
  }

  Future<void> _persistCardMeta(NarrativeCardModel card) async {
    final db = ref.read(databaseProvider);
    final row = await db.getNarrativeCard(card.id);
    if (row == null) return;
    await db.updateNarrativeCard(
      row.copyWith(
        metaJson: Value(card.meta.isEmpty ? null : jsonEncode(card.meta)),
      ),
    );
    if (card.kind == NarrativeCardKind.style ||
        card.kind == NarrativeCardKind.filmRef) {
      await MoodboardLightingLinkService.linkAllTaggedImages(
        db: db,
        projectId: widget.projectId,
        bibleId: widget.bibleId,
      );
    }
    if (mounted) setState(() => _card = card);
  }

  Future<List<MoodboardImageModel>> _matchedImagesForCard(
    AppDatabase db,
    NarrativeCardModel card,
  ) async {
    final rows = await db.watchMoodboardImages(widget.projectId).first;
    final metaById = await MoodboardReferenceMetaStore.loadMany(
      db,
      rows.map((r) => r.id),
    );
    final pool = rows
        .map(
          (r) => MoodboardImageModel.fromRow(r).copyWith(
            meta: metaById[r.id] ?? const MoodboardReferenceMeta(),
          ),
        )
        .toList();
    return MoodboardLightingLinkService.imagesMatchingContainer(
      pool: pool,
      container: card,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final card = _card;
    final db = ref.watch(databaseProvider);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        title: Text(
          card == null ? 'Detalle' : NarrativeCardKind.label(card.kind),
          style: AppTypography.bodyMedium(palette).copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (card?.kind == NarrativeCardKind.locationLight &&
              widget.onOpenLocation != null)
            TextButton(
              onPressed: widget.onOpenLocation,
              child: const Text('Ver en Localización'),
            ),
          TextButton(
            onPressed: _saveFields,
            child: Text('Guardar', style: TextStyle(color: palette.accent)),
          ),
        ],
      ),
      body: card == null
          ? const Center(child: CircularProgressIndicator())
          : card.kind == NarrativeCardKind.style
              ? _StyleContainerDetailBody(
                  projectId: widget.projectId,
                  bibleId: widget.bibleId,
                  card: card,
                  db: db,
                  palette: palette,
                  titleCtrl: _titleCtrl,
                  bodyCtrl: _bodyCtrl,
                  captionCtrl: _captionCtrl,
                  techExpanded: _techExpanded,
                  technicalPanel: widget.technicalPanel,
                  onTechExpandedChanged: (v) =>
                      setState(() => _techExpanded = v),
                  onCardUpdated: (updated) => setState(() => _card = updated),
                  onPersistMeta: _persistCardMeta,
                  onCoverSet: _setCover,
                  matchedImagesLoader: () =>
                      _matchedImagesForCard(db, card),
                )
              : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _CoverEditor(
                  projectId: widget.projectId,
                  bibleId: widget.bibleId,
                  card: card,
                  db: db,
                  palette: palette,
                  onCoverSet: _setCover,
                  onGalleryAdded: () => setState(() {}),
                ),
                const SizedBox(height: 20),
                BibleTextField(
                  label: 'Título',
                  controller: _titleCtrl,
                  onChanged: (_) {},
                ),
                const SizedBox(height: 12),
                if (card.kind == NarrativeCardKind.filmRef) ...[
                  BibleTextField(
                    label: 'Película',
                    controller: _filmTitleCtrl,
                    onChanged: (_) {},
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: BibleTextField(
                          label: 'DP',
                          controller: _filmDpCtrl,
                          onChanged: (_) {},
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: BibleTextField(
                          label: 'Año',
                          controller: _filmYearCtrl,
                          onChanged: (_) {},
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (card.kind == NarrativeCardKind.filmRef) ...[
                  LightingCardTagFields(
                    card: card,
                    palette: palette,
                    onChanged: (updated) {
                      setState(() => _card = updated);
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'STILLS COINCIDENTES',
                    style: AppTypography.mono(palette).copyWith(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      color: palette.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _TagMatchedPreview(
                    projectId: widget.projectId,
                    card: card,
                    db: db,
                    palette: palette,
                  ),
                  const SizedBox(height: 16),
                ],
                if (card.kind == NarrativeCardKind.locationLight) ...[
                  BibleTextField(
                    label: 'Pincelada para Localización',
                    controller: _summaryCtrl,
                    maxLines: 3,
                    onChanged: (_) {},
                  ),
                  const SizedBox(height: 12),
                ],
                BibleTextField(
                  label: card.kind == NarrativeCardKind.filmRef
                      ? 'Por qué es referente de luz'
                      : card.kind == NarrativeCardKind.locationLight
                          ? 'Cómo funciona la luz en esta localización'
                          : 'Desarrollo',
                  controller: _bodyCtrl,
                  maxLines: 8,
                  onChanged: (_) {},
                ),
                const SizedBox(height: 24),
                Text(
                  'IMÁGENES DE REFUERZO',
                  style: AppTypography.mono(palette).copyWith(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    color: palette.textTertiary,
                  ),
                ),
                const SizedBox(height: 10),
                _CardGallery(
                  projectId: widget.projectId,
                  bibleId: widget.bibleId,
                  card: card,
                  db: db,
                  palette: palette,
                  onChanged: () => setState(() {}),
                ),
                if (widget.technicalPanel != null) ...[
                  const SizedBox(height: 24),
                  ExpansionTile(
                    initiallyExpanded: _techExpanded,
                    onExpansionChanged: (v) =>
                        setState(() => _techExpanded = v),
                    title: Text(
                      'Técnica de set',
                      style: AppTypography.bodyMedium(palette).copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: widget.technicalPanel!,
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

class _CoverEditor extends StatelessWidget {
  final int projectId;
  final int bibleId;
  final NarrativeCardModel card;
  final AppDatabase db;
  final AppPalette palette;
  final Future<void> Function(int imageId) onCoverSet;
  final VoidCallback onGalleryAdded;

  const _CoverEditor({
    required this.projectId,
    required this.bibleId,
    required this.card,
    required this.db,
    required this.palette,
    required this.onCoverSet,
    required this.onGalleryAdded,
  });

  @override
  Widget build(BuildContext context) {
    return BibleTargetZone(
      hint: '⌘V o arrastra cover',
      minHeight: 180,
      onPaste: (payload) async {
        final id = await MoodboardHelpers.addImageForNarrativeCard(
          db: db,
          projectId: projectId,
          bibleId: bibleId,
          cardId: card.id,
          sectionId: card.sectionId,
          bytes: payload.bytes,
          extension: payload.extension,
          locationBasePlanId: card.locationBasePlanId,
          asCover: true,
        );
        await onCoverSet(id);
        onGalleryAdded();
      },
      onMoodboardDropped: (drag) async {
        await MoodboardHelpers.linkMoodboardToSection(
          db: db,
          projectId: projectId,
          payload: drag,
          sectionId: card.sectionId,
          locationBasePlanId: card.locationBasePlanId,
          cardId: card.id,
        );
        if (drag.moodboardImageId != null) {
          await onCoverSet(drag.moodboardImageId!);
        }
        onGalleryAdded();
      },
      child: SizedBox(
        height: 200,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: card.coverMoodboardImageId == null
              ? ColoredBox(
                  color: Colors.white.withValues(alpha: 0.04),
                  child: Center(
                    child: Text(
                      'Portada — ⌘V para pegar',
                      style: AppTypography.bodyMedium(palette).copyWith(
                        color: palette.textTertiary,
                      ),
                    ),
                  ),
                )
              : FutureBuilder<MoodboardImage?>(
                  future: (db.select(db.moodboardImages)
                        ..where(
                          (m) => m.id.equals(card.coverMoodboardImageId!),
                        ))
                      .getSingleOrNull(),
                  builder: (context, snap) {
                    final path = snap.data?.imagePath;
                    if (path != null && File(path).existsSync()) {
                      return Image.file(File(path), fit: BoxFit.cover);
                    }
                    return ColoredBox(
                      color: Colors.white.withValues(alpha: 0.04),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _CardGallery extends StatelessWidget {
  final int projectId;
  final int bibleId;
  final NarrativeCardModel card;
  final AppDatabase db;
  final AppPalette palette;
  final VoidCallback onChanged;

  const _CardGallery({
    required this.projectId,
    required this.bibleId,
    required this.card,
    required this.db,
    required this.palette,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BibleTargetZone(
      hint: 'Añadir stills de refuerzo',
      minHeight: 100,
      onPaste: (payload) async {
        await MoodboardHelpers.addImageForNarrativeCard(
          db: db,
          projectId: projectId,
          bibleId: bibleId,
          cardId: card.id,
          sectionId: card.sectionId,
          bytes: payload.bytes,
          extension: payload.extension,
          locationBasePlanId: card.locationBasePlanId,
        );
        onChanged();
      },
      onMoodboardDropped: (drag) async {
        await MoodboardHelpers.linkMoodboardToSection(
          db: db,
          projectId: projectId,
          payload: drag,
          sectionId: card.sectionId,
          locationBasePlanId: card.locationBasePlanId,
          cardId: card.id,
        );
        onChanged();
      },
      child: StreamBuilder<List<MoodboardImage>>(
        stream: db.watchMoodboardImagesForCard(projectId, card.id),
        builder: (context, snap) {
          final imgs = snap.data ?? [];
          if (imgs.isEmpty) {
            return Container(
              height: 100,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Text(
                'Sin stills — ⌘V o arrastra desde moodboard',
                style: AppTypography.bodyMedium(palette).copyWith(
                  fontSize: 12,
                  color: palette.textTertiary,
                ),
              ),
            );
          }
          return SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: imgs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final img = imgs[i];
                return ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: File(img.imagePath).existsSync()
                      ? Image.file(
                          File(img.imagePath),
                          width: 160,
                          height: 120,
                          fit: BoxFit.cover,
                        )
                      : SizedBox(
                          width: 160,
                          child: ColoredBox(
                            color: Colors.white.withValues(alpha: 0.04),
                          ),
                        ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Vista previa de stills del moodboard que coinciden con las etiquetas de la carta.
class _TagMatchedPreview extends StatelessWidget {
  final int projectId;
  final NarrativeCardModel card;
  final AppDatabase db;
  final AppPalette palette;

  const _TagMatchedPreview({
    required this.projectId,
    required this.card,
    required this.db,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MoodboardImage>>(
      stream: db.watchMoodboardImages(projectId),
      builder: (context, snap) {
        return FutureBuilder<Map<int, MoodboardReferenceMeta>>(
          future: MoodboardReferenceMetaStore.loadMany(
            db,
            (snap.data ?? []).map((r) => r.id),
          ),
          builder: (context, metaSnap) {
            final metaById = metaSnap.data ?? {};
            final pool = <MoodboardImageModel>[];
            for (final row in snap.data ?? []) {
              final meta = metaById[row.id] ?? const MoodboardReferenceMeta();
              pool.add(MoodboardImageModel.fromRow(row).copyWith(meta: meta));
            }
            final matched =
                MoodboardLightingLinkService.imagesMatchingContainer(
              pool: pool,
              container: card,
            );
            final criteria = LightingBehaviorTagFilter.fromCard(card);
            if (matched.isEmpty) {
              return Text(
                criteria.hasAny
                    ? 'Ningún still del moodboard coincide aún con estos tags.'
                    : 'Define tags arriba para ver stills coincidentes del moodboard.',
                style: AppTypography.bodyMedium(palette).copyWith(
                  fontSize: 12,
                  color: palette.textTertiary,
                ),
              );
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                final cross = constraints.maxWidth >= 700
                    ? 3
                    : constraints.maxWidth >= 420
                        ? 2
                        : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: matched.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cross,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.35,
                  ),
                  itemBuilder: (context, i) {
                    final path = matched[i].imagePath;
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: File(path).existsSync()
                          ? Image.file(File(path), fit: BoxFit.cover)
                          : ColoredBox(
                              color: Colors.white.withValues(alpha: 0.04),
                            ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Layout cinematic del detalle de contenedor de luz:
/// tags → título → motivación → hero+caption → paleta → refuerzos → técnica.
class _StyleContainerDetailBody extends StatefulWidget {
  final int projectId;
  final int bibleId;
  final NarrativeCardModel card;
  final AppDatabase db;
  final AppPalette palette;
  final TextEditingController titleCtrl;
  final TextEditingController bodyCtrl;
  final TextEditingController captionCtrl;
  final bool techExpanded;
  final Widget? technicalPanel;
  final ValueChanged<bool> onTechExpandedChanged;
  final ValueChanged<NarrativeCardModel> onCardUpdated;
  final Future<void> Function(NarrativeCardModel card) onPersistMeta;
  final Future<void> Function(int imageId) onCoverSet;
  final Future<List<MoodboardImageModel>> Function() matchedImagesLoader;

  const _StyleContainerDetailBody({
    required this.projectId,
    required this.bibleId,
    required this.card,
    required this.db,
    required this.palette,
    required this.titleCtrl,
    required this.bodyCtrl,
    required this.captionCtrl,
    required this.techExpanded,
    required this.technicalPanel,
    required this.onTechExpandedChanged,
    required this.onCardUpdated,
    required this.onPersistMeta,
    required this.onCoverSet,
    required this.matchedImagesLoader,
  });

  @override
  State<_StyleContainerDetailBody> createState() =>
      _StyleContainerDetailBodyState();
}

class _StyleContainerDetailBodyState extends State<_StyleContainerDetailBody> {
  List<MoodboardImageModel>? _matched;
  String? _coverPath;
  List<String> _coverPaletteHex = const [];

  @override
  void initState() {
    super.initState();
    _refreshMatched();
    _loadCover();
  }

  @override
  void didUpdateWidget(_StyleContainerDetailBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.coverMoodboardImageId !=
            widget.card.coverMoodboardImageId ||
        oldWidget.card.id != widget.card.id) {
      _loadCover();
    }
    if (oldWidget.card.meta != widget.card.meta) {
      _refreshMatched();
    }
  }

  Future<void> _refreshMatched() async {
    final matched = await widget.matchedImagesLoader();
    if (!mounted) return;
    setState(() => _matched = matched);
  }

  Future<void> _loadCover() async {
    final coverId = widget.card.coverMoodboardImageId;
    if (coverId == null) {
      setState(() {
        _coverPath = null;
        _coverPaletteHex = const [];
      });
      return;
    }
    final row = await (widget.db.select(widget.db.moodboardImages)
          ..where((m) => m.id.equals(coverId)))
        .getSingleOrNull();
    final meta = await MoodboardReferenceMetaStore.load(widget.db, coverId);
    if (!mounted) return;
    setState(() {
      _coverPath = row?.imagePath;
      _coverPaletteHex = meta.paletteHex;
    });
  }

  Future<void> _handleCoverSet(int imageId) async {
    await widget.onCoverSet(imageId);
    final meta = await MoodboardReferenceMetaStore.load(widget.db, imageId);
    if (meta.technicalNotes?.trim().isNotEmpty == true &&
        widget.captionCtrl.text.trim().isEmpty) {
      widget.captionCtrl.text = meta.technicalNotes!.trim();
    }
    await _loadCover();
    await _refreshMatched();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final palette = widget.palette;
    final matched = _matched ?? const <MoodboardImageModel>[];

    Future<void> persistPalette(List<String> hex) async {
      final coverId = card.coverMoodboardImageId;
      if (coverId == null) return;
      final meta = await MoodboardReferenceMetaStore.load(widget.db, coverId);
      await MoodboardReferenceMetaStore.save(
        widget.db,
        coverId,
        meta.copyWith(paletteHex: hex),
      );
      if (mounted) setState(() => _coverPaletteHex = hex);
    }

    Widget hero() => ContainerHeroWithCaption(
          projectId: widget.projectId,
          bibleId: widget.bibleId,
          card: card,
          palette: palette,
          coverPath: _coverPath,
          matchedImages: matched,
          captionController: widget.captionCtrl,
          maxHeroHeight: 380,
          onCoverSet: _handleCoverSet,
          onPasteCover: (payload) async {
            final id = await MoodboardHelpers.addImageForNarrativeCard(
              db: widget.db,
              projectId: widget.projectId,
              bibleId: widget.bibleId,
              cardId: card.id,
              sectionId: card.sectionId,
              bytes: payload.bytes,
              extension: payload.extension,
              locationBasePlanId: card.locationBasePlanId,
              asCover: true,
            );
            await _handleCoverSet(id);
          },
          onMoodboardDropped: (MoodboardDragPayload drag) async {
            await MoodboardHelpers.linkMoodboardToSection(
              db: widget.db,
              projectId: widget.projectId,
              payload: drag,
              sectionId: card.sectionId,
              locationBasePlanId: card.locationBasePlanId,
              cardId: card.id,
            );
            final imageId = drag.moodboardImageId;
            if (imageId != null) {
              await _handleCoverSet(imageId);
            }
          },
          onChanged: () => setState(() {}),
        );

    Widget sideColumn() => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ContainerPalettePanel(
              imagePath: _coverPath,
              paletteHex: _coverPaletteHex,
              palette: palette,
              onPalettePersisted: persistPalette,
            ),
            const SizedBox(height: 16),
            ContainerMetricsPanel(
              card: card,
              palette: palette,
              onChanged: (updated) async {
                widget.onCardUpdated(updated);
                await widget.onPersistMeta(updated);
              },
            ),
            if (widget.technicalPanel != null) ...[
              const SizedBox(height: 16),
              ExpansionTile(
                initiallyExpanded: widget.techExpanded,
                onExpansionChanged: widget.onTechExpandedChanged,
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Text(
                  'Técnica de set',
                  style: AppTypography.bodyMedium(palette).copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: widget.technicalPanel!,
                  ),
                ],
              ),
            ],
          ],
        );

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ContainerHeaderTags(
          card: card,
          palette: palette,
          onChanged: (updated) async {
            widget.onCardUpdated(updated);
            await widget.onPersistMeta(updated);
            await _refreshMatched();
          },
        ),
        const SizedBox(height: 16),
        BibleTextField(
          label: 'Título',
          controller: widget.titleCtrl,
          onChanged: (_) {},
        ),
        const SizedBox(height: 16),
        BibleTextField(
          label: 'Motivación',
          controller: widget.bodyCtrl,
          maxLines: 5,
          italic: true,
          onChanged: (_) {},
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 65, child: hero()),
                  const SizedBox(width: 20),
                  Expanded(flex: 35, child: sideColumn()),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                hero(),
                const SizedBox(height: 20),
                sideColumn(),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        ContainerStillsGrid(
          projectId: widget.projectId,
          card: card,
          db: widget.db,
          palette: palette,
        ),
        const SizedBox(height: 24),
        ReinforcementBlocks(
          projectId: widget.projectId,
          bibleId: widget.bibleId,
          card: card,
          db: widget.db,
          palette: palette,
          onChanged: (blocks) async {
            final updated = card.copyWith(
              meta: Map<String, dynamic>.from(card.meta),
            );
            updated.reinforcementBlocks = blocks;
            widget.onCardUpdated(updated);
            await widget.onPersistMeta(updated);
          },
        ),
      ],
    );
  }
}
