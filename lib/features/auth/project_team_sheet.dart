import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      if (mounted) {
        setState(() {
          _team = team;
          _loadError = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadError = 'No se pudo cargar el equipo');
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

  Future<void> _invite() async {
    final email = _emailCtrl.text.trim();
    if (!email.contains('@')) {
      AppSnackBar.showError(context, 'Escribe un correo válido');
      return;
    }
    await _run(
      (s) => s.invite(
        projectCloudId: widget.projectCloudId,
        email: email,
        role: _role,
      ),
      done: 'Invitación guardada: entrará al abrir IRIS con ese correo',
    );
    if (mounted) _emailCtrl.clear();
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
    await _run((s) => s.remove(widget.projectCloudId, entry));
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
            const Divider(height: AppSpacing.xl),
            Text('Invitar', style: AppTypography.label(palette)),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Correo',
                hintText: 'nombre@estudio.com',
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
              label: Text(_busy ? 'Guardando…' : 'Invitar'),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Todos los papeles editan todo salvo «Solo consulta». '
              'La persona entra en cuanto abre IRIS con ese correo y su cuenta '
              'está aprobada.',
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
