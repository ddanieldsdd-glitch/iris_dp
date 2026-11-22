import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cloud/cloud_providers.dart';
import '../cloud/cloud_runtime_config.dart';
import '../cloud/supabase_config.dart';
import '../utils/error_log.dart';
import 'access_blocked_screen.dart';
import 'app_access.dart';
import 'app_access_service.dart';

/// Las compilaciones que traen la nube de IRIS (las que se reparten) piden
/// sesión y permiso del administrador. Las de desarrollo, sin claves, no.
bool get accessControlEnforced => SupabaseConfig.isConfigured;

/// Deja pasar a la app solo con el acceso abierto. Comprueba al abrir, al
/// volver a primer plano, cada hora y al cambiar la sesión. Nunca borra nada
/// del equipo: con el acceso cerrado, la app simplemente no se abre.
class AppAccessGate extends ConsumerStatefulWidget {
  const AppAccessGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppAccessGate> createState() => _AppAccessGateState();
}

class _AppAccessGateState extends ConsumerState<AppAccessGate>
    with WidgetsBindingObserver {
  AccessVerdict? _verdict;
  AccessCheck? _check;
  bool _checking = false;
  bool _again = false;
  Timer? _hourly;
  StreamSubscription<AuthState>? _authSub;
  int? _localBuild;

  @override
  void initState() {
    super.initState();
    if (!accessControlEnforced) return;
    WidgetsBinding.instance.addObserver(this);
    _hourly = Timer.periodic(const Duration(hours: 1), (_) => _evaluate());
    _listenAuth();
    _evaluate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hourly?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _evaluate();
  }

  void _listenAuth() {
    _authSub?.cancel();
    final client = ref.read(supabaseClientProvider);
    _authSub = client?.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.signedIn ||
          event.event == AuthChangeEvent.signedOut ||
          event.event == AuthChangeEvent.userUpdated) {
        _evaluate();
      }
    });
  }

  /// Usa la nube de esta compilación (no una puesta a mano).
  bool get _onIrisCloud =>
      CloudRuntimeConfig.isActive &&
      CloudRuntimeConfig.url == SupabaseConfig.url;

  Future<void> _evaluate() async {
    if (_checking) {
      _again = true;
      return;
    }
    _checking = true;
    try {
      do {
        _again = false;
        await _evaluateOnce();
      } while (_again && mounted);
    } finally {
      _checking = false;
    }
  }

  Future<void> _evaluateOnce() async {
    _localBuild ??=
        int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ?? 0;
    final client = _onIrisCloud ? ref.read(supabaseClientProvider) : null;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      _set(AccessVerdict.needsSignIn, null);
      return;
    }

    // Mientras llega la respuesta, la última guardada: sin conexión se entra
    // enseguida si aún vale.
    final cached = await AccessCheckCache.load(user.id);
    if (_verdict == null && cached != null) {
      _set(_decide(cached, fresh: false), cached);
    }

    try {
      final check = await AppAccessService(client).fetch();
      await AccessCheckCache.save(check);
      _set(_decide(check, fresh: true), check);
    } on AccessCheckUnavailable {
      // La nube aún no tiene la migración 016: se entra como hasta ahora.
      _set(AccessVerdict.open, null);
    } catch (e, st) {
      await ErrorLog.recordUnlessOffline(e, st, context: 'Comprobar el acceso');
      _set(_decide(cached, fresh: false), cached);
    }
  }

  AccessVerdict _decide(AccessCheck? check, {required bool fresh}) =>
      decideAccess(
        last: check,
        fresh: fresh,
        localBuild: _localBuild ?? 0,
        now: DateTime.now(),
      );

  void _set(AccessVerdict verdict, AccessCheck? check) {
    if (!mounted) return;
    ref.read(accessCheckProvider.notifier).state = check;
    if (verdict == _verdict && identical(check, _check)) return;
    setState(() {
      _verdict = verdict;
      _check = check;
    });
  }

  Future<void> _signIn() async {
    if (!_onIrisCloud) {
      // Vuelve a la nube de IRIS si se había elegido solo local u otra.
      await CloudRuntimeConfig.enable();
      ref.invalidate(supabaseClientProvider);
      ref.invalidate(authStateProvider);
      ref.invalidate(isCloudModeProvider);
      _listenAuth();
    }
    if (!mounted) return;
    await openAuthFromGate(context);
    ref.invalidate(currentUserProvider);
    await _evaluate();
  }

  Future<void> _signOut() async {
    await signOutFromGate(ref);
    await _evaluate();
  }

  @override
  Widget build(BuildContext context) {
    if (!accessControlEnforced) return widget.child;
    final verdict = _verdict;
    if (verdict == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (verdict == AccessVerdict.open) {
      final check = _check;
      if (check != null && check.overQuota) {
        return Column(
          children: [
            QuotaExceededBanner(check: check),
            Expanded(child: widget.child),
          ],
        );
      }
      return widget.child;
    }
    return AccessBlockedScreen(
      verdict: verdict,
      check: _check,
      checking: _checking,
      onRetry: _evaluate,
      onSignIn: _signIn,
      onSignOut: _signOut,
    );
  }
}
