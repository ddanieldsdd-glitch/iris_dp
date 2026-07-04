import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_button.dart';
import '../widgets/app_theme_toggle.dart';
import 'api_key_provider.dart';
import 'api_key_storage.dart';
import '../../core/widgets/app_snackbar.dart';

/// Ajustes de la app: API key de Claude para normalización de escenas.
class SettingsSheet extends ConsumerStatefulWidget {
  const SettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SettingsSheet(),
    );
  }

  @override
  ConsumerState<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<SettingsSheet> {
  late final TextEditingController _keyController;
  bool _obscure = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController();
    _loadExistingKey();
  }

  Future<void> _loadExistingKey() async {
    final key = await ApiKeyStorage.readClaudeApiKey();
    if (key != null && mounted) {
      _keyController.text = key;
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final key = _keyController.text.trim();
      if (key.isEmpty) {
        await ref.read(claudeApiKeyProvider.notifier).clear();
      } else {
        await ref.read(claudeApiKeyProvider.notifier).save(key);
      }
      if (!mounted) return;
      Navigator.pop(context);
      AppSnackBar.show(context, key.isEmpty ? 'Clave de IA eliminada.' : 'Clave de IA guardada.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final keyAsync = ref.watch(claudeApiKeyProvider);

    final hasValidKey = keyAsync.maybeWhen(
      data: (k) => k != null && !ApiKeyStorage.isPlaceholderKey(k),
      orElse: () => false,
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: palette.surfaceElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ajustes', style: AppTypography.titleLarge(palette)),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Clave API de Anthropic (Claude)',
              style: AppTypography.titleMedium(palette),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Opcional. Se guarda localmente en tu Mac y no se incluye en la app. '
              'Sirve para normalizar sluglines al importar guiones.',
              style: AppTypography.bodyMedium(palette),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _keyController,
              obscureText: _obscure,
              style: AppTypography.bodyLarge(palette),
              decoration: InputDecoration(
                hintText: 'sk-ant-...',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: palette.textSecondary,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            if (hasValidKey) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 16, color: palette.success),
                  const SizedBox(width: 6),
                  Text(
                    'Clave configurada',
                    style: AppTypography.caption(palette)
                        .copyWith(color: palette.success),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            Text('Apariencia', style: AppTypography.titleMedium(palette)),
            const SizedBox(height: AppSpacing.sm),
            const AppThemeToggle(),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Cancelar',
                    variant: AppButtonVariant.secondary,
                    onTap: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppButton(
                    label: _saving ? 'Guardando...' : 'Guardar',
                    onTap: _saving ? null : _save,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
