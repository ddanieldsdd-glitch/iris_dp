import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../cloud/cloud_providers.dart';
import 'app_update_checker.dart';
import 'app_release.dart';
import 'app_update_store.dart';
import 'mac_auto_update.dart';

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

  /// Mac: la versión nueva ya descargada; se instala al cerrar IRIS.
  final StagedMacUpdate? staged;

  /// Mac: descargando y preparando la versión nueva, sin avisar.
  final bool preparing;

  /// Mac: no se pudo preparar sola (se ofrece hacerlo a mano).
  final String? prepareError;

  const AppUpdateState({
    this.availableRelease,
    this.remoteLatest,
    this.localVersionLabel = '',
    this.installedIsNewerThanPublished = false,
    this.checking = false,
    this.error,
    this.checkCompleted = false,
    this.skippedThrottle = false,
    this.staged,
    this.preparing = false,
    this.prepareError,
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
    StagedMacUpdate? staged,
    bool clearStaged = false,
    bool? preparing,
    String? prepareError,
    bool clearPrepareError = false,
  }) {
    return AppUpdateState(
      availableRelease: clearRelease
          ? null
          : (availableRelease ?? this.availableRelease),
      remoteLatest: clearRemoteLatest
          ? null
          : (remoteLatest ?? this.remoteLatest),
      localVersionLabel: localVersionLabel ?? this.localVersionLabel,
      installedIsNewerThanPublished:
          installedIsNewerThanPublished ?? this.installedIsNewerThanPublished,
      checking: checking ?? this.checking,
      error: clearError ? null : (error ?? this.error),
      checkCompleted: checkCompleted ?? this.checkCompleted,
      skippedThrottle: skippedThrottle ?? this.skippedThrottle,
      staged: clearStaged ? null : (staged ?? this.staged),
      preparing: preparing ?? this.preparing,
      prepareError: clearPrepareError
          ? null
          : (prepareError ?? this.prepareError),
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

    final kept = state;
    state = applyAppUpdateCheckResult(result).copyWith(
      staged: kept.staged,
      preparing: kept.preparing,
      prepareError: kept.prepareError,
    );
    final release = state.availableRelease;
    if (release != null && _autoUpdates) unawaited(prepare(release));
  }

  /// Mac: se actualiza sola (Windows e iPad siguen con el aviso).
  bool get _autoUpdates => !kIsWeb && Platform.isMacOS;

  bool _armed = false;

  /// Al abrir: si quedó una versión preparada (más nueva que esta), se deja
  /// lista para instalarse al cerrar; si es igual o más vieja, se tira.
  Future<void> resumeStaged() async {
    if (!_autoUpdates) return;
    final staged = await MacAutoUpdate.staged();
    if (staged == null) return;
    final info = await PackageInfo.fromPlatform();
    final local = int.tryParse(info.buildNumber) ?? 0;
    if (staged.buildNumber <= local) {
      await MacAutoUpdate.discard();
      return;
    }
    await _arm(staged);
  }

  Future<void> _arm(StagedMacUpdate staged) async {
    if (!_armed) {
      await MacAutoUpdate.applyOnExit(staged);
      _armed = true;
    }
    state = state.copyWith(staged: staged, preparing: false);
  }

  /// Mac: descarga y prepara [release] sin avisar; se instala al cerrar.
  Future<void> prepare(AppRelease release) async {
    if (state.preparing) return;
    final current = state.staged;
    if (current != null && current.buildNumber >= release.buildNumber) return;
    state = state.copyWith(preparing: true, clearPrepareError: true);
    try {
      final staged = await MacAutoUpdate.stage(release);
      _armed = false;
      await _arm(staged);
    } catch (e) {
      debugPrint('No se pudo preparar la actualización: $e');
      state = state.copyWith(preparing: false, prepareError: '$e');
    }
  }

  /// Mac: instala ya la versión preparada (o la prepara) y vuelve a abrir.
  Future<void> restartNow(AppRelease? release) async {
    var staged = state.staged ?? await MacAutoUpdate.staged();
    if (staged == null && release != null) {
      staged = await MacAutoUpdate.stage(release);
    }
    if (staged == null) return;
    await MacAutoUpdate.applyOnExit(staged, relaunch: true);
    exit(0);
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

final appUpdateProvider = NotifierProvider<AppUpdateNotifier, AppUpdateState>(
  AppUpdateNotifier.new,
);
