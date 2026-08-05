import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/cloud_providers.dart';
import 'app_update_checker.dart';
import 'app_release.dart';
import 'app_update_store.dart';

/// Estado de comprobación de actualización remota.
class AppUpdateState {
  final AppRelease? availableRelease;
  final AppRelease? remoteLatest;
  final String localVersionLabel;
  final bool installedIsNewerThanPublished;
  final bool checking;
  final String? error;
  final bool checkCompleted;
  final bool skippedThrottle;

  const AppUpdateState({
    this.availableRelease,
    this.remoteLatest,
    this.localVersionLabel = '',
    this.installedIsNewerThanPublished = false,
    this.checking = false,
    this.error,
    this.checkCompleted = false,
    this.skippedThrottle = false,
  });

  bool get hasUpdate => availableRelease != null;

  String? get remoteVersionLabel {
    final remote = remoteLatest;
    if (remote == null) return null;
    return '${remote.version} (${remote.buildNumber})';
  }

  AppUpdateState copyWith({
    AppRelease? availableRelease,
    AppRelease? remoteLatest,
    bool clearRelease = false,
    bool clearRemoteLatest = false,
    String? localVersionLabel,
    bool? installedIsNewerThanPublished,
    bool? checking,
    String? error,
    bool clearError = false,
    bool? checkCompleted,
    bool? skippedThrottle,
  }) {
    return AppUpdateState(
      availableRelease:
          clearRelease ? null : (availableRelease ?? this.availableRelease),
      remoteLatest: clearRemoteLatest
          ? null
          : (remoteLatest ?? this.remoteLatest),
      localVersionLabel: localVersionLabel ?? this.localVersionLabel,
      installedIsNewerThanPublished: installedIsNewerThanPublished ??
          this.installedIsNewerThanPublished,
      checking: checking ?? this.checking,
      error: clearError ? null : (error ?? this.error),
      checkCompleted: checkCompleted ?? this.checkCompleted,
      skippedThrottle: skippedThrottle ?? this.skippedThrottle,
    );
  }
}

/// Aplica el resultado de [checkForAppUpdate] al estado del notifier.
AppUpdateState applyAppUpdateCheckResult(AppUpdateCheckResult result) {
  return AppUpdateState(
    availableRelease: result.availableRelease,
    remoteLatest: result.remoteLatest,
    localVersionLabel: result.localVersionLabel,
    installedIsNewerThanPublished: result.installedIsNewerThanPublished,
    checking: false,
    error: result.error,
    checkCompleted: true,
    skippedThrottle: result.skippedThrottle,
  );
}

class AppUpdateNotifier extends Notifier<AppUpdateState> {
  @override
  AppUpdateState build() => const AppUpdateState();

  Future<void> check({bool force = false}) async {
    final client = ref.read(supabaseClientProvider);
    if (client == null) {
      state = state.copyWith(
        checking: false,
        checkCompleted: true,
        error: 'Supabase no configurado en esta compilación',
      );
      return;
    }

    state = state.copyWith(
      checking: true,
      clearError: true,
      clearRelease: true,
      clearRemoteLatest: true,
    );
    final result = await checkForAppUpdate(client: client, force: force);

    state = applyAppUpdateCheckResult(result);
  }

  Future<void> dismissLater() async {
    final release = state.availableRelease;
    if (release == null) return;
    await AppUpdateStore.dismissBuild(release.platform, release.buildNumber);
    state = state.copyWith(clearRelease: true);
  }

  Future<void> markUpdated() async {
    final platform = currentReleasePlatform();
    await AppUpdateStore.clearDismissed(platform);
    state = state.copyWith(clearRelease: true);
    await check(force: true);
  }
}

final appUpdateProvider =
    NotifierProvider<AppUpdateNotifier, AppUpdateState>(AppUpdateNotifier.new);
