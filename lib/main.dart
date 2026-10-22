import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/navigation/route_observer.dart';
import 'core/cloud/cloud_providers.dart';
import 'core/cloud/connectivity_gate.dart';
import 'core/storage/app_lifecycle_persistence.dart';
import 'core/storage/app_storage_config.dart';
import 'core/storage/storage_relocation_gate.dart';
import 'core/sync/auto_sync_scheduler.dart';
import 'core/sync/media_sync_binder.dart';
import 'core/theme/app_theme.dart';
import 'core/update/app_update_gate.dart';
import 'core/widgets/app_background.dart';
import 'core/widgets/app_splash_screen.dart';
import 'features/onboarding/auth_required_banner.dart';
import 'features/onboarding/onboarding_gate.dart';
import 'features/projects/projects_screen.dart';
import 'core/utils/error_log.dart';
import 'shared/annotations/brushes/auto_import.dart';

Future<void> _bootstrapApp() async {
  await AppStorageConfig.ensureLoaded();
  await initializeCloud();
  // Pinceles, papeles y paletas dejados en Documents/Importar: en segundo
  // plano, sin retrasar el arranque.
  unawaited(AutoImport.run());
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorLog.install();
  runApp(ProviderScope(child: IrisDPApp(bootstrap: _bootstrapApp())));
}

class IrisDPApp extends StatelessWidget {
  /// El arranque se lanza una sola vez, en `main`: si se creara en `build`,
  /// cada reconstrucción lo repetiría.
  final Future<void> bootstrap;

  const IrisDPApp({super.key, required this.bootstrap});

  @override
  Widget build(BuildContext context) {
    // Solo tema oscuro: el claro se quitó (2026-10-15).
    return MaterialApp(
      title: 'IRIS',
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      navigatorObservers: [routeObserver],
      home: AppSplashScreen(
        bootstrap: bootstrap,
        child: AppLifecyclePersistence(
          child: AppBackground(
            child: StorageRelocationGate(
              child: ConnectivityGate(
                child: AutoSyncScheduler(
                  child: AppUpdateGate(
                    child: MediaSyncBinder(
                      child: OnboardingGate(
                        homeContentBuilder: (_) => const Column(
                          children: [
                            AuthRequiredBanner(),
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
      ),
    );
  }
}
