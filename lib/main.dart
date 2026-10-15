import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/navigation/route_observer.dart';
import 'core/cloud/cloud_providers.dart';
import 'core/cloud/connectivity_gate.dart';
import 'core/storage/app_lifecycle_persistence.dart';
import 'core/storage/app_storage_config.dart';
import 'core/storage/storage_relocation_gate.dart';
import 'core/sync/media_sync_binder.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'core/update/app_update_gate.dart';
import 'core/widgets/app_background.dart';
import 'core/widgets/app_splash_screen.dart';
import 'features/onboarding/auth_required_banner.dart';
import 'features/onboarding/onboarding_gate.dart';
import 'features/projects/projects_screen.dart';
import 'core/update/update_available_banner.dart';
import 'core/utils/error_log.dart';

Future<void> _bootstrapApp() async {
  await AppStorageConfig.ensureLoaded();
  await initializeCloud();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorLog.install();
  final themeMode = await ThemeModeStore.load();
  runApp(
    ProviderScope(
      overrides: [themeModeProvider.overrideWith((ref) => themeMode)],
      child: IrisDPApp(bootstrap: _bootstrapApp()),
    ),
  );
}

class IrisDPApp extends ConsumerWidget {
  /// El arranque se lanza una sola vez, en `main`: si se creara en `build`,
  /// cada reconstrucción lo repetiría.
  final Future<void> bootstrap;

  const IrisDPApp({super.key, required this.bootstrap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sin `key` por tema: cambiar claro/oscuro no desmonta la app (antes
    // volvía al splash y a Proyectos y se perdía lo abierto).
    final themeMode = ref.watch(themeModeProvider);
    ref.listen(themeModeProvider, (_, next) => ThemeModeStore.save(next));

    return MaterialApp(
      title: 'IRIS DP',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      navigatorObservers: [routeObserver],
      home: AppSplashScreen(
        bootstrap: bootstrap,
        child: AppLifecyclePersistence(
          child: AppBackground(
            child: StorageRelocationGate(
              child: ConnectivityGate(
                child: AppUpdateGate(
                  child: MediaSyncBinder(
                    child: OnboardingGate(
                      homeContentBuilder: (_) => const Column(
                        children: [
                          AuthRequiredBanner(),
                          UpdateAvailableBanner(),
                          Expanded(child: ProjectsScreen()),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
