import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/unreal_link/unreal_library.dart';
import 'package:iris_dp/features/unreal_link/unreal_library_screen.dart';
import 'package:iris_dp/features/unreal_link/unreal_link.dart';
import 'package:shared_preferences/shared_preferences.dart';

UnrealAssetRef _ref(String path, {List<double>? size, String? thumb}) =>
    UnrealAssetRef.fromPath(path, sizeCm: size).copyWith(
      thumb34: thumb,
      thumbTop: thumb?.replaceAll('_34', '_top'),
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('recuerda lo usado y lo encontrado, sin pisarlo', () async {
    final lib = UnrealLibrary()..clearForTest();
    await lib.remember(
      _ref('/Game/Fab/Sofa/SM_Sofa.SM_Sofa', thumb: 'aaaaaaaaaaaaaaaaaaaa_34'),
      projectId: 7,
    );
    final added = await lib.addFound([
      _ref('/Game/Fab/Sofa/SM_Sofa.SM_Sofa'),
      _ref('/Game/Megascans/Rock/SM_Rock.SM_Rock'),
    ]);
    expect(added, 1);
    final sofa = lib.entryOf('/Game/Fab/Sofa/SM_Sofa.SM_Sofa')!;
    expect(sofa.ref.thumb34, 'aaaaaaaaaaaaaaaaaaaa_34');
    expect(sofa.thumbProjectId, 7);
    // Lo usado va antes que lo solo encontrado.
    expect(lib.entries.first.ref.name, 'SM_Sofa');
    // Volver a usarlo sin miniaturas conserva las que tenía.
    await lib.remember(_ref('/Game/Fab/Sofa/SM_Sofa.SM_Sofa'));
    expect(
      lib.entryOf('/Game/Fab/Sofa/SM_Sofa.SM_Sofa')!.ref.thumb34,
      'aaaaaaaaaaaaaaaaaaaa_34',
    );
  });

  test('favoritos primero, búsqueda sin Unreal y quitar', () async {
    final lib = UnrealLibrary()..clearForTest();
    await lib.addFound([
      _ref('/Game/Fab/Chair/SM_Chair.SM_Chair'),
      _ref('/Game/Megascans/Rock/SM_Rock.SM_Rock'),
    ]);
    await lib.toggleFavorite('/Game/Megascans/Rock/SM_Rock.SM_Rock');
    expect(lib.entries.first.ref.name, 'SM_Rock');
    expect([for (final e in lib.search('chair')) e.ref.name], ['SM_Chair']);
    expect([for (final e in lib.search('megascans')) e.ref.name], ['SM_Rock']);
    expect(lib.search('', favoritesOnly: true), hasLength(1));
    await lib.remove('/Game/Fab/Chair/SM_Chair.SM_Chair');
    expect(lib.entries, hasLength(1));
  });

  test('lo que llega de otro equipo se junta con lo de aquí', () async {
    final here = UnrealLibrary()..clearForTest();
    await here.addFound([_ref('/Game/Fab/A.A')]);
    await here.toggleFavorite('/Game/Fab/A.A');
    final there = UnrealLibrary()..clearForTest();
    await there.remember(
      _ref('/Game/Fab/A.A', thumb: 'bbbbbbbbbbbbbbbbbbbb_34'),
      projectId: 3,
    );
    await there.addFound([_ref('/Game/Fab/B.B')]);
    here.importJson(there.encode());
    final a = here.entryOf('/Game/Fab/A.A')!;
    expect(a.favorite, isTrue);
    expect(a.ref.thumb34, 'bbbbbbbbbbbbbbbbbbbb_34');
    expect(a.thumbProjectId, 3);
    expect(here.entryOf('/Game/Fab/B.B'), isNotNull);
  });

  test('cada asset se pone en la planta como el elemento que toca', () {
    final sofa = UnrealLibrary.elementFor(
      _ref('/Game/Fab/Sofa/SM_Sofa_Velvet_01.SM_Sofa_Velvet_01',
          size: [210, 95, 85]),
    );
    expect(sofa.propType, PropType.sofa);
    expect(sofa.displayLabel, 'Sofa Velvet 01');
    expect(sofa.props['size'], 2.1);
    expect(UnrealAssetRef.of(sofa)?.name, 'SM_Sofa_Velvet_01');

    final ada = UnrealLibrary.elementFor(
      UnrealAssetRef.fromPath(
        '/Game/MetaHumans/Ada/BP_Ada.BP_Ada',
        kind: UnrealAssetKind.metahuman,
      ),
    );
    expect(ada.type, ElementType.actor);
    expect(ada.label, 'ADA');

    expect(UnrealLibrary.propTypeFor('SM_OfficeDesk'), PropType.table);
    expect(UnrealLibrary.propTypeFor('SM_Pine_Tree_03'), PropType.tree);
    expect(UnrealLibrary.propTypeFor('SM_Lamp'), PropType.rectangle);
  });

  testWidgets('la pantalla enseña la biblioteca y pone en la planta', (
    tester,
  ) async {
    final lib = UnrealLibrary()..clearForTest();
    await tester.runAsync(
      () => lib.addFound([
        _ref('/Game/Fab/Chair/SM_Chair.SM_Chair', size: [50, 50, 90]),
        _ref('/Game/Megascans/Rock/SM_Rock.SM_Rock'),
      ]),
    );
    UnrealAssetRef? placed;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => UnrealLibraryScreen(
                  library: lib,
                  link: UnrealLink(),
                  onPlace: (r) => placed = r,
                ),
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Chair'), findsOneWidget);
    expect(find.text('Rock'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'rock');
    await tester.pump();
    expect(find.text('Chair'), findsNothing);
    await tester.tap(find.text('Poner en la planta'));
    await tester.pumpAndSettle();
    expect(placed?.name, 'SM_Rock');
  });
}
