import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/cloud_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_snackbar.dart';
import 'app_invite.dart';
import 'app_invite_service.dart';
import 'invite_share_sheet.dart';

final _appInvitesProvider = FutureProvider.autoDispose<List<AppInvite>>((
  ref,
) async {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return const [];
  return AppInviteService(client).list(appOnly: true);
});

/// Ajustes → Invitados (administrador): enlaces para que alguien entre a
/// IRIS sin esperar aprobación, gratis y sin fecha («probador»).
class AdminInvitesSection extends ConsumerWidget {
  const AdminInvitesSection({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final client = ref.read(supabaseClientProvider);
    if (client == null) return;
    final form = await showDialog<_InviteForm>(
      context: context,
      builder: (_) => const _NewInviteDialog(),
    );
    if (form == null || !context.mounted) return;
    try {
      final invite = await AppInviteService(
        client,
      ).create(email: form.email, maxUses: form.maxUses, note: form.note);
      ref.invalidate(_appInvitesProvider);
      if (context.mounted) await InviteShareSheet.show(context, invite: invite);
    } on InviteLinksUnavailable catch (e) {
      if (context.mounted) AppSnackBar.showError(context, e.toString());
    } catch (e) {
      if (context.mounted) AppSnackBar.showError(context, inviteErrorText(e));
    }
  }

  Future<void> _revoke(
    BuildContext context,
    WidgetRef ref,
    AppInvite invite,
  ) async {
    final client = ref.read(supabaseClientProvider);
    if (client == null) return;
    try {
      await AppInviteService(client).revoke(invite.id);
      ref.invalidate(_appInvitesProvider);
    } catch (e) {
      if (context.mounted) AppSnackBar.showError(context, inviteErrorText(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final invites = ref.watch(_appInvitesProvider);
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Invitaciones a IRIS',
                style: AppTypography.titleMedium(palette),
              ),
            ),
            FilledButton.icon(
              onPressed: () => _create(context, ref),
              icon: const Icon(Icons.link, size: 18),
              label: const Text('Crear enlace'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Quien use el enlace entra sin esperar tu aprobación, gratis y sin '
          'fecha de fin. Para invitar a un proyecto concreto, usa «Equipo del '
          'proyecto» en la ficha del proyecto.',
          style: AppTypography.caption(palette),
        ),
        const SizedBox(height: AppSpacing.sm),
        invites.when(
          loading: () =>
              Text('Cargando…', style: AppTypography.caption(palette)),
          error: (e, _) => Text(
            e is InviteLinksUnavailable
                ? e.toString()
                : 'No se pudieron leer las invitaciones.',
            style: AppTypography.caption(palette),
          ),
          data: (list) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (list.isEmpty)
                Text(
                  'Aún no has creado ninguna.',
                  style: AppTypography.caption(palette),
                ),
              for (final i in list.take(30))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(
                    i.isOpen(now) ? Icons.link : Icons.link_off,
                    color: i.isOpen(now)
                        ? palette.accent
                        : palette.textSecondary,
                  ),
                  title: Text(
                    i.email ?? i.note ?? formatInviteCode(i.code),
                    style: AppTypography.bodyMedium(palette),
                  ),
                  subtitle: Text(
                    '${formatInviteCode(i.code)} · ${i.uses}/${i.maxUses} '
                    'usos · ${_state(i, now)}',
                    style: AppTypography.caption(palette),
                  ),
                  trailing: i.isOpen(now)
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Compartir otra vez',
                              icon: const Icon(Icons.ios_share, size: 18),
                              onPressed: () =>
                                  InviteShareSheet.show(context, invite: i),
                            ),
                            IconButton(
                              tooltip: 'Retirar',
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => _revoke(context, ref, i),
                            ),
                          ],
                        )
                      : null,
                ),
            ],
          ),
        ),
      ],
    );
  }

  static String _state(AppInvite i, DateTime now) {
    if (i.revokedAt != null) return 'retirada';
    if (i.uses >= i.maxUses) return 'usada';
    if (!i.expiresAt.isAfter(now)) return 'caducada';
    final days = i.expiresAt.difference(now).inDays + 1;
    return 'caduca en $days días';
  }
}

class _InviteForm {
  const _InviteForm({this.email, this.maxUses = 1, this.note});
  final String? email;
  final int maxUses;
  final String? note;
}

class _NewInviteDialog extends StatefulWidget {
  const _NewInviteDialog();

  @override
  State<_NewInviteDialog> createState() => _NewInviteDialogState();
}

class _NewInviteDialogState extends State<_NewInviteDialog> {
  final _email = TextEditingController();
  final _note = TextEditingController();
  var _uses = 1;

  @override
  void dispose() {
    _email.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasEmail = _email.text.trim().isNotEmpty;
    return AlertDialog(
      title: const Text('Nuevo enlace'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Correo (opcional)',
                helperText: 'Con correo, solo esa persona puede usarlo.',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<int>(
              initialValue: _uses,
              decoration: const InputDecoration(labelText: 'Para'),
              items: const [
                DropdownMenuItem(value: 1, child: Text('1 persona')),
                DropdownMenuItem(value: 5, child: Text('Hasta 5 personas')),
                DropdownMenuItem(value: 20, child: Text('Hasta 20 personas')),
              ],
              onChanged: hasEmail
                  ? null
                  : (v) => setState(() => _uses = v ?? 1),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Nota para ti (opcional)',
                hintText: 'Amigos del corto, equipo de cámara…',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final email = _email.text.trim();
            if (email.isNotEmpty && !email.contains('@')) return;
            Navigator.pop(
              context,
              _InviteForm(
                email: email.isEmpty ? null : email,
                maxUses: email.isEmpty ? _uses : 1,
                note: _note.text.trim().isEmpty ? null : _note.text.trim(),
              ),
            );
          },
          child: const Text('Crear'),
        ),
      ],
    );
  }
}
