import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'cloud_providers.dart';
import 'cloud_runtime_config.dart';
import 'cloud_session.dart';
import 'cloudinary_config.dart';

/// Panel reutilizable para vincular / desvincular Supabase (+ estado Cloudinary).
class CloudLinkPanel extends ConsumerStatefulWidget {
  const CloudLinkPanel({
    super.key,
    this.onLoginAction,
    this.onMigrationAction,
    this.onCloudChanged,
    this.promptRestart = true,
    this.showTitle = true,
    this.showCloudinaryStatus = true,
  });

  final VoidCallback? onLoginAction;
  final Future<void> Function()? onMigrationAction;

  /// Tras activar o desactivar la nube (útil en el tutorial para reconstruir pasos).
  final Future<void> Function({required bool active})? onCloudChanged;

  /// Si true (Ajustes), pide reiniciar la app. En tutorial suele ser false.
  final bool promptRestart;

  final bool showTitle;

  /// Banner de estado Cloudinary (en Ajustes lo muestra SettingsCloudStorageSection).
  final bool showCloudinaryStatus;

  @override
  ConsumerState<CloudLinkPanel> createState() => _CloudLinkPanelState();
}

class _CloudLinkPanelState extends ConsumerState<CloudLinkPanel> {
  final _urlCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _afterChange({required bool active, required String message}) async {
    ref.invalidate(supabaseClientProvider);
    ref.invalidate(authStateProvider);
    ref.invalidate(isCloudModeProvider);
    await widget.onCloudChanged?.call(active: active);
    if (!mounted) return;
    if (widget.promptRestart) {
      await _promptRestart(message);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _enableEmbedded() async {
    setState(() => _busy = true);
    try {
      await CloudRuntimeConfig.enable();
      if (!mounted) return;
      await _afterChange(
        active: true,
        message: widget.promptRestart
            ? 'Nube activada. Reinicia la app e inicia sesión para sincronizar.'
            : 'Nube activada. Continúa para iniciar sesión.',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo activar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enableManual() async {
    setState(() => _busy = true);
    try {
      await CloudRuntimeConfig.enable(
        url: _urlCtrl.text,
        anonKey: _keyCtrl.text,
      );
      if (!mounted) return;
      await _afterChange(
        active: true,
        message: widget.promptRestart
            ? 'Nube configurada. Reinicia la app e inicia sesión.'
            : 'Nube configurada. Continúa para iniciar sesión.',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disable() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desvincular nube'),
        content: const Text(
          'Seguirás en modo local. Tus proyectos en este Mac no se borran.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desvincular'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await CloudRuntimeConfig.disable();
      await CloudSessionStore.clear();
      if (!mounted) return;
      await _afterChange(
        active: false,
        message: widget.promptRestart
            ? 'Modo local activado. Reinicia la app.'
            : 'Modo local activado. Puedes continuar sin nube.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _promptRestart(String message) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reinicia IRIS DP'),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final active = CloudRuntimeConfig.isActive;
    final user = active ? ref.watch(currentUserProvider) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showTitle) ...[
          Text('Modo local / Nube', style: AppTypography.titleMedium(palette)),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (!active) ...[
          Text(
            'IRIS DP funciona al 100 % en local: proyectos, guion, biblia, '
            'imágenes y exportaciones. Puedes vincular Supabase ahora o más '
            'tarde desde Ajustes para sincronizar entre dispositivos.',
            style: AppTypography.caption(palette),
          ),
          const SizedBox(height: AppSpacing.md),
          if (CloudRuntimeConfig.hasEmbeddedCredentials)
            FilledButton.icon(
              onPressed: _busy ? null : _enableEmbedded,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Activar nube (credenciales del build)'),
            ),
          if (CloudRuntimeConfig.hasEmbeddedCredentials)
            const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _urlCtrl,
            decoration: const InputDecoration(
              labelText: 'SUPABASE_URL',
              hintText: 'https://tu-proyecto.supabase.co',
            ),
            autocorrect: false,
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _keyCtrl,
            decoration: const InputDecoration(labelText: 'SUPABASE_ANON_KEY'),
            obscureText: true,
            autocorrect: false,
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            onPressed: _busy ? null : _enableManual,
            icon: const Icon(Icons.link),
            label: const Text('Vincular con Supabase'),
          ),
        ] else if (user == null) ...[
          Text(
            'Nube vinculada. Inicia sesión para sincronizar proyectos.',
            style: AppTypography.caption(palette),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (widget.onLoginAction != null) ...[
            FilledButton.icon(
              onPressed: _busy ? null : widget.onLoginAction,
              icon: const Icon(Icons.login),
              label: const Text('Iniciar sesión'),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          OutlinedButton.icon(
            onPressed: _busy ? null : _disable,
            icon: const Icon(Icons.cloud_off),
            label: const Text('Volver a solo local'),
          ),
        ] else ...[
          Text(
            user.email ?? 'Sesión activa',
            style: AppTypography.bodyMedium(palette),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (widget.onMigrationAction != null) ...[
            OutlinedButton.icon(
              onPressed: _busy ? null : widget.onMigrationAction,
              icon: const Icon(Icons.upload),
              label: const Text('Subir proyectos locales a la nube'),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          OutlinedButton.icon(
            onPressed: _busy ? null : _disable,
            icon: const Icon(Icons.cloud_off),
            label: const Text('Desvincular nube (seguir en local)'),
          ),
        ],
        if (widget.showCloudinaryStatus) ...[
          const SizedBox(height: AppSpacing.md),
          const CloudinaryStatusBanner(),
        ],
      ],
    );
  }
}

/// Estado de Cloudinary (imágenes entre dispositivos).
class CloudinaryStatusBanner extends StatelessWidget {
  const CloudinaryStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final cloudActive = CloudRuntimeConfig.isActive;
    final configured = CloudinaryConfig.isConfigured;

    final Color color;
    final IconData icon;
    final String title;
    final String body;

    if (!cloudActive) {
      color = palette.textSecondary;
      icon = Icons.image_not_supported_outlined;
      title = 'Imágenes en local';
      body =
          'Cloudinary solo se usa con la nube activa. '
          'Sin Supabase, las fotos se quedan en este Mac.';
    } else if (!configured) {
      color = palette.warning;
      icon = Icons.warning_amber_outlined;
      title = 'Cloudinary no configurado';
      body =
          'Faltan CLOUDINARY_CLOUD_NAME / CLOUDINARY_UPLOAD_PRESET en el build '
          '(.env + ./scripts/run_cloud.sh). Los datos sí sincronizan; las '
          'imágenes no entre dispositivos.';
    } else {
      color = palette.success;
      icon = Icons.image_outlined;
      title = 'Cloudinary listo';
      body =
          'Cloud «${CloudinaryConfig.cloudName}» · preset '
          '«${CloudinaryConfig.uploadPreset}». '
          'Las imágenes del moodboard y planos se suben al sincronizar.';
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleMedium(palette).copyWith(
                    color: color,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: AppTypography.caption(palette).copyWith(
                    color: palette.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
