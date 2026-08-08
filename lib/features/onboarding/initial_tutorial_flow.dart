import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cloud/cloud_providers.dart';
import '../../core/cloud/cloud_session.dart';
import '../../core/cloud/cloud_runtime_config.dart';
import '../../core/cloud/app_version_sync.dart';
import '../../core/update/app_update_providers.dart';
import '../../core/storage/app_storage_config.dart';
import '../../core/storage/storage_setup_screen.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_snackbar.dart';
import '../auth/auth_screen.dart';
import '../migration/cloud_migration_wizard.dart';
import 'app_tutorial_store.dart';
import 'cloud_tutorial_pages.dart';
import 'home_tutorial_overlay.dart';
import 'install_update_guide_screen.dart';
import 'tutorial_shell.dart';

enum _TutorialPhase {
  infoWelcome,
  cloudLink,
  macInstall,
  auth,
  infoStorage,
  storage,
  infoSyncUpdate,
  migration,
  infoFirstSteps,
  home,
}

/// Tutorial paso a paso: nube, cuenta, carpetas, sync y primeros pasos.
class InitialTutorialFlow extends ConsumerStatefulWidget {
  final bool replayFromStart;

  /// Contenido de la fase «home» (p. ej. listado de proyectos).
  final WidgetBuilder homeContentBuilder;

  const InitialTutorialFlow({
    super.key,
    this.replayFromStart = false,
    required this.homeContentBuilder,
  });

  @override
  ConsumerState<InitialTutorialFlow> createState() =>
      _InitialTutorialFlowState();
}

class _InitialTutorialFlowState extends ConsumerState<InitialTutorialFlow> {
  var _loading = true;
  var _phaseIndex = 0;
  late List<_TutorialPhase> _phases;
  var _needsMigration = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final cloud = CloudRuntimeConfig.isActive;
    _needsMigration = cloud && !await CloudSessionStore.isMigrationComplete();
    _phases = _buildPhases(cloud: cloud, needsMigration: _needsMigration);

    if (widget.replayFromStart) {
      _phaseIndex = 0;
    } else {
      _phaseIndex = await _resolveStartIndex(cloud);
    }

    if (mounted) setState(() => _loading = false);

    if (_currentPhase == _TutorialPhase.home) {
      await _enterHome();
    }
  }

  List<_TutorialPhase> _buildPhases({
    required bool cloud,
    required bool needsMigration,
  }) {
    final phases = <_TutorialPhase>[
      _TutorialPhase.infoWelcome,
      _TutorialPhase.cloudLink,
    ];
    if (cloud) {
      phases.addAll([
        _TutorialPhase.macInstall,
        _TutorialPhase.auth,
      ]);
    } else {
      phases.add(_TutorialPhase.macInstall);
    }
    phases.addAll([
      _TutorialPhase.infoStorage,
      _TutorialPhase.storage,
    ]);
    if (cloud) {
      phases.add(_TutorialPhase.infoSyncUpdate);
      if (needsMigration) phases.add(_TutorialPhase.migration);
    }
    phases.addAll([
      _TutorialPhase.infoFirstSteps,
      _TutorialPhase.home,
    ]);
    return phases;
  }

  Future<void> _onCloudLinkChanged({required bool active}) async {
    _needsMigration =
        active && !await CloudSessionStore.isMigrationComplete();
    final cloudLinkIndex = _phases.indexOf(_TutorialPhase.cloudLink);
    _phases = _buildPhases(
      cloud: active,
      needsMigration: _needsMigration,
    );
    final newIndex = cloudLinkIndex >= 0
        ? _phases.indexOf(_TutorialPhase.cloudLink)
        : 0;
    if (mounted) {
      setState(() {
        _phaseIndex = newIndex >= 0 ? newIndex : 0;
      });
    }
  }

  Future<int> _resolveStartIndex(bool cloud) async {
    final user = ref.read(supabaseClientProvider)?.auth.currentUser;
    final storageOk = AppStorageConfig.isConfigured;

    // Sin sesión en modo nube → paso de vinculación (entrar/salir) antes de auth.
    if (cloud && user == null) {
      final link = _phases.indexOf(_TutorialPhase.cloudLink);
      return link >= 0 ? link : _phases.indexOf(_TutorialPhase.auth);
    }

    if (storageOk && (!cloud || user != null)) {
      await AppTutorialStore.setIntroComplete(true);
      return _phases.indexOf(_TutorialPhase.home);
    }

    if (!storageOk && cloud && user != null) {
      return _phases.indexOf(_TutorialPhase.infoStorage);
    }

    if (cloud && _needsMigration && user != null && storageOk) {
      return _phases.indexOf(_TutorialPhase.migration);
    }

    return 0;
  }

  _TutorialPhase get _currentPhase => _phases[_phaseIndex];

  int get _totalSteps => _phases.length - 1;

  int get _displayStepIndex =>
      _currentPhase == _TutorialPhase.home ? _totalSteps : _phaseIndex;

  void _goNext() {
    if (_phaseIndex < _phases.length - 1) {
      setState(() => _phaseIndex++);
      if (_currentPhase == _TutorialPhase.home) _enterHome();
    }
  }

  void _goBack() {
    if (_phaseIndex > 0) setState(() => _phaseIndex--);
  }

  Future<void> _enterHome() async {
    await CloudSessionStore.setOnboardingComplete(true);
    await AppTutorialStore.setIntroComplete(true);
    await _runSync();

    if (!mounted) return;
    await ref.read(appUpdateProvider.notifier).check(force: true);
    if (!mounted) return;
    final syncResult = await syncAfterAppUpdateIfNeeded(ref);
    if (syncResult.message != null && mounted) {
      AppSnackBar.show(context, syncResult.message!);
    }
  }

  Future<void> _runSync() async {
    if (!CloudRuntimeConfig.isActive) return;
    final user = ref.read(supabaseClientProvider)?.auth.currentUser;
    if (user == null) return;
    try {
      await ref.read(syncEngineProvider).syncOnStartup();
    } catch (_) {}
  }

  Future<void> _onMigrationDone() async {
    _needsMigration = false;
    _phases = _buildPhases(
      cloud: CloudRuntimeConfig.isActive,
      needsMigration: false,
    );
    _goNext();
  }

  TutorialInfoStep? _infoForPhase(_TutorialPhase phase) {
    final cloud = CloudRuntimeConfig.isActive;
    final steps = buildTutorialInfoSteps(cloudMode: cloud);
    return switch (phase) {
      _TutorialPhase.infoWelcome => steps[0],
      _TutorialPhase.infoStorage => steps[1],
      _TutorialPhase.infoSyncUpdate => cloud ? steps[2] : null,
      _TutorialPhase.infoFirstSteps => steps[cloud ? 3 : 2],
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final phase = _currentPhase;

    if (phase == _TutorialPhase.home) {
      return HomeTutorialOverlay(
        onComplete: () async {
          await AppTutorialStore.setHomeTourComplete(true);
        },
        child: widget.homeContentBuilder(context),
      );
    }

    if (phase == _TutorialPhase.cloudLink) {
      return CloudLinkTutorialPage(
        stepIndex: _displayStepIndex,
        totalSteps: _totalSteps,
        onBack: _goBack,
        onNext: _goNext,
        onCloudChanged: _onCloudLinkChanged,
      );
    }

    if (phase == _TutorialPhase.macInstall) {
      return MacInstallTutorialPage(
        stepIndex: _displayStepIndex,
        totalSteps: _totalSteps,
        onBack: _goBack,
        onNext: _goNext,
      );
    }

    if (phase == _TutorialPhase.auth) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TutorialProgressHeader(
            stepIndex: _displayStepIndex,
            totalSteps: _totalSteps,
            title: 'Iniciar sesión',
          ),
          Expanded(
            child: AuthScreen(
              embeddedInTutorial: true,
              onAuthenticated: _goNext,
            ),
          ),
        ],
      );
    }

    if (phase == _TutorialPhase.storage) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TutorialProgressHeader(
            stepIndex: _displayStepIndex,
            totalSteps: _totalSteps,
            title: 'Almacenamiento',
          ),
          Expanded(
            child: StorageSetupScreen(onConfigured: _goNext),
          ),
        ],
      );
    }

    if (phase == _TutorialPhase.migration) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TutorialProgressHeader(
            stepIndex: _displayStepIndex,
            totalSteps: _totalSteps,
            title: 'Migración',
          ),
          Expanded(
            child: CloudMigrationWizard(
              onComplete: _onMigrationDone,
              onSkip: _onMigrationDone,
            ),
          ),
        ],
      );
    }

    final info = _infoForPhase(phase);
    if (info == null) {
      return const Scaffold(body: Center(child: Text('Paso no encontrado')));
    }

    final isLastInfo = phase == _TutorialPhase.infoFirstSteps;
    final isSyncStep = phase == _TutorialPhase.infoSyncUpdate;

    return TutorialInfoPage(
      step: info,
      stepIndex: _displayStepIndex,
      totalSteps: _totalSteps,
      onBack: _phaseIndex > 0 ? _goBack : null,
      onNext: _goNext,
      nextLabel: isLastInfo
          ? 'Entrar a IRIS DP'
          : (isSyncStep ? 'Entendido, continuar' : 'Siguiente'),
    );
  }
}

/// Cabecera de progreso para pantallas de acción (auth, storage…).
class TutorialProgressHeader extends StatelessWidget {
  final int stepIndex;
  final int totalSteps;
  final String title;

  const TutorialProgressHeader({
    super.key,
    required this.stepIndex,
    required this.totalSteps,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final progress = (stepIndex + 1) / totalSteps;

    return Material(
      color: palette.surface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Paso ${stepIndex + 1} de $totalSteps',
                    style: AppTypography.caption(palette).copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: AppTypography.caption(palette).copyWith(
                      color: palette.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: palette.border,
                  color: palette.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void openInstallUpdateGuide(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const InstallUpdateGuideScreen(),
    ),
  );
}
