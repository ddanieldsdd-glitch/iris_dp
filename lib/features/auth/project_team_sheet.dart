import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/access/app_invite.dart';
import '../../core/access/app_invite_service.dart';
import '../../core/access/invite_share_sheet.dart';
import '../../core/cloud/cloud_providers.dart';
import '../../core/cloud/project_role.dart';
import '../../core/sync/project_sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_snackbar.dart';

/// Equipo de un proyecto compartido: quién está, con qué papel, a quién se
/// ha invitado, e invitar a alguien nuevo (solo el dueño del proyecto).
class ProjectTeamSheet extends ConsumerStatefulWidget {
  const ProjectTeamSheet({
    super.key,
    required this.projectCloudId,
    required this.projectName,
  });

  final String projectCloudId;
  final String projectName;

  static Future<void> show(
    BuildContext context, {
    required String projectCloudId,
    required String projectName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.surfaceElevated,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: ProjectTeamSheet(
          projectCloudId: projectCloudId,
          projectName: projectName,
        ),
      ),
    );
  }

  @override
  ConsumerState<ProjectTeamSheet> createState() => _ProjectTeamSheetState();
}

class _ProjectTeamSheetState extends ConsumerState<ProjectTeamSheet> {
  final _emailCtrl = TextEditingController();
  var _role = ProjectRole.director;
  var _busy = false;
  List<ProjectTeamEntry>? _team;
  List<AppInvite> _links = const [];
  String? _loadError;

  ProjectInviteService? get _service {
    final client = ref.read(supabaseClientProvider);
    return client == null ? null : ProjectInviteService(client);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final service = _service;
    if (service == null) return;
    try {
      final team = await service.team(widget.projectCloudId);
      final links = await _openLinks();
      if (mounted) {
        setState(() {
          _team = team;
          _links = links;
          _loadError = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadError = 'No se pudo cargar el equipo');
    }
  }

  AppInviteService? get _invites {
    final client = ref.read(supabaseClientProvider);
    return client == null ? null : AppInviteService(client);
  }

  /// Enlaces abiertos de este proyecto (sin la 020, ninguno).
  Future<List<AppInvite>> _openLinks() async {
    try {
      final now = DateTime.now();
      final all = await _invites?.list(projectCloudId: widget.projectCloudId);
      return [
        for (final i in all ?? const <AppInvite>[])
          if (i.isOpen(now)) i,
      ];
    } on InviteLinksUnavailable {
      return const [];
    }
  }

  Future<void> _run(
    Future<void> Function(ProjectInviteService s) op, {
    String? done,
  }) async {
    final service = _service;
    if (service == null) return;
    setState(() => _busy = true);
    try {
      await op(service);
      if (mounted && done != null) AppSnackBar.show(context, done);
      await _load();
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Crea el enlace (con correo, solo para esa persona) y lo comparte. Sin
  /// la 020 en la nube, solo por correo y como antes.
  Future<void> _invite() async {
    final email = _emailCtrl.text.trim();
    if (email.isNotEmpty && !email.contains('@')) {
      AppSnackBar.showError(context, 'Escribe un correo válido');
      return;
    }
    final invites = _invites;
    if (invites == null) return;
    setState(() => _busy = true);
    AppInvite? created;
    try {
      created = await invites.create(
        projectCloudId: widget.projectCloudId,
        role: _role,
        email: email.isEmpty ? null : email,
      );
    } on InviteLinksUnavailable {
      if (email.isEmpty) {
        if (mounted) {
          AppSnackBar.showError(
            context,
            'Para crear enlaces falta la migración 020 en Supabase. '
            'De momento, invita escribiendo el correo.',
          );
        }
      } else {
        try {
          await _service?.invite(
            projectCloudId: widget.projectCloudId,
            email: email,
            role: _role,
          );
          if (mounted) {
            AppSnackBar.show(
              context,
              'Invitación guardada: entrará al abrir IRIS con ese correo',
            );
          }
        } catch (e) {
          if (mounted) AppSnackBar.showError(context, inviteErrorText(e));
        }
      }
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, inviteErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _load();
    if (!mounted) return;
    _emailCtrl.clear();
    if (created != null) {
      await InviteShareSheet.show(
        context,
        invite: created,
        projectName: widget.projectName,
      );
    }
  }

  Future<void> _revokeLink(AppInvite link) =>
      _run((_) async => _invites?.revoke(link.id));

  /// Retirar a alguien invitado por correo retira también su enlace.
  Future<void> _revokeLinksOf(String email) async {
    final now = DateTime.now();
    for (final link in _links) {
      if (link.isOpen(now) && link.email == email.toLowerCase()) {
        await _invites?.revoke(link.id);
      }
    }
  }

  Future<void> _remove(ProjectTeamEntry entry) async {
    final who = entry.name ?? entry.email ?? 'esta persona';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          entry.pending ? 'Retirar invitación' : 'Quitar del proyecto',
        ),
        content: Text(
          entry.pending
              ? '$who ya no podrá entrar con esta invitación.'
              : '$who deja de recibir y subir cambios de este proyecto. '
                    'Lo que ya tiene en su equipo no se borra.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(entry.pending ? 'Retirar' : 'Quitar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run((s) async {
      await s.remove(widget.projectCloudId, entry);
      if (entry.pending && entry.email != null) {
        await _revokeLinksOf(entry.email!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final team = _team;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Equipo del proyecto',
              style: AppTypography.titleMedium(palette),
            ),
            Text(widget.projectName, style: AppTypography.caption(palette)),
            const SizedBox(height: AppSpacing.md),
            if (_loadError != null)
              Text(_loadError!, style: AppTypography.caption(palette))
            else if (team == null)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (team.isEmpty)
              Text(
                'Aún no hay nadie más en este proyecto.',
                style: AppTypography.caption(palette),
              )
            else
              for (final entry in team)
                _TeamRow(
                  key: ValueKey(entry.userId ?? entry.invitationId),
                  entry: entry,
                  enabled: !_busy,
                  onRole: (r) =>
                      _run((s) => s.setRole(widget.projectCloudId, entry, r)),
                  onRemove: () => _remove(entry),
                ),
            for (final link in _links.where((l) => l.email == null))
              _LinkRow(
                key: ValueKey(link.id),
                link: link,
                enabled: !_busy,
                onShare: () => InviteShareSheet.show(
                  context,
                  invite: link,
                  projectName: widget.projectName,
                ),
                onRevoke: () => _revokeLink(link),
              ),
            const Divider(height: AppSpacing.xl),
            Text('Invitar', style: AppTypography.label(palette)),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Correo (opcional)',
                hintText: 'nombre@estudio.com',
                helperText:
                    'Con correo, solo esa persona puede usar la invitación. '
                    'Sin correo, sirve para quien reciba el enlace.',
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _RolePicker(
              value: _role,
              onChanged: _busy ? null : (r) => setState(() => _role = r),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: _busy ? null : _invite,
              icon: const Icon(Icons.person_add_outlined),
              label: Text(_busy ? 'Creando…' : 'Crear invitación'),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Todos los papeles editan todo salvo «Solo consulta». Después '
              'podrás mandarla por Correo, WhatsApp o Mensajes: el enlace lleva '
              'a la descarga de IRIS para su ordenador.',
              style: AppTypography.caption(palette),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamRow extends StatelessWidget {
  const _TeamRow({
    super.key,
    required this.entry,
    required this.enabled,
    required this.onRole,
    required this.onRemove,
  });

  final ProjectTeamEntry entry;
  final bool enabled;
  final ValueChanged<ProjectRole> onRole;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final title = entry.name ?? entry.email ?? 'Sin nombre';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(
            entry.pending ? Icons.mail_outline : Icons.person_outline,
            size: 20,
            color: palette.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyMedium(palette),
                  overflow: TextOverflow.ellipsis,
                ),
                if (entry.pending)
                  Text(
                    'Invitación pendiente',
                    style: AppTypography.caption(palette),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: _RolePicker(
              value: entry.role,
              dense: true,
              onChanged: enabled ? onRole : null,
            ),
          ),
          IconButton(
            tooltip: entry.pending ? 'Retirar invitación' : 'Quitar',
            icon: const Icon(Icons.close),
            onPressed: enabled ? onRemove : null,
          ),
        ],
      ),
    );
  }
}

class _RolePicker extends StatelessWidget {
  const _RolePicker({
    required this.value,
    required this.onChanged,
    this.dense = false,
  });

  final ProjectRole? value;
  final ValueChanged<ProjectRole>? onChanged;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DropdownButtonFormField<ProjectRole>(
      initialValue: value,
      isExpanded: true,
      isDense: dense,
      decoration: InputDecoration(
        labelText: dense ? null : 'Papel',
        isDense: dense,
      ),
      items: [
        for (final r in ProjectRole.values)
          DropdownMenuItem(
            value: r,
            child: Text(
              r.label,
              style: AppTypography.bodyMedium(palette),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged == null
          ? null
          : (r) {
              if (r != null && r != value) onChanged!(r);
            },
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    super.key,
    required this.link,
    required this.enabled,
    required this.onShare,
    required this.onRevoke,
  });

  final AppInvite link;
  final bool enabled;
  final VoidCallback onShare;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(Icons.link, size: 20, color: palette.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enlace · ${link.role?.label ?? ''}',
                  style: AppTypography.bodyMedium(palette),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${formatInviteCode(link.code)} · ${link.uses}/${link.maxUses} usos',
                  style: AppTypography.caption(palette),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Compartir otra vez',
            icon: const Icon(Icons.ios_share),
            onPressed: enabled ? onShare : null,
          ),
          IconButton(
            tooltip: 'Retirar enlace',
            icon: const Icon(Icons.close),
            onPressed: enabled ? onRevoke : null,
          ),
        ],
      ),
    );
  }
}
