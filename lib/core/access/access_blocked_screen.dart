import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_screen.dart';
import '../cloud/cloud_usage_service.dart' show formatBytes;
import '../cloud/profile_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../update/app_update_providers.dart';
import '../update/update_actions_row.dart';
import '../widgets/app_button.dart';
import 'app_access.dart';

Future<void> openAuthFromGate(BuildContext context) => openAuthScreen(context);

Future<void> signOutFromGate(WidgetRef ref) => signOutCloud(ref);

/// Lo que se ve cuando la app no se puede abrir. Nada del equipo se borra.
class AccessBlockedScreen extends ConsumerStatefulWidget {
  const AccessBlockedScreen({
    super.key,
    required this.verdict,
    required this.check,
    required this.checking,
    required this.onRetry,
    required this.onSignIn,
    required this.onSignOut,
  });

  final AccessVerdict verdict;
  final AccessCheck? check;
  final bool checking;
  final Future<void> Function() onRetry;
  final Future<void> Function() onSignIn;
  final Future<void> Function() onSignOut;

  @override
  ConsumerState<AccessBlockedScreen> createState() =>
      _AccessBlockedScreenState();
}

class _AccessBlockedScreenState extends ConsumerState<AccessBlockedScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.verdict == AccessVerdict.outdated) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(appUpdateProvider.notifier).check(force: true),
      );
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  ({IconData icon, String title, String body}) get _copy {
    final check = widget.check;
    return switch (widget.verdict) {
      AccessVerdict.needsSignIn => (
        icon: Icons.login,
        title: 'Inicia sesión para usar IRIS',
        body:
            'Entra con tu cuenta. Si es nueva, el administrador tiene que '
            'aprobarla antes de que puedas empezar.',
      ),
      AccessVerdict.pending => (
        icon: Icons.hourglass_top,
        title: 'Tu cuenta está pendiente',
        body:
            check?.message ??
            'El administrador tiene que aprobarla. Cuando lo haga, pulsa '
                'Reintentar.',
      ),
      AccessVerdict.suspended => (
        icon: Icons.lock_outline,
        title: 'El acceso a IRIS está cerrado',
        body:
            check?.message ??
            'El administrador ha cerrado el acceso de esta cuenta. Tus '
                'proyectos siguen guardados en este equipo.',
      ),
      AccessVerdict.maintenance => (
        icon: Icons.construction,
        title: 'IRIS está en mantenimiento',
        body:
            check?.maintenanceMessage ??
            'Vuelve a intentarlo en un rato. Tus proyectos siguen guardados '
                'en este equipo.',
      ),
      AccessVerdict.outdated => (
        icon: Icons.system_update_alt,
        title: 'Hace falta actualizar IRIS',
        body:
            'Esta versión ya no se puede usar. Instala la nueva para '
            'seguir.',
      ),
      AccessVerdict.offlineExpired => (
        icon: Icons.wifi_off,
        title: 'Conéctate a internet',
        body:
            'IRIS necesita comprobar tu acceso. Sin conexión funciona '
            '${kAccessOfflineGrace.inDays} días desde la última comprobación.',
      ),
      AccessVerdict.open => (icon: Icons.check, title: '', body: ''),
    };
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final copy = _copy;
    final update = widget.verdict == AccessVerdict.outdated
        ? ref.watch(appUpdateProvider).availableRelease
        : null;
    final busy = _busy || widget.checking;

    return Scaffold(
      backgroundColor: palette.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(copy.icon, size: 40, color: palette.accent),
                const SizedBox(height: AppSpacing.md),
                Text(copy.title, style: AppTypography.titleLarge(palette)),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  copy.body,
                  style: AppTypography.bodyMedium(
                    palette,
                  ).copyWith(color: palette.textSecondary),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (update != null) ...[
                  UpdateActionsRow(release: update, showDismissLater: false),
                  const SizedBox(height: AppSpacing.md),
                ],
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    if (widget.verdict == AccessVerdict.needsSignIn)
                      AppButton(
                        label: 'Iniciar sesión',
                        icon: Icons.login,
                        loading: busy,
                        onTap: () => _run(widget.onSignIn),
                      )
                    else
                      AppButton(
                        label: 'Reintentar',
                        icon: Icons.refresh,
                        loading: busy,
                        onTap: () => _run(widget.onRetry),
                      ),
                    if (widget.verdict == AccessVerdict.pending ||
                        widget.verdict == AccessVerdict.suspended)
                      AppButton(
                        label: 'Cerrar sesión',
                        icon: Icons.logout,
                        variant: AppButtonVariant.ghost,
                        onTap: () => _run(widget.onSignOut),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Aviso fijo cuando la cuenta ha llegado a su tope de espacio.
class QuotaExceededBanner extends StatelessWidget {
  const QuotaExceededBanner({super.key, required this.check});

  final AccessCheck check;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final used = check.usedBytes ?? 0;
    final limit = check.storageLimitBytes ?? 0;
    return Material(
      color: palette.warning.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined, color: palette.warning, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Has llegado al límite de espacio en la nube '
                '(${formatBytes(used)} de ${formatBytes(limit)}). Los '
                'cambios se guardan en este equipo, pero no se suben hasta '
                'que el administrador amplíe el límite.',
                style: AppTypography.caption(palette),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
