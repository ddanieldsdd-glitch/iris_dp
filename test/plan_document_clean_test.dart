import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_painter.dart';
import 'package:iris_dp/features/camera_plan/plan_document_labels.dart';
import 'package:iris_dp/features/camera_plan/plan_renderer.dart';
import 'package:iris_dp/features/camera_plan/plan_segment.dart';
import 'package:iris_dp/features/camera_plan/plan_thumbnail.dart';
import 'package:iris_dp/features/export_center/export_options.dart';
import 'package:iris_dp/features/export_center/export_selection.dart';
import 'package:iris_dp/shared/pdf_export/shooting_plan_pdf.dart';

/// En la planta de rodaje los números de los recorridos, las flechas, los
/// nombres y las luces tapaban las cámaras y los actores. Ahora los nombres
/// van a los márgenes, los números se apartan de las figuras y las luces
/// tienen su propia planta.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('nombres al margen', () {
    const canvas = Size(420, 240);
    const drawing = Rect.fromLTRB(80, 0, 340, 240);

    DocumentLabel label(double x, double y, {bool optional = false}) =>
        DocumentLabel(
          anchors: [Offset(x, y)],
          size: const Size(70, 18),
          radius: 8,
          optional: optional,
        );

    test('ningún nombre obligatorio cae dentro del dibujo', () {
      // Ocho personajes y una cámara en un pasillo, como en el kebab.
      final labels = [
        for (var i = 0; i < 9; i++) label(150 + (i % 3) * 30, 30 + i * 22),
      ];
      final result = layoutDocumentLabels(
        labels,
        canvas,
        drawing: drawing,
        gap: 4,
      );
      expect(result.placed, hasLength(9));
      for (final p in result.placed) {
        expect(p.leader, isTrue);
        expect(p.rect.overlaps(drawing), isFalse, reason: '${p.rect}');
      }
      for (final (i, a) in result.placed.indexed) {
        for (final b in result.placed.skip(i + 1)) {
          expect(a.rect.overlaps(b.rect), isFalse);
        }
      }
    });

    test('la línea va por el lado que no cruza otra figura', () {
      // Una figura a la izquierda del ancla: el nombre sale por la derecha
      // aunque el ancla esté en la mitad izquierda.
      final anchor = label(190, 120);
      final blocker = Rect.fromCircle(
        center: const Offset(130, 120),
        radius: 10,
      );
      final result = layoutDocumentLabels(
        [anchor],
        canvas,
        drawing: drawing,
        gap: 4,
        marks: [blocker],
      );
      expect(result.placed.single.rect.left, greaterThanOrEqualTo(340));
    });

    test('lo opcional solo entra si cabe dentro del dibujo', () {
      final result = layoutDocumentLabels(
        [label(85, 120, optional: true), label(200, 120, optional: true)],
        canvas,
        drawing: drawing,
        gap: 4,
      );
      expect(result.placed, hasLength(1));
      expect(drawing.contains(result.placed.single.rect.center), isTrue);
    });
  });

  group('números de los recorridos', () {
    const bounds = Rect.fromLTWH(0, 0, 300, 240);
    const r = CameraPlanPainter.debugStopRadius;

    void expectClear(
      List<({Offset center, Offset anchor, int number})> stops,
      List<(Offset, double)> figures,
    ) {
      for (final s in stops) {
        for (final (at, radius) in figures) {
          expect(
            (s.center - at).distance,
            greaterThanOrEqualTo(radius + r),
            reason: 'parada ${s.number} en ${s.center} tapa la figura en $at',
          );
        }
      }
      for (final (i, a) in stops.indexed) {
        for (final b in stops.skip(i + 1)) {
          expect((a.center - b.center).distance, greaterThanOrEqualTo(r * 2));
        }
      }
    }

    test('ninguno tapa una figura ni otro número', () {
      // Lo de la captura: dos personajes que se cruzan en un pasillo con
      // una cámara que los sigue y figuración alrededor.
      final figures = <(Offset, double)>[
        (const Offset(150, 40), 9), // SIMO
        (const Offset(160, 205), 9), // ALI
        (const Offset(170, 190), 11), // cámara A
        (const Offset(130, 140), 9), // ARIEL
        (const Offset(110, 110), 9), // HASSAN
        (const Offset(195, 145), 7), // figuración
        (const Offset(195, 160), 7),
        (const Offset(95, 185), 7),
        (const Offset(110, 185), 7),
      ];
      final stops = CameraPlanPainter.debugLayoutStops(
        [
          (
            points: const [
              Offset(150, 40),
              Offset(100, 75),
              Offset(165, 125),
              Offset(185, 150),
            ],
            body: 9,
          ),
          (
            points: const [
              Offset(160, 205),
              Offset(168, 135),
              Offset(190, 110),
              Offset(120, 100),
            ],
            body: 9,
          ),
          (
            points: const [
              Offset(170, 190),
              Offset(150, 135),
              Offset(168, 120),
            ],
            body: 11,
          ),
        ],
        figures,
        bounds,
      );
      expect(stops, hasLength(11));
      expectClear(stops, figures);
    });

    test('cada número va junto a su figura, sin taparla', () {
      // En cada parada hay una figura: el número va a su lado, cerca.
      final stops = CameraPlanPainter.debugLayoutStops(
        [
          (points: const [Offset(50, 50), Offset(200, 150)], body: 9),
        ],
        [(const Offset(50, 50), 9), (const Offset(200, 150), 9)],
        bounds,
      );
      for (final s in stops) {
        final gap = (s.center - s.anchor).distance;
        expect(gap, greaterThanOrEqualTo(9 + r));
        expect(gap, lessThan(9 + r * 3));
      }
    });
  });

  group('plantas pintadas', () {
    PlanElement actor(int id, Offset at, String name, List<Offset> path) =>
        PlanElement(
          id: id,
          type: ElementType.actor,
          position: at,
          label: name,
          pathPoints: path,
          props: {'uid': 'A$id'},
        );
    final elements = [
      actor(1, const Offset(100, 40), 'SIMO', const [
        Offset(40, 120),
        Offset(110, 230),
      ]),
      actor(2, const Offset(120, 480), 'ALI', const [
        Offset(130, 320),
        Offset(170, 240),
      ]),
      PlanElement(
        id: 3,
        type: ElementType.camera,
        position: const Offset(130, 430),
        cameraLetter: 'A',
        pathPoints: const [Offset(120, 330)],
        props: {'uid': 'C3'},
      ),
      PlanElement(
        id: 4,
        type: ElementType.light,
        position: const Offset(20, 20),
        lightType: LightType.fresnelMedium,
        props: {'uid': 'L4', 'intensity': 75},
      )..customName = 'PavoTube 15X',
    ];

    test('la de cámara y actores deja márgenes para los nombres', () async {
      const size = Size(420, 241);
      final png = await PlanThumbnail.renderPng(
        elements: elements.where((e) => e.type != ElementType.light).toList(),
        size: size,
        documentMarks: true,
        documentGutter: PlanRenderer.documentGutterFor(size),
      );
      expect(png, isNotNull);
    });

    test('la de luz se pinta con cámaras y actores atenuados', () async {
      final png = await PlanThumbnail.renderPng(
        elements: elements,
        size: const Size(624, 230),
        documentMarks: true,
        documentLightNumbers: true,
        documentLightOnly: true,
      );
      expect(png, isNotNull);
    });
  });

  group('encuadre de la planta de cámara', () {
    PlanElement wall(int id, Offset a, Offset b) =>
        PlanSegment.create(start: a, end: b);
    final camera = PlanElement(
      id: 1,
      type: ElementType.camera,
      position: const Offset(500, 500),
      cameraLetter: 'A',
      pathPoints: const [Offset(560, 520)],
      props: {'uid': 'C1'},
    );

    test('entra la sala que rodea la acción', () {
      final view = PlanThumbnail.stageView(
        all: [
          camera,
          wall(2, const Offset(300, 380), const Offset(800, 380)),
          wall(3, const Offset(300, 380), const Offset(300, 760)),
        ],
      )!;
      expect(view.top, lessThanOrEqualTo(380));
      expect(view.left, lessThanOrEqualTo(300));
    });

    test('una calle larga no aleja la acción', () {
      final view = PlanThumbnail.stageView(
        all: [
          camera,
          wall(2, const Offset(-5000, 440), const Offset(5000, 440)),
        ],
      )!;
      expect(view.width, lessThan(1000));
    });

    test('la sección elegida en el editor entra entera', () {
      const section = Rect.fromLTRB(100, 100, 900, 900);
      final view = PlanThumbnail.stageView(all: [camera], crop: section)!;
      expect(view.contains(section.topLeft), isTrue);
      expect(view.contains(section.bottomRight - const Offset(1, 1)), isTrue);
    });
  });

  group('selector de plantas', () {
    test('por defecto salen las dos', () {
      expect(const ExportOptions().planView, PlanExportView.both);
      expect(ExportOptions.fromJson(const {}).planView, PlanExportView.both);
    });

    test('«Con luz» apagado de antes es la planta de cámara', () {
      expect(
        ExportOptions.fromJson(const {'planWithLight': false}).planView,
        PlanExportView.stage,
      );
    });

    test('se recuerda lo elegido', () {
      final options = const ExportOptions().copyWith(
        planView: PlanExportView.light,
      );
      expect(
        ExportOptions.fromJson(options.toJson()).planView,
        PlanExportView.light,
      );
    });

    test('un plano a página entera va solo en la suya', () async {
      final plan = Uint8List.fromList(
        img.encodeJpg(
          img.Image(width: 30, height: 24)..clear(img.ColorRgb8(0, 0, 0)),
        ),
      );
      ShootingPlanBlock block(int n, {bool full = true}) => ShootingPlanBlock(
        sceneLabel: '6',
        shotNumber: n,
        slug: 'INT KEBAB NOCHE',
        plan: plan,
        fullPage: full,
        lightPlan: full ? plan : null,
        lightLegend: const [ShootingPlanLegendLine(1, 'PavoTube 15X')],
      );
      final a = block(1);
      final b = block(2, full: false);
      final c = block(3, full: false);
      final d = block(4);
      final days = [
        ShootingPlanDay('Orden', [
          ShootingPlanEntry('ESCENA 6', [a, b, c, d]),
        ]),
      ];
      final layout = ShootingPlanLayout.of(days, overviews: false);
      expect(layout.pages, [
        [a],
        [b, c],
        [d],
      ]);
      final bytes = await ShootingPlanPdf.compose(
        projectName: 'Prueba',
        days: days,
        view: PlanExportView.both,
      );
      expect(bytes, isNotEmpty);

      // Sin índice la portada va sola; el plan de rodaje va tras ella.
      final bare = ShootingPlanLayout.of(
        days,
        overviews: false,
        index: false,
        schedulePages: 2,
      );
      expect(bare.indexPages, 1);
      expect(bare.schedulePage, 2);
      expect(bare.entryPages.values.single, 4);
    });
  });

  group('lo que abre el documento', () {
    test('por defecto: índice, tiempo y portada solo en el guion', () {
      const options = ExportOptions();
      expect(options.planIndex, isTrue);
      expect(options.withWeather, isTrue);
      expect(options.withSchedule, isFalse);
      expect(
        options.copyWith(document: ExportDocument.technicalScript).withSchedule,
        isTrue,
      );
    });

    test('se recuerda por documento', () {
      final options = const ExportOptions(
        document: ExportDocument.shootingPlan,
      ).withScheduleSet(true).copyWith(planIndex: false, withWeather: false);
      final back = ExportOptions.fromJson(options.toJson());
      expect(back.withSchedule, isTrue);
      expect(back.planIndex, isFalse);
      expect(back.withWeather, isFalse);
      expect(
        back.copyWith(document: ExportDocument.storyboard).withSchedule,
        isFalse,
      );
    });
  });
}
