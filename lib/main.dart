import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/cloud/cloud_providers.dart';
import 'core/storage/app_storage_config.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'core/update/app_update_gate.dart';
import 'core/widgets/app_background.dart';
import 'features/onboarding/onboarding_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppStorageConfig.ensureLoaded();
  await initializeCloud();
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
      home: const AppBackground(
        child: AppUpdateGate(child: OnboardingGate()),
      ),
    );
  }
}
