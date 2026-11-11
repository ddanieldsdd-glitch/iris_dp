import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iris_dp/core/theme/app_colors.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_painter.dart';
import 'package:iris_dp/features/camera_plan/plan_category.dart';
import 'package:iris_dp/features/camera_plan/plan_outliner.dart';

List<PlanElement> _plan() => [
  PlanElement(
    id: 1,
    type: ElementType.light,
    position: const Offset(100, 100),
    lightType: LightType.lightPanel,
    props: {'name': 'ARRI SkyPanel S60'},
  )..customName = 'Principal',
  PlanElement(
    id: 2,
    type: ElementType.prop,
    position: const Offset(200, 200),
    label: PropType.sofa.dbValue,
    props: {'unrealAsset': '/Game/Fab/Sofa.Sofa'},
  ),
  PlanElement(
    id: 3,
    type: ElementType.prop,
    position: const Offset(300, 200),
    label: PropType.table.dbValue,
  ),
  PlanElement(id: 4, type: ElementType.camera, position: const Offset(0, 0)),
  PlanElement(
    id: 5,
    type: ElementType.actor,
    position: const Offset(50, 50),
    label: 'ADIL',
  ),
];

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('la lista agrupa por categoría y ordena por nombre', () {
    final groups = PlanOutliner.group(_plan(), '');
    expect([for (final (c, _) in groups) c], [
      PlanCategory.camera,
      PlanCategory.light,
      PlanCategory.furniture,
      PlanCategory.people,
    ]);
    final furniture = groups.firstWhere((g) => g.$1 == PlanCategory.furniture);
    expect([for (final el in furniture.$2) el.displayLabel], ['Mesa', 'Sofá']);
  });

  test('busca por nombre, modelo, tipo, categoría y «ue»', () {
    final els = _plan();
    String found(String q) => [
      for (final (_, list) in PlanOutliner.group(els, q))
        for (final el in list) el.displayLabel,
    ].join(',');
    expect(found('principal'), 'Principal');
    expect(found('skypanel'), 'Principal');
    expect(found('sofá'), 'Sofá');
    expect(found('mobiliario'), 'Mesa,Sofá');
    expect(found('ue'), 'Sofá');
    expect(found('fab'), 'Sofá');
    expect(found('nada así'), '');
  });

  test('cuenta los assets por origen: Fab, Megascans, Unreal', () {
    PlanElement prop(String path) => PlanElement(
      id: 0,
      type: ElementType.prop,
      position: Offset.zero,
      label: PropType.rock.dbValue,
      props: {'unrealAsset': path},
    );
    final els = [
      ..._plan(),
      prop('/Game/Megascans/3D_Assets/Rock/S_Rock.S_Rock'),
      prop('/Game/Quixel/Rock2.Rock2'),
      prop('/Game/Props/Barril.Barril'),
    ];
    expect(
      PlanOutliner.assetSummary(els),
      '1 de Fab · 2 de Megascans · 1 de Proyecto',
    );
    expect(PlanOutliner.assetSummary(_plan().take(1)), '');
    String found(String q) => [
      for (final (_, list) in PlanOutliner.group(els, q))
        for (final el in list) el.displayLabel,
    ].join(',');
    expect(found('megascans').split(','), hasLength(2));
  });

  test('distintivo «UE» solo con asset de Unreal', () {
    final els = _plan();
    expect([for (final el in els) PlanCategory.hasUnrealAsset(el)], [
      false,
      true,
      false,
      false,
      false,
    ]);
  });

  testWidgets('la planta pinta colores, nombres, «UE» y leyenda sin fallar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: CustomPaint(
          size: const Size(800, 600),
          painter: CameraPlanPainter(
            elements: _plan(),
            palette: AppPalette.dark,
            colorByType: true,
            showNames: true,
            gearLabels: true,
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('la lista enseña nombres, «UE» y oculta con el ojo', (
    tester,
  ) async {
    final els = _plan();
    final hidden = <PlanElement>{};
    PlanElement? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (_, refresh) => PlanOutliner(
              elements: els,
              selected: null,
              hidden: hidden,
              onSelect: (el) => picked = el,
              onToggleHidden: (el) => refresh(() {
                if (!hidden.remove(el)) hidden.add(el);
              }),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Elementos · 5'), findsOneWidget);
    expect(find.text('Principal'), findsOneWidget);
    // El sofá es de Fab (ED.4).
    expect(find.text('Fab'), findsOneWidget);
    expect(find.text('Assets: 1 de Fab'), findsOneWidget);
    await tester.tap(find.text('Sofá'));
    expect(picked?.propType, PropType.sofa);
    await tester.tap(find.byTooltip(RegExp('^Ocultar')).first);
    await tester.pump();
    expect(hidden, hasLength(1));
  });
}
