import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

Future<void> _bootstrapApp() async {
  await AppStorageConfig.ensureLoaded();
  await initializeCloud();
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: IrisDPApp()));
}

class IrisDPApp extends ConsumerWidget {
  const IrisDPApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      key: ValueKey(themeMode),
      title: 'IRIS DP',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      home: AppSplashScreen(
        bootstrap: _bootstrapApp(),
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
