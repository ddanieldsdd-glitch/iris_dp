import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../bible_block_catalog.dart';
import '../../v2/migration/legacy_to_document_migrator.dart';
import '../../v2/model/bible_block.dart';
import '../../v2/model/bible_block_layout.dart';
import '../../v2/model/bible_document.dart';
import '../../v2/model/bible_page.dart';
import '../../visual_bible_export_config.dart';
import '../../../../shared/visual_bible/bible_section_ids.dart';
import '../model/bible_export_composition.dart';

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
  ) {
    final sectionId = page.source?.sectionId;
    final extra = <BibleBlock>[];
    switch (sectionId) {
      case BibleSectionId.colorImage:
        if (bundle.blocks.isNotEmpty) {
          extra.add(
            BibleBlock(
              id: '${page.id}__palettes',
              type: BibleBlockKind.colorPalette,
              layout: BibleBlockLayout(row: page.blocks.length),
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
              layout: BibleBlockLayout(row: page.blocks.length),
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
              layout: BibleBlockLayout(row: page.blocks.length + extra.length),
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
      case BibleSectionId.cameraTests:
        if (bundle.cameraTests.isNotEmpty) {
          extra.add(
            BibleBlock(
              id: '${page.id}__camera_tests',
              type: BibleBlockKind.specsTable,
              layout: BibleBlockLayout(row: page.blocks.length),
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
          extra.add(
            BibleBlock(
              id: '${page.id}__moodboard',
              type: BibleBlockKind.moodboardRefs,
              layout: BibleBlockLayout(row: page.blocks.length),
              content: {
                'images': [
                  for (final image in bundle.moodboard)
                    {
                      'path': image.imagePath,
                      if (image.caption != null) 'caption': image.caption,
                    },
                ],
              },
            ),
          );
        }
    }
    final blocks = [...page.blocks, ...extra];
    return page.copyWith(
      blocks: blocks,
      metadata: {
        ...page.metadata,
        'sourceBlocks': blocks.map((block) => block.toJson()).toList(),
      },
    );
  }

  static String _sectionId(BiblePage page) => page.legacySectionId ?? page.id;
}
