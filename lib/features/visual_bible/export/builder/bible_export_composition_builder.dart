import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../bible_block_catalog.dart';
import '../../v2/migration/legacy_to_document_migrator.dart';
import '../../v2/model/bible_block.dart';
import '../../v2/model/bible_block_layout.dart';
import '../../v2/model/bible_document.dart';
import '../../v2/model/bible_page.dart';
import '../../moodboard_export_grouper.dart';
import '../../moodboard_export_layout.dart';
import '../../visual_bible_model.dart';
import '../../visual_bible_export_config.dart';
import '../../../../shared/visual_bible/bible_section_ids.dart';
import '../../../../shared/visual_bible/narrative_card_kind.dart';
import '../model/bible_export_composition.dart';
import '../bible_section_export_reader.dart';

typedef BibleExportIdFactory = String Function();
typedef BibleExportClock = DateTime Function();

class BibleExportCompositionBuilder {
  BibleExportCompositionBuilder({
    BibleExportIdFactory? idFactory,
    BibleExportClock? clock,
  }) : _idFactory = idFactory ?? const Uuid().v4,
       _clock = clock ?? _utcNow;

  final BibleExportIdFactory _idFactory;
  final BibleExportClock _clock;

  static DateTime _utcNow() => DateTime.now().toUtc();

  /// Crea una copia editable de las páginas seleccionadas. [sourceDocument]
  /// tiene prioridad; el fallback legacy se construye únicamente en memoria.
  BibleExportComposition build({
    required int projectId,
    required VisualBibleExportConfig config,
    required BibleExportSourceBundle bundle,
    BibleDocument? sourceDocument,
    String? compositionId,
    bool includeCover = true,
    BibleExportPageFormat format = BibleExportPageFormat.a4Portrait,
    BibleExportPageMargins margins = const BibleExportPageMargins(),
  }) {
    if (sourceDocument != null && sourceDocument.projectId != projectId) {
      throw ArgumentError.value(
        sourceDocument.projectId,
        'sourceDocument.projectId',
        'Must match projectId $projectId',
      );
    }

    final id = compositionId ?? _idFactory();
    final now = _clock().toUtc();
    final document =
        sourceDocument ??
        _legacyDocument(
          projectId: projectId,
          bibleId: bundle.data.id,
          config: config,
          bundle: bundle,
        );
    final pages = <BibleExportPage>[];

    if (includeCover) {
      pages.add(
        BibleExportPage(
          id: '${id}__cover',
          label: config.name,
          type: BibleExportPageType.cover,
          sortOrder: 0,
          format: format,
          margins: margins,
          blocks: [
            BibleBlock(
              id: '${id}__cover_title',
              type: BibleBlockKind.text,
              content: {
                'text': config.name,
                'subtitle': config.summaryLabel,
                if (config.recipients.trim().isNotEmpty)
                  'recipients': config.recipients.trim(),
              },
            ),
          ],
        ),
      );
    }

    final selectedPages =
        document.pages
            .where(
              (page) =>
                  !page.isHidden && config.sections.contains(_sectionId(page)),
            )
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    for (final sourcePage in selectedPages) {
      pages.add(
        _enrichPage(
          _pageFromSource(
            compositionId: id,
            sourcePage: sourcePage,
            document: document,
            sortOrder: pages.length,
            format: format,
            margins: margins,
          ),
          bundle,
          config,
        ),
      );
    }

    return BibleExportComposition(
      id: id,
      projectId: projectId,
      bibleId: document.bibleId,
      config: config,
      pages: pages,
      createdAt: now,
      updatedAt: now,
      metadata: {
        'source': sourceDocument == null
            ? 'legacy_migration'
            : 'bible_document_v2',
        'bundleCounts': {
          'colorBlocks': bundle.blocks.length,
          'exposureBlocks': bundle.exposureBlocks.length,
          'lightingSetups': bundle.lightingSetups.length,
          'cameraTests': bundle.cameraTests.length,
          'moodboard': bundle.moodboard.length,
        },
      },
    );
  }

  /// Restaura solo una página desde la Biblia actual y conserva su posición,
  /// formato y márgenes dentro del montaje.
  BibleExportComposition restorePage({
    required BibleExportComposition composition,
    required String pageId,
    required BibleExportSourceBundle bundle,
    BibleDocument? sourceDocument,
  }) {
    final current = composition.pageById(pageId);
    if (current == null) {
      throw ArgumentError.value(pageId, 'pageId', 'Page not found');
    }
    final reference = current.source;
    if (reference == null) {
      throw ArgumentError.value(pageId, 'pageId', 'Page has no Bible source');
    }

    final document =
        sourceDocument ??
        _legacyDocument(
          projectId: composition.projectId,
          bibleId: composition.bibleId ?? bundle.data.id,
          config: composition.config,
          bundle: bundle,
        );
    final sourcePage = document.pageById(reference.pageId);
    if (sourcePage == null) {
      throw StateError('Source page ${reference.pageId} no longer exists');
    }

    final restored = _pageFromSource(
      compositionId: composition.id,
      sourcePage: sourcePage,
      document: document,
      sortOrder: current.sortOrder,
      format: current.format,
      margins: current.margins,
    ).copyWith(id: current.id);
    final pages = composition.pages
        .map((page) => page.id == current.id ? restored : page)
        .toList();
    return composition.copyWith(pages: pages, updatedAt: _clock().toUtc());
  }

  BibleDocument _legacyDocument({
    required int projectId,
    required int bibleId,
    required VisualBibleExportConfig config,
    required BibleExportSourceBundle bundle,
  }) {
    final orderedIds = [
      ...BibleSectionId.all.where(config.sections.contains),
      ...(config.sections
          .where((id) => !BibleSectionId.all.contains(id))
          .toList()
        ..sort()),
    ];
    return LegacyToDocumentMigrator.migrate(
      projectId: projectId,
      bibleId: bibleId,
      groups: const [
        LegacyBibleGroupSnapshot(id: 'export', label: 'Exportación'),
      ],
      sections: [
        for (var index = 0; index < orderedIds.length; index++)
          LegacyBibleSectionSnapshot(
            id: orderedIds[index],
            groupId: 'export',
            label: BibleSectionId.label(orderedIds[index]),
            sortOrder: index,
            contentJson: bundle.sectionContentJsonById[orderedIds[index]],
          ),
      ],
      data: bundle.data,
    );
  }

  BibleExportPage _pageFromSource({
    required String compositionId,
    required BiblePage sourcePage,
    required BibleDocument document,
    required int sortOrder,
    required BibleExportPageFormat format,
    required BibleExportPageMargins margins,
  }) {
    return BibleExportPage(
      id: '${compositionId}__${sourcePage.id}',
      label: sourcePage.label,
      type: BibleExportPageType.generated,
      sortOrder: sortOrder,
      format: format,
      margins: margins,
      source: BibleExportSourceReference(
        bibleId: document.bibleId,
        pageId: sourcePage.id,
        sectionId: _sectionId(sourcePage),
        documentSchemaVersion: document.schemaVersion,
        documentUpdatedAt: document.updatedAt,
      ),
      blocks: sourcePage.blocks
          .map(
            (block) => BibleBlock.fromJson(
              Map<String, dynamic>.from(
                jsonDecode(jsonEncode(block.toJson())) as Map,
              ),
            ),
          )
          .toList(),
      metadata: {
        'sourceBlocks': sourcePage.blocks
            .map((block) => block.toJson())
            .toList(),
      },
    );
  }

  BibleExportPage _enrichPage(
    BibleExportPage page,
    BibleExportSourceBundle bundle,
    VisualBibleExportConfig config,
  ) {
    final sectionId = page.source?.sectionId;
    final blocks = List<BibleBlock>.from(page.blocks);
    final extra = <BibleBlock>[];
    switch (sectionId) {
      case BibleSectionId.colorImage:
        if (bundle.blocks.isNotEmpty) {
          extra.add(
            BibleBlock(
              id: '${page.id}__palettes',
              type: BibleBlockKind.colorPalette,
              layout: BibleBlockLayout(row: blocks.length),
              content: {
                'colors': [
                  for (final block in bundle.blocks)
                    for (final color in block.dominantColors)
                      {'name': block.blockName, 'hex': color},
                ],
              },
            ),
          );
        }
      case BibleSectionId.exposure:
        if (bundle.exposureBlocks.isNotEmpty) {
          extra.add(
            BibleBlock(
              id: '${page.id}__exposure',
              type: BibleBlockKind.specsTable,
              layout: BibleBlockLayout(row: blocks.length),
              content: {
                'columns': ['block', 'highlights', 'shadows', 'ratio'],
                'rows': [
                  for (final block in bundle.exposureBlocks)
                    {
                      'block': block.blockName,
                      'highlights': block.highlightStrategy ?? '—',
                      'shadows': block.shadowStrategy ?? '—',
                      'ratio': block.keyFillRatio ?? '—',
                    },
                ],
              },
            ),
          );
        }
      case BibleSectionId.lighting:
        final lightingCards = bundle.narrativeCards
            .where((c) => c.sectionId == BibleSectionId.lighting)
            .toList()
          ..sort((a, b) {
            int rank(String kind) => switch (kind) {
                  NarrativeCardKind.overview => 0,
                  NarrativeCardKind.style => 1,
                  NarrativeCardKind.filmRef => 2,
                  NarrativeCardKind.locationLight => 3,
                  _ => 9,
                };
            final rk = rank(a.kind).compareTo(rank(b.kind));
            if (rk != 0) return rk;
            return a.sortOrder.compareTo(b.sortOrder);
          });
        for (final card in lightingCards) {
          final body = StringBuffer();
          if (card.kind == NarrativeCardKind.filmRef) {
            final bits = [
              if (card.filmTitle?.isNotEmpty == true) card.filmTitle,
              if (card.filmDp?.isNotEmpty == true) 'DP ${card.filmDp}',
              if (card.filmYear?.isNotEmpty == true) card.filmYear,
            ].whereType<String>();
            if (bits.isNotEmpty) body.writeln(bits.join(' · '));
          }
          if (card.summary?.isNotEmpty == true) {
            body.writeln(card.summary);
          }
          if (card.body?.isNotEmpty == true) body.writeln(card.body);
          final text = body.toString().trim();
          if (text.isEmpty && card.title.trim().isEmpty) continue;
          extra.add(
            BibleBlock(
              id: '${page.id}__narr_${card.id}',
              type: BibleBlockKind.text,
              layout: BibleBlockLayout(row: blocks.length + extra.length),
              content: {
                'label':
                    '${NarrativeCardKind.label(card.kind)} · ${card.title}',
                'text': text.isEmpty ? card.title : text,
              },
            ),
          );
        }
        for (final setup in bundle.lightingSetups) {
          List<dynamic> nodes;
          try {
            nodes = jsonDecode(setup.diagramJson) as List<dynamic>;
          } catch (_) {
            nodes = const [];
          }
          extra.add(
            BibleBlock(
              id: '${page.id}__lighting_${setup.id}',
              type: BibleBlockKind.lightingDiagram,
              layout: BibleBlockLayout(row: blocks.length + extra.length),
              content: {
                'label': setup.setupName,
                'text': setup.narrativeNote ?? '',
                'nodes': nodes,
                'setupId': setup.id,
                if (setup.referenceImagePath != null)
                  'imagePath': setup.referenceImagePath,
              },
            ),
          );
        }
      case BibleSectionId.location:
        extra.addAll(_locationBlocks(page, blocks.length + extra.length, bundle));
      case BibleSectionId.cameraTests:
        if (bundle.cameraTests.isNotEmpty) {
          extra.add(
            BibleBlock(
              id: '${page.id}__camera_tests',
              type: BibleBlockKind.specsTable,
              layout: BibleBlockLayout(row: blocks.length),
              content: {
                'columns': ['test', 'lut', 'light', 'notes'],
                'rows': [
                  for (final test in bundle.cameraTests)
                    {
                      'test': test.testName,
                      'lut': test.lutName ?? '—',
                      'light': test.lightCondition ?? '—',
                      'notes': test.notes ?? '—',
                    },
                ],
              },
            ),
          );
        }
      case BibleSectionId.moodboard:
        if (bundle.moodboard.isNotEmpty) {
          final layout = config.resolvedMoodboardLayout;
          final groups = MoodboardExportGrouper.group(bundle.moodboard, layout);
          final blockSpecs =
              <({String? title, List<MoodboardImageModel> images})>[];

          if (layout.grouping == MoodboardExportGrouping.flat) {
            blockSpecs.add((title: null, images: groups.flat));
          } else {
            for (final facet in MoodboardExportGrouper.facetOrder) {
              final facetImages = groups.byFacet[facet];
              if (facetImages == null || facetImages.isEmpty) continue;
              blockSpecs.add((
                title: MoodboardExportLayout.facetLabel(facet),
                images: facetImages,
              ));
            }
            if (layout.includeUnclassified && groups.unclassified.isNotEmpty) {
              blockSpecs.add((
                title: 'Sin clasificar',
                images: groups.unclassified,
              ));
            }
          }

          final emptyIdx = blocks.indexWhere(
            (b) =>
                b.type == BibleBlockKind.moodboardRefs &&
                _moodboardRefsImagesEmpty(b),
          );
          final anyIdx = blocks.indexWhere(
            (b) => b.type == BibleBlockKind.moodboardRefs,
          );

          var specIndex = 0;
          if (emptyIdx >= 0 && specIndex < blockSpecs.length) {
            blocks[emptyIdx] = blocks[emptyIdx].copyWith(
              content: _moodboardRefsContent(
                blockSpecs[specIndex].images,
                layout,
                title: blockSpecs[specIndex].title,
              ),
            );
            specIndex++;
          } else if (anyIdx >= 0 && specIndex < blockSpecs.length) {
            // Un bloque con algunas stills no debe recortar el resto del moodboard.
            blocks[anyIdx] = blocks[anyIdx].copyWith(
              content: _moodboardRefsContent(
                blockSpecs[specIndex].images,
                layout,
                title: blockSpecs[specIndex].title ??
                    blocks[anyIdx].content['title']?.toString(),
              ),
            );
            specIndex++;
          } else if (anyIdx < 0 && specIndex < blockSpecs.length) {
            extra.add(
              BibleBlock(
                id: '${page.id}__moodboard',
                type: BibleBlockKind.moodboardRefs,
                layout: BibleBlockLayout(row: blocks.length),
                content: _moodboardRefsContent(
                  blockSpecs[specIndex].images,
                  layout,
                  title: blockSpecs[specIndex].title,
                ),
              ),
            );
            specIndex++;
          }

          for (; specIndex < blockSpecs.length; specIndex++) {
            final spec = blockSpecs[specIndex];
            extra.add(
              BibleBlock(
                id: '${page.id}__moodboard_$specIndex',
                type: BibleBlockKind.moodboardRefs,
                layout: BibleBlockLayout(row: blocks.length + extra.length),
                content: _moodboardRefsContent(
                  spec.images,
                  layout,
                  title: spec.title,
                ),
              ),
            );
          }
        }
      case BibleSectionId.optics:
        final hasNarrativeBlock = blocks.any(
          (b) => b.type == BibleBlockKind.narrative,
        );
        final opticsRows = BibleSectionExportReader.rowsFromOpticsConfigJson(
          bundle.data.opticsConfigJson,
          // La cita narrative del template ya muestra la intención; no repetir
          // como primera fila de la tabla de specs.
          narrativeIntent: hasNarrativeBlock
              ? null
              : bundle.data.opticsNarrativeIntent,
          lensPhilosophy: bundle.data.lensPhilosophy,
        );
        if (opticsRows.isNotEmpty) {
          extra.add(
            BibleBlock(
              id: '${page.id}__optics',
              type: BibleBlockKind.specsTable,
              layout: BibleBlockLayout(row: blocks.length + extra.length),
              content: {
                'columns': ['campo', 'valor'],
                'rows': [
                  for (final row in opticsRows)
                    {'campo': row.label, 'valor': row.value},
                ],
              },
            ),
          );
        }
    }
    if (sectionId != null && sectionId != BibleSectionId.moodboard) {
      final stills = MoodboardExportGrouper.imagesForSection(
        bundle.moodboard,
        sectionId,
      );
      if (stills.isNotEmpty) {
        final emptyIdx = blocks.indexWhere(
          (b) =>
              b.type == BibleBlockKind.moodboardRefs &&
              _moodboardRefsImagesEmpty(b),
        );
        final content = _moodboardRefsContent(
          stills,
          config.resolvedMoodboardLayout,
          title: 'Referencias',
        );
        if (emptyIdx >= 0) {
          blocks[emptyIdx] = blocks[emptyIdx].copyWith(content: content);
        } else {
          extra.add(
            BibleBlock(
              id: '${page.id}__section_refs',
              type: BibleBlockKind.moodboardRefs,
              layout: BibleBlockLayout(row: blocks.length + extra.length),
              content: content,
            ),
          );
        }
      }
    }
    if (sectionId != null) {
      final customRows = BibleSectionExportReader.rowsForSection(
        sectionId,
        BibleSectionExportReader.parseCustomBlob(
          bundle.sectionContentJsonById[sectionId],
          sectionId,
        ),
      );
      if (customRows.isNotEmpty) {
        extra.add(
          BibleBlock(
            id: '${page.id}__custom_fields',
            type: BibleBlockKind.specsTable,
            layout: BibleBlockLayout(row: blocks.length + extra.length),
            content: {
              'columns': ['campo', 'valor'],
              'rows': [
                for (final row in customRows)
                  {'campo': row.label, 'valor': row.value},
              ],
            },
          ),
        );
      }
    }
    final merged = [...blocks, ...extra];
    return page.copyWith(
      blocks: merged,
      metadata: {
        ...page.metadata,
        'sourceBlocks': merged.map((block) => block.toJson()).toList(),
      },
    );
  }

  static List<BibleBlock> _locationBlocks(
    BibleExportPage page,
    int startRow,
    BibleExportSourceBundle bundle,
  ) {
    final extra = <BibleBlock>[];
    final images = _locationMoodboardImages(bundle.moodboard);
    final setNames = <String>{
      for (final image in images)
        if (image.linkedLocationName?.trim().isNotEmpty == true)
          image.linkedLocationName!.trim(),
    };
    if (setNames.isNotEmpty) {
      extra.add(
        BibleBlock(
          id: '${page.id}__location_sets',
          type: BibleBlockKind.chipSelect,
          layout: BibleBlockLayout(row: startRow + extra.length),
          content: {
            'chips': setNames.toList(),
            'selected': setNames.toList(),
          },
        ),
      );
    }
    if (images.isNotEmpty) {
      extra.add(
        BibleBlock(
          id: '${page.id}__location_hero',
          type: BibleBlockKind.heroImage,
          layout: BibleBlockLayout(row: startRow + extra.length, colSpan: 8),
          content: {'image': {'path': images.first.imagePath}},
        ),
      );
      extra.add(
        BibleBlock(
          id: '${page.id}__location_refs',
          type: BibleBlockKind.moodboardRefs,
          layout: BibleBlockLayout(row: startRow + extra.length),
          content: _moodboardRefsContent(
            images,
            MoodboardExportLayout.defaults,
            title: 'Referencias de localización',
          ),
        ),
      );
    }
    final solar = _locationSolarMetrics(
      BibleSectionExportReader.parseCustomBlob(
        bundle.sectionContentJsonById[BibleSectionId.location],
        BibleSectionId.location,
      ),
    );
    if (solar.isNotEmpty) {
      extra.add(
        BibleBlock(
          id: '${page.id}__location_solar',
          type: BibleBlockKind.telemetry,
          layout: BibleBlockLayout(row: startRow + extra.length, colSpan: 4),
          content: {'metrics': solar},
        ),
      );
    }
    return extra;
  }

  static List<MoodboardImageModel> _locationMoodboardImages(
    List<MoodboardImageModel> moodboard,
  ) {
    return [
      for (final image in moodboard)
        if (image.assignedSections.contains(BibleSectionId.location) ||
            image.category == MoodboardCategory.location ||
            (image.linkedLocationName?.trim().isNotEmpty ?? false) ||
            image.linkedLocationBasePlanId != null)
          image,
    ];
  }

  static List<Map<String, String>> _locationSolarMetrics(
    Map<String, dynamic> blob,
  ) {
    const keys = [
      ('azimuth', 'Azimut'),
      ('sunrise', 'Amanecer'),
      ('sunset', 'Atardecer'),
      ('goldenHour', 'Golden hour'),
      ('daylightWindow', 'Ventana'),
    ];
    return [
      for (final (key, label) in keys)
        if ((blob[key]?.toString().trim().isNotEmpty ?? false))
          {'label': label, 'value': blob[key].toString().trim()},
    ];
  }

  static Map<String, dynamic> _moodboardRefsContent(
    List<MoodboardImageModel> images,
    MoodboardExportLayout layout, {
    String? title,
  }) => {
    if (title != null) 'title': title,
    'images': images.map((image) => _moodboardImageJson(image, layout)).toList(),
  };

  static Map<String, dynamic> _moodboardImageJson(
    MoodboardImageModel image,
    MoodboardExportLayout layout,
  ) {
    final caption = MoodboardExportGrouper.captionFor(image, layout.density);
    final details = MoodboardExportGrouper.detailLinesFor(image, layout.density);
    return {
      'path': image.imagePath,
      if (caption != null) 'caption': caption,
      if (details.isNotEmpty) 'details': details,
    };
  }

  static bool _moodboardRefsImagesEmpty(BibleBlock block) {
    final images = block.content['images'] ?? block.content['items'];
    if (images is! List) return true;
    return images.isEmpty;
  }

  static String _sectionId(BiblePage page) => page.legacySectionId ?? page.id;
}
