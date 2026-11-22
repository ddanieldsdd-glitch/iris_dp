import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../cloud/profile_providers.dart';
import '../cloud/project_role.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_snackbar.dart';
import 'app_invite.dart';

/// Tras crear una invitación: el código, el enlace y cómo mandarlo
/// (Compartir abre Correo, WhatsApp, Mensajes…). IRIS no envía nada sola.
class InviteShareSheet extends ConsumerWidget {
  const InviteShareSheet({super.key, required this.invite, this.projectName});

  final AppInvite invite;
  final String? projectName;

  static Future<void> show(
    BuildContext context, {
    required AppInvite invite,
    String? projectName,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.palette.surfaceElevated,
    builder: (_) => InviteShareSheet(invite: invite, projectName: projectName),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final from = ref
        .watch(currentProfileProvider)
        .valueOrNull
        ?.profile
        .displayName;
    final ProjectRole? role = invite.role;
    final message = inviteMessage(
      code: invite.code,
      from: from,
      project: projectName,
      role: role,
    );
    final link = inviteLink(
      code: invite.code,
      from: from,
      project: projectName,
      role: role,
    ).toString();
    final subject = projectName == null
        ? 'Invitación a IRIS'
        : 'Invitación a «$projectName» en IRIS';
    final who = invite.email == null
        ? (invite.maxUses == 1
              ? 'Vale para una persona.'
              : 'Vale para ${invite.maxUses} personas.')
        : 'Solo para ${invite.email}: entrará sola al crear su cuenta con '
              'ese correo.';
    final days = invite.expiresAt.difference(DateTime.now()).inDays + 1;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Invitación lista', style: AppTypography.titleMedium(palette)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '$who El enlace caduca en $days días si nadie lo usa.'
              '${invite.grantsAccess ? '' : ' Si la persona aún no usa IRIS, tendrás que pedir al administrador que apruebe su cuenta.'}',
              style: AppTypography.caption(palette),
            ),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: SelectableText(
                formatInviteCode(invite.code),
                style: AppTypography.mono(
                  palette,
                ).copyWith(fontSize: 28, letterSpacing: 2),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            SelectableText(
              link,
              textAlign: TextAlign.center,
              style: AppTypography.caption(palette),
            ),
            const SizedBox(height: AppSpacing.lg),
            Builder(
              builder: (buttonContext) => FilledButton.icon(
                icon: const Icon(Icons.ios_share),
                label: const Text('Compartir…'),
                onPressed: () {
                  final box = buttonContext.findRenderObject() as RenderBox?;
                  Share.share(
                    message,
                    subject: subject,
                    sharePositionOrigin: box == null
                        ? null
                        : box.localToGlobal(Offset.zero) & box.size,
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.mail_outline),
                    label: const Text('Correo'),
                    onPressed: () => launchUrl(
                      Uri(
                        scheme: 'mailto',
                        path: invite.email ?? '',
                        query: _mailQuery(subject, message),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy),
                    label: const Text('Copiar'),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: message));
                      if (context.mounted) {
                        AppSnackBar.show(context, 'Invitación copiada');
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// mailto no admite «+» por espacio: se codifica a mano.
  static String _mailQuery(String subject, String body) =>
      'subject=${Uri.encodeComponent(subject)}'
      '&body=${Uri.encodeComponent(body)}';
}
