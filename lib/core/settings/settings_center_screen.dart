import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_prefs.dart';
import 'settings_section.dart';

/// Centro de ajustes: lateral de secciones y el detalle de la elegida.
/// Por debajo de [_splitWidth] pasa a lista → detalle.
///
/// Si se abre desde un proyecto ([projectId]), arriba se elige si los
/// cambios valen para toda la app o solo para ese proyecto.
class SettingsCenterScreen extends ConsumerStatefulWidget {
  final List<SettingsSectionSpec> sections;
  final String? initialSectionId;
  final int? projectId;
  final String? projectName;

  const SettingsCenterScreen({
    super.key,
    required this.sections,
    this.initialSectionId,
    this.projectId,
    this.projectName,
  });

  @override
  ConsumerState<SettingsCenterScreen> createState() =>
      _SettingsCenterScreenState();
}

const double _splitWidth = 720;

class _SettingsCenterScreenState extends ConsumerState<SettingsCenterScreen> {
  late String _selectedId;
  late SettingsScope _scope;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialSectionId ?? widget.sections.first.id;
    _scope = widget.projectId == null
        ? const SettingsScope.global()
        : SettingsScope.project(widget.projectId!);
  }

  SettingsSectionSpec get _selected => widget.sections.firstWhere(
    (s) => s.id == _selectedId,
    orElse: () => widget.sections.first,
  );

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.surface,
        title: Text('Ajustes', style: AppTypography.titleMedium(palette)),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < _splitWidth) {
            return _sidebar(
              onTap: (s) => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    backgroundColor: palette.background,
                    appBar: AppBar(
                      backgroundColor: palette.surface,
                      title: Text(
                        s.title,
                        style: AppTypography.titleMedium(palette),
                      ),
                    ),
                    body: _SectionDetail(
                      spec: s,
                      initialScope: _scope,
                      projectId: widget.projectId,
                      projectName: widget.projectName,
                      onScopeChanged: (scope) => _scope = scope,
                      showTitle: false,
                    ),
                  ),
                ),
              ),
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 260,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.surface,
                    border: Border(right: BorderSide(color: palette.border)),
                  ),
                  child: _sidebar(
                    onTap: (s) => setState(() => _selectedId = s.id),
                  ),
                ),
              ),
              Expanded(
                child: _SectionDetail(
                  key: ValueKey(_selectedId),
                  spec: _selected,
                  initialScope: _scope,
                  projectId: widget.projectId,
                  projectName: widget.projectName,
                  onScopeChanged: (scope) => setState(() => _scope = scope),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sidebar({required ValueChanged<SettingsSectionSpec> onTap}) {
    final palette = context.palette;
    final prefs = ref.watch(appPrefsProvider);
    final visible = widget.sections.where((s) => s.matches(_query)).toList();
    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, AppSpacing.sm),
        child: TextField(
          onChanged: (v) => setState(() => _query = v),
          style: AppTypography.bodyMedium(palette),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Buscar ajuste',
            prefixIcon: const Icon(Icons.search, size: 18),
            filled: true,
            fillColor: palette.surfaceElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    ];
    for (final group in SettingsGroup.values) {
      final items = visible.where((s) => s.group == group).toList();
      if (items.isEmpty) continue;
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(12, AppSpacing.md, 12, 6),
          child: Text(
            group.label.toUpperCase(),
            style: AppTypography.caption(
              palette,
            ).copyWith(letterSpacing: 0.8, color: palette.textTertiary),
          ),
        ),
      );
      for (final s in items) {
        final pid = widget.projectId;
        final overrides = pid == null || !s.scoped
            ? 0
            : prefs.overrideCount(s.prefKeys, pid);
        children.add(
          _SidebarTile(
            spec: s,
            selected: s.id == _selectedId,
            overrides: overrides,
            onTap: () => onTap(s),
          ),
        );
      }
    }
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      children: children,
    );
  }
}

class _SidebarTile extends StatelessWidget {
  final SettingsSectionSpec spec;
  final bool selected;
  final int overrides;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.spec,
    required this.selected,
    required this.overrides,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: selected ? palette.accentMuted : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              children: [
                SettingsSectionIcon(spec: spec),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    spec.title,
                    style: AppTypography.bodyMedium(palette),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (overrides > 0)
                  Tooltip(
                    message: overrides == 1
                        ? '1 ajuste cambiado en este proyecto'
                        : '$overrides ajustes cambiados en este proyecto',
                    child: Text(
                      '$overrides',
                      style: AppTypography.caption(
                        palette,
                      ).copyWith(color: palette.warning),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Icono de color de una sección.
class SettingsSectionIcon extends StatelessWidget {
  final SettingsSectionSpec spec;
  final double size;

  const SettingsSectionIcon({super.key, required this.spec, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: spec.color,
        borderRadius: BorderRadius.circular(size / 4),
      ),
      child: Icon(spec.icon, size: size * 0.6, color: Colors.white),
    );
  }
}

/// Selector «Toda la app / Este proyecto».
class SettingsScopeSwitch extends StatelessWidget {
  final SettingsScope scope;
  final int projectId;
  final ValueChanged<SettingsScope> onChanged;

  const SettingsScopeSwitch({
    super.key,
    required this.scope,
    required this.projectId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<bool>(
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: const [
        ButtonSegment(value: true, label: Text('Este proyecto')),
        ButtonSegment(value: false, label: Text('Toda la app')),
      ],
      selected: {scope.isProject},
      onSelectionChanged: (s) => onChanged(
        s.first
            ? SettingsScope.project(projectId)
            : const SettingsScope.global(),
      ),
    );
  }
}

class _SectionDetail extends StatefulWidget {
  final SettingsSectionSpec spec;
  final SettingsScope initialScope;
  final int? projectId;
  final String? projectName;
  final ValueChanged<SettingsScope> onScopeChanged;
  final bool showTitle;

  const _SectionDetail({
    super.key,
    required this.spec,
    required this.initialScope,
    required this.onScopeChanged,
    this.projectId,
    this.projectName,
    this.showTitle = true,
  });

  @override
  State<_SectionDetail> createState() => _SectionDetailState();
}

class _SectionDetailState extends State<_SectionDetail> {
  late SettingsScope _scope = widget.initialScope;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spec = widget.spec;
    final pid = widget.projectId;
    final scope = spec.scoped ? _scope : const SettingsScope.global();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (spec.scoped && pid != null)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.sm + 2,
            ),
            decoration: BoxDecoration(
              color: palette.surface,
              border: Border(bottom: BorderSide(color: palette.border)),
            ),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: [
                Text('Cambiar para', style: AppTypography.caption(palette)),
                SettingsScopeSwitch(
                  scope: _scope,
                  projectId: pid,
                  onChanged: (s) {
                    setState(() => _scope = s);
                    widget.onScopeChanged(s);
                  },
                ),
                if (widget.projectName != null)
                  Text(
                    widget.projectName!,
                    style: AppTypography.label(palette),
                  ),
              ],
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.xxl,
            ),
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.showTitle) ...[
                        Text(
                          spec.title,
                          style: AppTypography.titleLarge(palette),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                      if (spec.description != null) ...[
                        Text(
                          spec.description!,
                          style: AppTypography.caption(palette),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      spec.builder(context, scope),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Panel lateral con una sola sección: lo que abre el engranaje de cada
/// pantalla. Deja la pantalla a la vista para ver los cambios al momento.
Future<void> showScreenSettingsPanel(
  BuildContext context, {
  required SettingsSectionSpec spec,
  int? projectId,
  VoidCallback? onOpenAll,
}) {
  final wide = MediaQuery.sizeOf(context).width >= 600;
  final panel = _ScreenSettingsPanel(
    spec: spec,
    projectId: projectId,
    onOpenAll: onOpenAll,
  );
  if (!wide) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.surface,
      builder: (_) => FractionallySizedBox(heightFactor: 0.85, child: panel),
    );
  }
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar ajustes',
    barrierColor: Colors.black.withValues(alpha: 0.12),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, _, _) => Align(
      alignment: Alignment.centerRight,
      child: SizedBox(width: 360, child: panel),
    ),
    transitionBuilder: (_, animation, _, child) => SlideTransition(
      position: Tween(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}

class _ScreenSettingsPanel extends StatefulWidget {
  final SettingsSectionSpec spec;
  final int? projectId;
  final VoidCallback? onOpenAll;

  const _ScreenSettingsPanel({
    required this.spec,
    required this.projectId,
    required this.onOpenAll,
  });

  @override
  State<_ScreenSettingsPanel> createState() => _ScreenSettingsPanelState();
}

class _ScreenSettingsPanelState extends State<_ScreenSettingsPanel> {
  late SettingsScope _scope = widget.projectId == null
      ? const SettingsScope.global()
      : SettingsScope.project(widget.projectId!);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spec = widget.spec;
    return Material(
      color: palette.surface,
      child: SafeArea(
        left: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: palette.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    SettingsSectionIcon(spec: spec, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Ajustes · ${spec.title}',
                        style: AppTypography.titleMedium(palette),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              if (spec.scoped && widget.projectId != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SettingsScopeSwitch(
                      scope: _scope,
                      projectId: widget.projectId!,
                      onChanged: (s) => setState(() => _scope = s),
                    ),
                  ),
                ),
              Divider(height: 1, color: palette.border),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    spec.builder(
                      context,
                      spec.scoped ? _scope : const SettingsScope.global(),
                    ),
                  ],
                ),
              ),
              if (widget.onOpenAll != null) ...[
                Divider(height: 1, color: palette.border),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: widget.onOpenAll,
                      icon: const Icon(Icons.tune, size: 18),
                      label: const Text('Abrir todos los ajustes'),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
