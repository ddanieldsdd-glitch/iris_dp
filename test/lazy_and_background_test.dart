import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:iris_dp/core/sync/media_optimizer.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/light/light_scene.dart';
import 'package:iris_dp/features/camera_plan/plan_light_map.dart';
import 'package:iris_dp/features/visual_bible/widgets/moodboard_stitch_shell.dart';

import 'plan_light_perf_test.dart' show syntheticPlan;

void main() {
  group('mapa de luz en otro hilo', () {
    const mpu = 0.02;
    const rect = Rect.fromLTWH(0, 0, 3000, 3000);
    LightScene scene() => LightScene.from(
      List<PlanElement>.of(syntheticPlan()),
      metersPerUnit: mpu,
    );

    Future<void> nextNotify(ChangeNotifier n) {
      final done = Completer<void>();
      void on() {
        n.removeListener(on);
        done.complete();
      }

      n.addListener(on);
      return done.future;
    }

    test(
      'primero el grueso, y al llegar el fino avisa y es igual al de aquí',
      () async {
        final s = scene();
        final cache = PlanLightMapCache(background: true);
        addTearDown(cache.dispose);
        final arrived = nextNotify(cache);
        final first = cache.resolve(s, 1, rect);
        expect(first.columns * first.rows, greaterThan(0));
        await arrived.timeout(const Duration(seconds: 60));
        final fine = cache.resolve(s, 1, rect);
        expect(identical(fine, first), isFalse);
        final local = PlanLightMap.compute(s, rect, budget: cache.fineBudget);
        expect(fine.columns, local.columns);
        expect(fine.keyLux, closeTo(local.keyLux, 1e-3));
      },
    );

    test('si la luz cambia, lo que llega tarde se ignora', () async {
      final s = scene();
      final cache = PlanLightMapCache(background: true);
      addTearDown(cache.dispose);
      cache.resolve(s, 1, rect);
      final arrived = nextNotify(cache);
      cache.resolve(s, 2, rect);
      await arrived.timeout(const Duration(seconds: 60));
      // Solo debe quedar el de la luz 2: pedirlo ya no lanza otro cálculo.
      final map = cache.resolve(s, 2, rect);
      expect(identical(cache.resolve(s, 2, rect), map), isTrue);
    });

    test('sin segundo plano sigue calculando en el sitio', () {
      final s = scene();
      final cache = PlanLightMapCache();
      addTearDown(cache.dispose);
      final map = cache.resolve(s, 1, rect);
      expect(identical(cache.resolve(s, 1, rect), map), isTrue);
    });
  });

  test('la imagen se optimiza igual en otro hilo', () async {
    final source = img.Image(width: 64, height: 40);
    final bytes = Uint8List.fromList(img.encodePng(source));
    final here = MediaOptimizer.optimizeBytes(bytes, extension: '.png');
    final there = await MediaOptimizer.optimizeInBackground(
      bytes,
      extension: '.png',
    );
    expect(there.bytes, here.bytes);
    expect(there.extension, here.extension);
  });

  group('moodboard perezoso', () {
    Widget grid(List<int> built) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MoodboardMasonryGrid(
            itemCount: 200,
            imageAspectOf: (_) => 1,
            itemBuilder: (context, i) {
              built.add(i);
              return SizedBox(height: 280, child: Text('t$i'));
            },
          ),
        ),
      ),
    );

    testWidgets('solo construye lo cercano y, al bajar, lo siguiente', (
      tester,
    ) async {
      final built = <int>[];
      await tester.pumpWidget(grid(built));
      await tester.pump();
      expect(built, isNotEmpty);
      expect(built.length, lessThan(40));
      final before = built.length;
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -2000),
      );
      await tester.pump();
      await tester.pump();
      expect(built.length, greaterThan(before));
      expect(built.length, lessThan(200));
    });

    testWidgets('sin desplazamiento se construye todo', (tester) async {
      final built = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: OverflowBox(
            maxHeight: double.infinity,
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 800,
              child: MoodboardMasonryGrid(
                itemCount: 12,
                itemBuilder: (context, i) {
                  built.add(i);
                  return const SizedBox(height: 10);
                },
              ),
            ),
          ),
        ),
      );
      expect(built.toSet(), hasLength(12));
    });
  });
}
