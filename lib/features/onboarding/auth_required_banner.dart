import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cloud/cloud_providers.dart';
import '../../core/cloud/cloud_runtime_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../auth/auth_screen.dart';

/// Banner visible cuando la nube está activa pero no hay sesión iniciada.
class AuthRequiredBanner extends ConsumerWidget {
  const AuthRequiredBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!CloudRuntimeConfig.isActive) return const SizedBox.shrink();

    final user = ref.watch(currentUserProvider);
    if (user != null) return const SizedBox.shrink();

    final palette = context.palette;

    return Material(
      color: palette.warning.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined, color: palette.warning),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Inicia sesión para usar la nube',
                    style: AppTypography.titleMedium(palette),
                  ),
                  Text(
                    'Tus proyectos están en Supabase. Crea cuenta o entra con '
                    'tu email para sincronizar con otros Mac o iPad.',
                    style: AppTypography.caption(palette).copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            AppButton(
              label: 'Iniciar sesión',
              icon: Icons.login,
              onTap: () async {
                final ok = await openAuthScreen(context);
                if (ok == true && context.mounted) {
                  ref.invalidate(currentUserProvider);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
