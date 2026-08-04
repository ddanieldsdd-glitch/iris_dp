import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/cloud_providers.dart';
import 'app_update_checker.dart';
import 'app_release.dart';
import 'app_update_store.dart';

/// Estado de comprobación de actualización remota.
class AppUpdateState {
  final AppRelease? availableRelease;
  final bool checking;
  final String? error;
  final bool checkCompleted;

  const AppUpdateState({
    this.availableRelease,
    this.checking = false,
    this.error,
    this.checkCompleted = false,
  });

  bool get hasUpdate => availableRelease != null;

  AppUpdateState copyWith({
    AppRelease? availableRelease,
    bool clearRelease = false,
    bool? checking,
    String? error,
    bool clearError = false,
    bool? checkCompleted,
  }) {
    return AppUpdateState(
      availableRelease:
          clearRelease ? null : (availableRelease ?? this.availableRelease),
      checking: checking ?? this.checking,
      error: clearError ? null : (error ?? this.error),
      checkCompleted: checkCompleted ?? this.checkCompleted,
    );
  }
}

/// Aplica el resultado de [checkForAppUpdate] al estado del notifier.
AppUpdateState applyAppUpdateCheckResult(AppUpdateCheckResult result) {
  return AppUpdateState(
    availableRelease: result.availableRelease,
    checking: false,
    error: result.error,
    checkCompleted: true,
  );
}

class AppUpdateNotifier extends Notifier<AppUpdateState> {
  @override
  AppUpdateState build() => const AppUpdateState();

  Future<void> check({bool force = false}) async {
    final client = ref.read(supabaseClientProvider);
    if (client == null) return;

    state = state.copyWith(checking: true, clearError: true);
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
