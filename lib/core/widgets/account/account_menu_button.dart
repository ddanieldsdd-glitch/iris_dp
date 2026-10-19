import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cloud/cloud_providers.dart';
import '../../cloud/profile_providers.dart';
import '../../cloud/user_profile.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'edit_profile_dialog.dart';
import 'user_avatar.dart';

/// Avatar de la cuenta en la barra de proyectos: dice de un vistazo si hay
/// sesión y abre un menú con el perfil.
class AccountMenuButton extends ConsumerWidget {
  const AccountMenuButton({
    super.key,
    this.onLoginAction,
    this.pickImage = pickImageBytes,
  });

  final VoidCallback? onLoginAction;
  final ImageBytesPicker pickImage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isCloudModeProvider)) return const SizedBox.shrink();
    final palette = context.palette;

    final account = ref.watch(signedInAccountProvider);
    if (account == null) {
      return TextButton.icon(
        key: const ValueKey('account-login'),
        onPressed: onLoginAction,
        icon: Icon(
          Icons.account_circle_outlined,
          size: 22,
          color: palette.warning,
        ),
        label: Text(
          'Iniciar sesión',
          style: AppTypography.caption(
            palette,
          ).copyWith(color: palette.warning),
        ),
      );
    }

    final snapshot = ref.watch(currentProfileProvider).valueOrNull;
    final profile =
        snapshot?.profile ??
        UserProfile(
          id: account.id,
          displayName: account.fallbackName,
          email: account.email,
        );
    final sessionRole = ref.watch(cloudSessionRoleProvider).valueOrNull;
    final role = roleLabel(sessionRole ?? profile.role);
    final workspace = ref.watch(cloudWorkspaceNameProvider).valueOrNull;

    return PopupMenuButton<_AccountAction>(
      key: const ValueKey('account-menu'),
      tooltip: 'Sesión iniciada · ${profile.label}',
      position: PopupMenuPosition.under,
      color: palette.surfaceElevated,
      onOpened: () => ref.read(currentProfileProvider.notifier).refresh(),
      onSelected: (action) async {
        switch (action) {
          case _AccountAction.edit:
            final current = ref.read(currentProfileProvider).valueOrNull;
            if (current == null) return;
            await EditProfileDialog.show(
              context,
              current,
              pickImage: pickImage,
            );
          case _AccountAction.signOut:
            await _confirmSignOut(context, ref);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<_AccountAction>(
          enabled: false,
          child: Row(
            children: [
              UserAvatar(
                profile: profile,
                bytes: snapshot?.avatarBytes,
                size: 40,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      profile.label,
                      style: AppTypography.bodyMedium(palette),
                    ),
                    if (account.email != null)
                      Text(
                        account.email!,
                        style: AppTypography.caption(palette),
                      ),
                    Text(
                      workspace == null ? role : '$role · $workspace',
                      style: AppTypography.caption(
                        palette,
                      ).copyWith(color: palette.accent),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _AccountAction.edit,
          child: _MenuRow(icon: Icons.edit_outlined, label: 'Editar perfil'),
        ),
        const PopupMenuItem(
          value: _AccountAction.signOut,
          child: _MenuRow(icon: Icons.logout, label: 'Cerrar sesión'),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: UserAvatar(
          profile: profile,
          bytes: snapshot?.avatarBytes,
          size: 32,
          ringColor: palette.success,
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
          'Tus proyectos se quedan en este dispositivo. Para volver a '
          'sincronizar tendrás que iniciar sesión otra vez.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (ok == true) await signOutCloud(ref);
  }
}

enum _AccountAction { edit, signOut }

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Icon(icon, size: 18, color: palette.textSecondary),
        const SizedBox(width: 10),
        Text(label, style: AppTypography.bodyMedium(palette)),
      ],
    );
  }
}
