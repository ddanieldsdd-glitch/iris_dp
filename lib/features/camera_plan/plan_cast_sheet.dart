import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/project_cast_settings.dart';
import '../../core/utils/scene_color.dart';
import '../../core/widgets/scene_color_picker.dart';
import 'plan_cast.dart';

/// Gestiona el reparto del proyecto: colores, ocultos, quitados y grupos.
/// Cada cambio se guarda al momento y [onRecolour] avisa a la planta abierta.
Future<void> showPlanCastSheet(
  BuildContext context, {
  required int projectId,
  required Future<void> Function(String name, Color color) onRecolour,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: context.palette.surfaceElevated,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: PlanCastPanel(projectId: projectId, onRecolour: onRecolour),
      ),
    ),
  );
}

class PlanCastPanel extends ConsumerStatefulWidget {
  final int projectId;
  final Future<void> Function(String name, Color color) onRecolour;

  const PlanCastPanel({
    super.key,
    required this.projectId,
    required this.onRecolour,
  });

  @override
  ConsumerState<PlanCastPanel> createState() => _PlanCastPanelState();
}

class _PlanCastPanelState extends ConsumerState<PlanCastPanel> {
  CastRoster? _roster;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final roster = await PlanCast.roster(
      ref.read(databaseProvider),
      widget.projectId,
    );
    if (mounted) setState(() => _roster = roster);
  }

  Future<void> _save(ProjectCastSettings settings) async {
    await PlanCast.saveSettings(
      ref.read(databaseProvider),
      widget.projectId,
      settings,
    );
    await _reload();
  }

  Future<void> _recolour(CastMember member) async {
    final palette = context.palette;
    var hex = hexFromColor(member.color);
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Color de ${member.name}'),
        content: StatefulBuilder(
          builder: (ctx, setInner) => SceneColorPicker(
            selectedHex: hex,
            palette: palette,
            onChanged: (v) => setInner(() => hex = v),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, hex),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    final color = colorFromHex(picked);
    if (color == null) return;
    await widget.onRecolour(member.name, color);
    await _reload();
  }

  Future<String?> _askName({String? initial, required String title}) {
    final ctrl = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Figuración, familia…'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _newGroup(ProjectCastSettings settings) async {
    final name = (await _askName(title: 'Grupo nuevo'))?.trim();
    if (name == null || name.isEmpty) return;
    final group = CastGroup(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      name: name,
    );
    await _save(settings.copyWith(groups: [...settings.groups, group]));
  }

  Future<void> _renameGroup(
    ProjectCastSettings settings,
    CastGroup group,
  ) async {
    final name = (await _askName(
      title: 'Nombre del grupo',
      initial: group.name,
    ))?.trim();
    if (name == null || name.isEmpty) return;
    await _save(
      settings.copyWith(
        groups: [
          for (final g in settings.groups)
            if (g.id == group.id) g.copyWith(name: name) else g,
        ],
      ),
    );
  }

  Future<void> _remove(CastMember member, ProjectCastSettings settings) async {
    await _save(settings.withRemoved(member.key));
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          member.inPlans
              ? '${member.name} sale del reparto. Sigue en las plantas donde '
                    'ya estaba.'
              : '${member.name} sale del reparto.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final roster = _roster;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Reparto', style: AppTypography.titleMedium(palette)),
              ),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          if (roster == null)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Flexible(child: _list(roster)),
        ],
      ),
    );
  }

  Widget _list(CastRoster roster) {
    final palette = context.palette;
    final settings = roster.settings;
    Widget title(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(0, AppSpacing.md, 0, 4),
      child: Text(
        text,
        style: AppTypography.caption(
          palette,
        ).copyWith(color: palette.accent, letterSpacing: 1.2),
      ),
    );
    final shown = roster.visible;
    final hidden = [
      for (final m in roster.members)
        if (m.hidden) m,
    ];
    return ListView(
      shrinkWrap: true,
      children: [
        title('GRUPOS'),
        for (final group in settings.groups)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.group_outlined, size: 18),
            title: Text(group.name),
            subtitle: Text(
              roster.membersOf(group).map((m) => m.name).join(', '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Cambiar nombre',
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: () => _renameGroup(settings, group),
                ),
                IconButton(
                  tooltip: 'Borrar el grupo',
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () => _save(
                    settings.copyWith(
                      groups: [
                        for (final g in settings.groups)
                          if (g.id != group.id) g,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _newGroup(settings),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Grupo nuevo'),
          ),
        ),
        title('SUJETOS'),
        if (shown.isEmpty)
          Text(
            'Aún no hay sujetos. Aparecen al ponerlos en una planta o al '
            'importar el guion.',
            style: AppTypography.caption(palette),
          ),
        for (final m in shown) _row(m, settings),
        if (hidden.isNotEmpty) ...[
          title('OCULTOS'),
          for (final m in hidden) _row(m, settings),
        ],
        if (roster.removedNames.isNotEmpty) ...[
          title('QUITADOS'),
          for (final entry in roster.removedNames.entries)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(entry.value),
              trailing: TextButton(
                onPressed: () => _save(settings.withRestored(entry.key)),
                child: const Text('Recuperar'),
              ),
            ),
        ],
      ],
    );
  }

  Widget _row(CastMember member, ProjectCastSettings settings) {
    final palette = context.palette;
    final source = [
      if (member.inPlans) 'En plantas',
      if (member.fromScript)
        'Guion: ${member.scriptScenes} '
            '${member.scriptScenes == 1 ? 'escena' : 'escenas'}',
    ].join(' · ');
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _recolour(member),
        child: Tooltip(
          message: 'Cambiar color',
          child: CircleAvatar(backgroundColor: member.color, radius: 9),
        ),
      ),
      title: Text(member.name),
      subtitle: Text(source, style: AppTypography.caption(palette)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (settings.groups.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: 'Grupos',
              icon: const Icon(Icons.group_add_outlined, size: 18),
              onSelected: (id) {
                final group = settings.groups.firstWhere((g) => g.id == id);
                _save(
                  settings.withMember(
                    id,
                    member.key,
                    !group.members.contains(member.key),
                  ),
                );
              },
              itemBuilder: (_) => [
                for (final g in settings.groups)
                  CheckedPopupMenuItem(
                    value: g.id,
                    checked: g.members.contains(member.key),
                    child: Text(g.name),
                  ),
              ],
            ),
          IconButton(
            tooltip: member.hidden ? 'Enseñar' : 'Ocultar',
            icon: Icon(
              member.hidden
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 18,
            ),
            onPressed: () =>
                _save(settings.withHidden(member.key, !member.hidden)),
          ),
          IconButton(
            tooltip: 'Quitar del reparto',
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => _remove(member, settings),
          ),
        ],
      ),
    );
  }
}
