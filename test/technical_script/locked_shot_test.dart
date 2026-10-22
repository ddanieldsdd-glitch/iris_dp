import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/sync/live_editing.dart';
import 'package:iris_dp/core/sync/realtime_hub.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/technical_script/technical_script_screen.dart';

/// En el guion técnico, un plano que edita otro equipo se ve con su borde y
/// la etiqueta «Editando en iPad», con lo que escribe en vivo, y no se puede
/// tocar aquí.
void main() {
  late AppDatabase db;
  late LiveEditing live;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    live = LiveEditing(
      installId: 'mac',
      publishEditing: (_, _) {},
      publishTyping: (_, _, _) {},
    );
  });

  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('el plano que edita el iPad sale bloqueado y con su texto',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late int projectId;
    late String lockedUid;
    await tester.runAsync(() async {
      projectId = await db.insertProject(ProjectsCompanion.insert(name: 'P'));
      final sceneId = await db.insertScene(
        ScenesCompanion.insert(
          projectId: projectId,
          number: 3,
          name: 'Escena',
          locationCanonical: 'EXT. CALLE RAVAL - NOCHE',
          locationPureName: 'CALLE RAVAL',
        ),
      );
      for (var i = 1; i <= 3; i++) {
        await db.insertShot(
          ShotsCompanion.insert(
            sceneId: sceneId,
            projectId: projectId,
            number: i,
            sortOrder: Value(i),
            framing: Value('Plano $i'),
            action: const Value('Ali cruza'),
          ),
        );
      }
      final shots = await db.select(db.shots).get();
      lockedUid = shots.firstWhere((s) => s.number == 2).uid!;
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          liveEditingProvider.overrideWith((ref) => live),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: TechnicalScriptScreen(projectId: projectId),
        ),
      ),
    );
    await settle(tester);
    expect(find.text('Editando en iPad'), findsNothing);

    live.setPeers([
      PeerEditing(
        installId: 'ipad',
        device: 'iPad',
        shotUid: lockedUid,
        since: DateTime.utc(2026, 10, 18),
      ),
    ]);
    live.receiveTyping(lockedUid, 'action', 'Ali mira a cámara y sonr');
    await tester.pump();

    expect(find.text('Editando en iPad'), findsOneWidget);
    expect(find.textContaining('Ali mira a cámara y sonr'), findsOneWidget);

    // Tocarlo aquí no lo abre: dice quién lo está editando.
    await tester.tap(find.text('Plano 2'));
    await tester.pump();
    expect(find.textContaining('Lo está editando el iPad'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    // Al dejarlo el iPad, vuelve a ser normal.
    live.setPeers(const []);
    await tester.pump();
    expect(find.text('Editando en iPad'), findsNothing);
    expect(find.textContaining('Ali mira a cámara'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
