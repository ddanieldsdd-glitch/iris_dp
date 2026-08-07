import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/cloud_providers.dart';
import '../cloud/cloud_runtime_config.dart';
import '../cloud/cloud_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Vincular / desvincular la nube desde Ajustes (modo local-first).
class SettingsCloudLinkSection extends ConsumerStatefulWidget {
  const SettingsCloudLinkSection({
    super.key,
    this.onLoginAction,
    this.onMigrationAction,
  });

  final VoidCallback? onLoginAction;
  final Future<void> Function()? onMigrationAction;

  @override
  ConsumerState<SettingsCloudLinkSection> createState() =>
      _SettingsCloudLinkSectionState();
}

class _SettingsCloudLinkSectionState
    extends ConsumerState<SettingsCloudLinkSection> {
  final _urlCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _enableEmbedded() async {
    setState(() => _busy = true);
    try {
      await CloudRuntimeConfig.enable();
      ref.invalidate(supabaseClientProvider);
      ref.invalidate(authStateProvider);
      if (!mounted) return;
      await _promptRestart(
        'Nube activada. Reinicia la app e inicia sesión para sincronizar.',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo activar: $e')));
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
      ref.invalidate(supabaseClientProvider);
      ref.invalidate(authStateProvider);
      if (!mounted) return;
      await _promptRestart(
        'Nube configurada. Reinicia la app e inicia sesión.',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
          'Seguirás en modo local. Tus proyectos en este Mac no se borran. '
          'Reinicia la app después.',
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
    await CloudRuntimeConfig.disable();
    await CloudSessionStore.clear();
    ref.invalidate(supabaseClientProvider);
    ref.invalidate(authStateProvider);
    if (mounted) {
      setState(() => _busy = false);
      await _promptRestart('Modo local activado. Reinicia la app.');
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
        Text('Modo local / Nube', style: AppTypography.titleMedium(palette)),
        const SizedBox(height: AppSpacing.sm),
        if (!active) ...[
          Text(
            'IRIS DP funciona al 100 % en local: proyectos, guion, biblia, '
            'imágenes y exportaciones. Puedes vincular la nube más tarde para '
            'sincronizar entre dispositivos.',
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
          FilledButton.icon(
            onPressed: _busy ? null : widget.onLoginAction,
            icon: const Icon(Icons.login),
            label: const Text('Iniciar sesión'),
          ),
          const SizedBox(height: AppSpacing.sm),
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
          OutlinedButton.icon(
            onPressed: _busy ? null : widget.onMigrationAction,
            icon: const Icon(Icons.upload),
            label: const Text('Subir proyectos locales a la nube'),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: _busy ? null : _disable,
            icon: const Icon(Icons.cloud_off),
            label: const Text('Desvincular nube (seguir en local)'),
          ),
        ],
      ],
    );
  }
}
