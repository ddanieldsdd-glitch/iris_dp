import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/visual_bible/widgets/bible_card_editor.dart';
import 'package:iris_dp/shared/visual_bible/bible_cards.dart';
import 'package:iris_dp/features/visual_bible/widgets/bible_image_sheet.dart';
import 'package:iris_dp/features/visual_bible/widgets/catalog/bible_widget_catalog.dart';

void main() {
  test('las imágenes de un bloque se guardan en ese bloque', () {
    const card = BibleCard(
      title: 'Niebla',
      imageIds: [1],
      points: [
        BibleCard(title: 'Luz rota', imageIds: [2, 3]),
        BibleCard(title: 'Luz dura', imageIds: [3, 4]),
      ],
    );
    final back = BibleCard.fromJson(card.toJson());
    expect(back.points.first.imageIds, [2, 3]);
    expect(back.points.last.imageIds, [3, 4]);
    expect(back.imageIds, [1]);
    expect(back.allImageIds, [1, 2, 3, 4]);
  });

  testWidgets('cada bloque de texto elige sus propias imágenes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final tmp = Directory.systemTemp.createTempSync('iris_bloque');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final path = '${tmp.path}/a.png';
    File(path).writeAsBytesSync(img.encodePng(img.Image(width: 16, height: 9)));

    BibleCard? saved;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: BibleCardEditor(
            copy: BibleCardEditorCopy.mosaic,
            initial: const BibleCard(
              title: 'Niebla',
              points: [BibleCard(title: 'Luz rota')],
            ),
            imagePaths: {7: path},
            onChanged: (card) => saved = card,
            onMove: (_, _) {},
            onDelete: () {},
            onPickImages: (selected) async => [...selected, 7],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Imágenes de este punto'));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(saved!.points.single.imageIds, [7]);
    expect(saved!.imageIds, isEmpty);
    expect(find.byTooltip('Quitar de este bloque'), findsOneWidget);

    await tester.tap(find.byTooltip('Quitar de este bloque'));
    await tester.pumpAndSettle();
    expect(saved!.points.single.imageIds, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('en el mosaico cada punto es un tema con su texto y su grupo '
      'de imágenes, a todo el ancho', (tester) async {
    tester.view.physicalSize = const Size(1300, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final tmp = Directory.systemTemp.createTempSync('iris_tema');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final paths = <int, String>{};
    for (final id in [7, 8, 9]) {
      paths[id] = '${tmp.path}/$id.png';
      File(
        paths[id]!,
      ).writeAsBytesSync(img.encodePng(img.Image(width: 32, height: 18)));
    }

    BibleCard? saved;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: BibleCardEditor(
            copy: BibleCardEditorCopy.mosaic,
            initial: const BibleCard(
              title: 'Cálidos y contraste alto',
              imageIds: [7],
              points: [
                BibleCard(title: 'Los cálidos', imageIds: [8, 9]),
                BibleCard(title: 'El contraste alto'),
              ],
            ),
            imagePaths: paths,
            onChanged: (card) => saved = card,
            onMove: (_, _) {},
            onDelete: () {},
            onPickImages: (selected) async => [...selected, 7],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('PUNTOS QUE ANALIZAMOS'), findsOneWidget);
    expect(find.text('LÁMINAS · 1'), findsNothing);
    // El primer tema con sus dos imágenes, grandes.
    final thumbs = find.byType(MoodboardImageThumb);
    expect(thumbs, findsNWidgets(2));
    expect(tester.getSize(thumbs.first).width, 240);

    await tester.tap(find.text('Imágenes de este punto'));
    await tester.pumpAndSettle();
    expect(saved!.points.last.imageIds, [7]);
    expect(saved!.points.first.imageIds, [8, 9]);
    expect(tester.takeException(), isNull);
  });

  test('análisis de una imagen: la imagen y su nota viajan juntas', () {
    final raw = BibleImageAnalysisPoint.encode(
      12,
      const BibleImageNote(title: 'Medio rostro', text: 'El sodio quema'),
    );
    final (id, note) = BibleImageAnalysisPoint.decode(raw);
    expect(id, 12);
    expect(note.title, 'Medio rostro');
    expect(
      BibleWidgetCatalog.byId('image_analysis')?.label,
      'Análisis de una imagen',
    );
  });
}
