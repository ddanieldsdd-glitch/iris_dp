import 'package:flutter/material.dart';

import '../../core/cloud/supabase_config.dart';
import '../../core/cloud/cloud_runtime_config.dart';
import '../../core/cloud/supabase_health_check.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Muestra si Supabase está vinculado y si el servidor responde.
class CloudConnectionStatusCard extends StatefulWidget {
  const CloudConnectionStatusCard({super.key});

  @override
  State<CloudConnectionStatusCard> createState() =>
      _CloudConnectionStatusCardState();
}

class _CloudConnectionStatusCardState extends State<CloudConnectionStatusCard> {
  SupabaseHealthResult? _health;
  var _checking = false;

  @override
  void initState() {
    super.initState();
    if (CloudRuntimeConfig.isActive) _check();
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    final result = await checkSupabaseReachability();
    if (mounted) {
      setState(() {
        _health = result;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final configured = CloudRuntimeConfig.isActive;
    final host = Uri.tryParse(CloudRuntimeConfig.url)?.host ??
        (Uri.tryParse(SupabaseConfig.url)?.host ?? SupabaseConfig.url);

    if (!configured) {
      return _StatusBox(
        palette: palette,
        icon: Icons.cloud_off_outlined,
        color: palette.warning,
        title: 'Modo local',
        body:
            'IRIS DP funciona al 100 % sin nube. Vincula Supabase en Ajustes '
            'cuando quieras sincronizar entre dispositivos.',
      );
    }

    if (_checking) {
      return _StatusBox(
        palette: palette,
        icon: Icons.cloud_sync_outlined,
        color: palette.accent,
        title: 'Comprobando Supabase…',
        body: host,
        trailing: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final ok = _health?.ok ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatusBox(
          palette: palette,
          icon: ok ? Icons.cloud_done_outlined : Icons.error_outline,
          color: ok ? palette.success : palette.error,
          title: ok ? 'Supabase accesible' : 'No se puede conectar a Supabase',
          body: _health?.message ?? 'Proyecto: $host',
        ),
        if (!ok) ...[
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: _check,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Verificar conexión de nuevo'),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Si tu navegador abre la URL de Supabase, puedes crear cuenta '
            'o iniciar sesión aunque este aviso siga en rojo.',
            style: AppTypography.caption(palette).copyWith(
              color: palette.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusBox extends StatelessWidget {
  final AppPalette palette;
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final Widget? trailing;

  const _StatusBox({
    required this.palette,
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleMedium(palette).copyWith(color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: AppTypography.caption(palette).copyWith(
                    color: palette.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Pasos numerados para guías del tutorial.
class TutorialNumberedSteps extends StatelessWidget {
  final List<String> steps;

  const TutorialNumberedSteps({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: palette.accent,
                  child: Text(
                    '${i + 1}',
                    style: AppTypography.caption(palette).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(steps[i], style: AppTypography.bodyMedium(palette)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
