import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:iris_dp/core/cloud/cloud_providers.dart';
import 'package:iris_dp/core/cloud/profile_providers.dart';
import 'package:iris_dp/core/cloud/profile_service.dart';
import 'package:iris_dp/core/cloud/user_profile.dart';
import 'package:iris_dp/core/settings/settings_cloud_usage_section.dart';
import 'package:iris_dp/core/settings/settings_workspace_members_section.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/core/widgets/account/account_menu_button.dart';
import 'package:iris_dp/core/widgets/account/user_avatar.dart';

import 'fake_profile_backend.dart';

const _account = SignedInAccount(
  id: 'u-1',
  email: 'daniel@iris.test',
  metadataName: 'daniel',
);

void main() {
  late FakeProfileBackend backend;
  late MemoryProfileCache cache;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    backend = FakeProfileBackend()
      ..profiles['u-1'] = const UserProfile(
        id: 'u-1',
        displayName: 'Daniel Díaz',
        role: 'dp',
      );
    cache = MemoryProfileCache();
  });

  Widget host(
    Widget child, {
    SignedInAccount? account = _account,
    bool cloud = true,
  }) {
    return ProviderScope(
      overrides: [
        isCloudModeProvider.overrideWithValue(cloud),
        signedInAccountProvider.overrideWithValue(account),
        profileServiceProvider.overrideWithValue(
          ProfileService(backend, cache),
        ),
        cloudSessionRoleProvider.overrideWith((ref) async => 'owner'),
        cloudWorkspaceNameProvider.overrideWith(
          (ref) async => 'Daniel — IRIS DP',
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          appBar: AppBar(actions: [child]),
          body: const SizedBox.expand(),
        ),
      ),
    );
  }

  testWidgets('modo local: no hay avatar', (tester) async {
    await tester.pumpWidget(host(const AccountMenuButton(), cloud: false));
    expect(find.byType(UserAvatar), findsNothing);
    expect(find.text('Iniciar sesión'), findsNothing);
  });

  testWidgets('sin sesión: aviso «Iniciar sesión»', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      host(
        AccountMenuButton(onLoginAction: () => tapped = true),
        account: null,
      ),
    );
    expect(find.byType(UserAvatar), findsNothing);
    await tester.tap(find.text('Iniciar sesión'));
    expect(tapped, isTrue);
  });

  testWidgets('con sesión: iniciales y menú con email, rol y workspace', (
    tester,
  ) async {
    await tester.pumpWidget(host(const AccountMenuButton()));
    await tester.pumpAndSettle();

    expect(find.text('DD'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('account-menu')));
    await tester.pumpAndSettle();

    expect(find.text('Daniel Díaz'), findsOneWidget);
    expect(find.text('daniel@iris.test'), findsOneWidget);
    expect(find.text('DP · Daniel — IRIS DP'), findsOneWidget);
    expect(find.text('Editar perfil'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsOneWidget);
  });

  testWidgets('editar perfil cambia nombre y foto en la nube', (tester) async {
    final photo = Uint8List.fromList(
      img.encodePng(img.Image(width: 40, height: 40)),
    );
    await tester.pumpWidget(
      host(AccountMenuButton(pickImage: () async => photo)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('account-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar perfil'));
    await tester.pumpAndSettle();

    expect(find.text('Editar perfil'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Dani Díaz');
    await tester.tap(find.text('Elegir foto'));
    await tester.pumpAndSettle();
    expect(find.text('Quitar foto'), findsOneWidget);

    // La foto se procesa en otro isolate: hace falta tiempo real.
    await tester.runAsync(() async {
      await tester.tap(find.text('Guardar'));
      for (var i = 0; i < 50 && backend.uploads == 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(backend.profiles['u-1']?.displayName, 'Dani Díaz');
    expect(backend.profiles['u-1']?.hasAvatar, isTrue);
    expect(cache.avatars['u-1'], isNotNull);
    // El avatar de la barra ya enseña la foto, no las iniciales.
    expect(find.text('DD'), findsNothing);
  });

  testWidgets('el nombre no puede quedar vacío', (tester) async {
    await tester.pumpWidget(host(const AccountMenuButton()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar perfil'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe un nombre'), findsOneWidget);
    expect(backend.profiles['u-1']?.displayName, 'Daniel Díaz');
  });

  testWidgets('equipo: lista los miembros con su rol', (tester) async {
    backend.members.addAll(const [
      UserProfile(id: 'u-1', displayName: 'Daniel Díaz', role: 'owner'),
      UserProfile(id: 'u-2', displayName: 'Eva Ruiz', role: 'director'),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          signedInAccountProvider.overrideWithValue(_account),
          profileServiceProvider.overrideWithValue(
            ProfileService(backend, cache),
          ),
          workspaceMembersProvider.overrideWith((ref) async => backend.members),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: SettingsWorkspaceMembersSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Daniel Díaz (tú)'), findsOneWidget);
    expect(find.text('Eva Ruiz'), findsOneWidget);
    expect(find.text('Director'), findsOneWidget);
    expect(find.text('ER'), findsOneWidget);
  });

  testWidgets('barra de uso: texto y color por nivel', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: Column(
            children: [
              UsageBar(
                label: 'Base',
                used: 250 * 1024 * 1024,
                limit: 500 * 1024 * 1024,
              ),
              UsageBar(label: 'Archivos', used: 950, limit: 1000),
            ],
          ),
        ),
      ),
    );
    expect(find.text('250 MB de 500 MB · 50 %'), findsOneWidget);
    final bars = tester
        .widgetList<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        )
        .toList();
    expect(bars[0].value, closeTo(0.5, 0.001));
    expect(bars[1].color, isNot(bars[0].color));
  });
}
