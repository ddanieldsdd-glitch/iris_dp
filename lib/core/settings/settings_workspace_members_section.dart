import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/profile_providers.dart';
import '../cloud/user_profile.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/account/user_avatar.dart';

/// Personas del workspace con su nombre y foto.
class SettingsWorkspaceMembersSection extends ConsumerWidget {
  const SettingsWorkspaceMembersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final account = ref.watch(signedInAccountProvider);
    if (account == null) return const SizedBox.shrink();
    final me = ref.watch(currentProfileProvider).valueOrNull;
    final members = ref.watch(workspaceMembersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Equipo', style: AppTypography.titleMedium(palette)),
        const SizedBox(height: AppSpacing.sm),
        members.when(
          loading: () =>
              Text('Cargando equipo…', style: AppTypography.caption(palette)),
          error: (_, __) => Text(
            'No se pudo cargar el equipo (¿falta la migración 012?).',
            style: AppTypography.caption(palette),
          ),
          data: (list) {
            if (list.isEmpty) {
              return Text(
                'Aún no hay nadie más en el workspace.',
                style: AppTypography.caption(palette),
              );
            }
            return Column(
              children: [
                for (final p in list)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: UserAvatar(
                      profile: p,
                      bytes: p.id == account.id ? me?.avatarBytes : null,
                      size: 32,
                    ),
                    title: Text(
                      p.id == account.id ? '${p.label} (tú)' : p.label,
                      style: AppTypography.bodyMedium(palette),
                    ),
                    subtitle: Text(
                      roleLabel(p.role),
                      style: AppTypography.caption(palette),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
