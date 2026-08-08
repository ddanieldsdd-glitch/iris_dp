import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/visual_bible/bible_section_ids.dart';
import 'bible_quick_adjust_panel.dart';
import 'bible_section_fields_editor.dart';
import 'bible_section_references_manager.dart';
import 'bible_structure_editor.dart';

enum BibleLivePanelTab { widgets, references, style, structure }

/// Panel derecho desplegable con edición en vivo mientras se ve la biblia.
class BibleLiveCustomizePanel extends ConsumerStatefulWidget {
  final int bibleId;
  final int projectId;
  final String sectionId;
  final double width;
  final BibleLivePanelTab initialTab;
  final VoidCallback onClose;
  final VoidCallback onOpenMasterConfig;
  final ValueChanged<double>? onWidthChanged;

  const BibleLiveCustomizePanel({
    super.key,
    required this.bibleId,
    required this.projectId,
    required this.sectionId,
    required this.width,
    required this.onClose,
    required this.onOpenMasterConfig,
    this.initialTab = BibleLivePanelTab.style,
    this.onWidthChanged,
  });

  static String widthKey(int projectId) => 'iris_bible_live_panel_width_$projectId';
  static String openKey(int projectId) => 'iris_bible_live_panel_open_$projectId';

  static Future<double> loadWidth(int projectId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(widthKey(projectId)) ?? 320;
  }

  static Future<void> saveWidth(int projectId, double width) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(widthKey(projectId), width);
  }

  static Future<bool> loadOpen(int projectId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(openKey(projectId)) ?? false;
  }

  static Future<void> saveOpen(int projectId, bool open) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(openKey(projectId), open);
  }

  @override
  ConsumerState<BibleLiveCustomizePanel> createState() =>
      _BibleLiveCustomizePanelState();
}

class _BibleLiveCustomizePanelState extends ConsumerState<BibleLiveCustomizePanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late BibleLivePanelTab _currentTab;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
    _tabs = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.index,
    );
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) {
        setState(() => _currentTab = BibleLivePanelTab.values[_tabs.index]);
      }
    });
  }

  @override
  void didUpdateWidget(BibleLiveCustomizePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab &&
        widget.initialTab.index != _tabs.index) {
      _tabs.animateTo(widget.initialTab.index);
      _currentTab = widget.initialTab;
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  bool get _isMoodboard => widget.sectionId == BibleSectionId.moodboard;
  bool get _isSettings => widget.sectionId == BibleSectionId.settings;
  bool get _isOverview => widget.sectionId == BibleSidebarOverviewId.overview;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return Material(
      color: palette.surfaceElevated,
      child: Container(
      width: widget.width,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: palette.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 0),
            child: Row(
              children: [
                Icon(Icons.tune, color: palette.accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ajustes de pantalla',
                        style: AppTypography.titleMedium(palette).copyWith(fontSize: 15),
                      ),
                      Text(
                        BibleSectionId.label(widget.sectionId),
                        style: AppTypography.caption(palette).copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar panel',
                  onPressed: widget.onClose,
                  icon: Icon(Icons.chevron_right, color: palette.textSecondary),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle: AppTypography.caption(palette).copyWith(fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Widgets'),
              Tab(text: 'Refs'),
              Tab(text: 'Densidad'),
              Tab(text: 'Estructura'),
            ],
          ),
          Divider(height: 1, color: palette.border),
          Expanded(
            child: StreamBuilder<List<BibleSectionDefinition>>(
              stream: widget.bibleId > 0
                  ? db.watchBibleSectionDefinitions(widget.bibleId)
                  : Stream.value(const []),
              builder: (context, snap) {
                final defs = snap.data ?? const <BibleSectionDefinition>[];
                final def = defs.where((d) => d.id == widget.sectionId).firstOrNull;

                return TabBarView(
                  controller: _tabs,
                  children: [
                    _WidgetsTab(
                      bibleId: widget.bibleId,
                      definition: def,
                      sectionId: widget.sectionId,
                      disabled: _isMoodboard || _isSettings || _isOverview,
                    ),
                    _ReferencesTab(
                      projectId: widget.projectId,
                      bibleId: widget.bibleId,
                      sectionId: widget.sectionId,
                      disabled: _isMoodboard || _isSettings || _isOverview,
                    ),
                    _StyleTab(
                      bibleId: widget.bibleId,
                      projectId: widget.projectId,
                      sectionId: widget.sectionId,
                      onOpenMasterConfig: widget.onOpenMasterConfig,
                    ),
                    _StructureTab(
                      bibleId: widget.bibleId,
                      projectId: widget.projectId,
                      onOpenMasterConfig: widget.onOpenMasterConfig,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
    );
  }
}

/// ID usado internamente para overview — evita import circular con sidebar.
abstract final class BibleSidebarOverviewId {
  static const overview = '__overview__';
}

class _WidgetsTab extends StatelessWidget {
  final int bibleId;
  final BibleSectionDefinition? definition;
  final String sectionId;
  final bool disabled;

  const _WidgetsTab({
    required this.bibleId,
    this.definition,
    required this.sectionId,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    if (disabled || definition == null || bibleId <= 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            disabled
                ? 'Selecciona una pantalla de contenido para editar sus sub-apartados.'
                : 'Selecciona una pantalla de contenido para editar sus sub-apartados.',
            textAlign: TextAlign.center,
            style: AppTypography.caption(context.palette),
          ),
        ),
      );
    }
    return BibleSectionFieldsEditor(
      key: ValueKey(definition!.id),
      bibleId: bibleId,
      definition: definition!,
      embedded: true,
    );
  }
}

class _ReferencesTab extends StatelessWidget {
  final int projectId;
  final int bibleId;
  final String sectionId;
  final bool disabled;

  const _ReferencesTab({
    required this.projectId,
    required this.bibleId,
    required this.sectionId,
    required this.disabled,
  });

  @override
  Widget build(BuildContext context) {
    if (disabled) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'Las referencias por pantalla están disponibles en Dirección, '
            'Concepto, Iluminación y el resto de capítulos técnicos.',
            textAlign: TextAlign.center,
            style: AppTypography.caption(context.palette),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        BibleSectionReferencesManager(
          projectId: projectId,
          bibleId: bibleId,
          sectionId: sectionId,
          compact: true,
        ),
      ],
    );
  }
}

class _StyleTab extends StatelessWidget {
  final int bibleId;
  final int projectId;
  final String sectionId;
  final VoidCallback onOpenMasterConfig;

  const _StyleTab({
    required this.bibleId,
    required this.projectId,
    required this.sectionId,
    required this.onOpenMasterConfig,
  });

  @override
  Widget build(BuildContext context) {
    return BibleQuickAdjustPanel(
      bibleId: bibleId,
      projectId: projectId,
      sectionId: sectionId,
      onOpenMasterConfig: onOpenMasterConfig,
      embedded: true,
    );
  }
}

class _StructureTab extends StatelessWidget {
  final int bibleId;
  final int projectId;
  final VoidCallback onOpenMasterConfig;

  const _StructureTab({
    required this.bibleId,
    required this.projectId,
    required this.onOpenMasterConfig,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: BibleStructureEditor(
            bibleId: bibleId,
            projectId: projectId,
            compact: true,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: OutlinedButton.icon(
            onPressed: onOpenMasterConfig,
            icon: const Icon(Icons.dashboard_customize_outlined, size: 18),
            label: const Text('Estructura y plantillas (avanzado)'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
          child: Text(
            'Reordena pantallas aquí y observa cómo cambia el lateral al instante.',
            style: AppTypography.caption(palette).copyWith(color: palette.textTertiary),
          ),
        ),
      ],
    );
  }
}

/// Handle para abrir/cerrar el panel sin tapar el contenido.
class BibleLivePanelHandle extends StatelessWidget {
  final bool open;
  final VoidCallback onToggle;

  const BibleLivePanelHandle({
    super.key,
    required this.open,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.surfaceOverlay,
      child: InkWell(
        onTap: onToggle,
        child: Container(
          width: 28,
          alignment: Alignment.center,
          child: Icon(
            open ? Icons.chevron_right : Icons.tune,
            size: 18,
            color: open ? palette.textSecondary : palette.accent,
          ),
        ),
      ),
    );
  }
}
