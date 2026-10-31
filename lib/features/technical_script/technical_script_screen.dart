import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show listEquals, mapEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_layout.dart';
import '../shoot_documents/shoot_day_on_set.dart';
import '../shoot_documents/shoot_day_screen.dart';
import '../../core/sync/live_editing.dart';
import '../../core/sync/live_editing_scope.dart';
import '../../core/sync/realtime_hub.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/project_color_scheme.dart';
import '../../core/utils/scene_format.dart';
import '../../core/utils/scene_characters.dart';
import '../../core/utils/user_error.dart';
import '../../core/widgets/app_button.dart';
import '../camera_plan/camera_plan_status_cell.dart';
import '../../shared/history/edit_history.dart';
import '../../shared/history/shot_edits.dart';
import '../camera_plan/plan_data.dart';
import '../camera_plan/plan_sketch.dart';
import '../camera_plan/plan_thumbnail.dart';
import '../goodnotes/goodnotes_pdf_actions.dart';
import '../look_bible/look_bible_model.dart';
import '../../shared/pdf_export/technical_script_pdf.dart';
import '../../core/utils/shot_reference_import.dart';
import '../../shared/rich_text/script_markup.dart';
import '../../shared/shot_images/shot_image_menu.dart';
import '../../shared/technical_script_export/technical_script_docx.dart';
import '../locations/location_picker.dart';
import '../locations/where_field.dart';
import 'scene_form_sheet.dart';
import 'table/editable_cell.dart';
import 'table/script_sheet_theme.dart';
import 'import/technical_script_import_action.dart';
import 'script_export_dialog.dart';
import 'technical_script_export.dart';
import 'technical_script_settings.dart';
import '../../core/utils/shot_technical_options.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/scene_meta_display.dart';
import '../../core/utils/platform_keys.dart';

// Re-export para compatibilidad con imports existentes.
const kMovements = kShotMovements;
const kAngles = kShotAngles;

/// Color de lo que edita otro equipo (borde, etiqueta y texto en vivo).
const _kPeerColor = Color(0xFF7F77DD);

/// Lo que se ve de otro equipo en una fila: quién la edita y qué escribe.
class _RowLock {
  final String device;
  final Map<String, String> typing;

  const _RowLock(this.device, this.typing);

  static _RowLock? of(LiveEditing live, String? shotUid) {
    final holder = live.holderOf(shotUid);
    if (holder == null) return null;
    return _RowLock(holder.device, {
      for (final column in const [
        'encuadre',
        'lens',
        'f',
        'pers',
        'dur',
        'action',
        'notes',
      ])
        if (live.typingIn(shotUid, column) case final text?) column: text,
    });
  }

  @override
  bool operator ==(Object other) =>
      other is _RowLock &&
      other.device == device &&
      mapEquals(other.typing, typing);

  @override
  int get hashCode => Object.hash(
    device,
    Object.hashAllUnordered([
      for (final e in typing.entries) '${e.key}=${e.value}',
    ]),
  );
}

/// Un plano que edita otro equipo: borde de su color, la etiqueta
/// «Editando en iPad» encima y sin poder tocarlo aquí mientras tanto.
class _LockedShot extends StatelessWidget {
  final String device;
  final Widget child;

  const _LockedShot({required this.device, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => AppSnackBar.show(
            context,
            'Lo está editando el $device. Podrás tocarlo cuando lo deje.',
          ),
          child: AbsorbPointer(
            child: Container(
              foregroundDecoration: BoxDecoration(
                border: Border.all(color: _kPeerColor, width: 1.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: child,
            ),
          ),
        ),
        Positioned(
          top: -9,
          right: 12,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              decoration: BoxDecoration(
                color: _kPeerColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    device == 'Mac' ? Icons.laptop_mac : Icons.tablet_mac,
                    size: 12,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Editando en $device',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Plano en el que se está trabajando: el de la última celda tocada. La barra
/// de formato actúa sobre él.
final _activeShotProvider = StateProvider.autoDispose<int?>((ref) => null);

/// Celda en la que se está trabajando; el color de celda actúa sobre ella.
final _activeCellProvider =
    StateProvider.autoDispose<({int shotId, String column})?>((ref) => null);

/// Si los colores de la barra tiñen el plano entero o solo la celda.
final _colorTargetIsCellProvider = StateProvider.autoDispose<bool>(
  (ref) => false,
);

/// Colores de celda de un plano: columna → color.
Map<String, String> _cellStyles(Shot shot) {
  final raw = shot.cellStylesJson;
  if (raw == null || raw.isEmpty) return const {};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const {};
    return {
      for (final e in decoded.entries)
        if (e.value is String) '${e.key}': e.value as String,
    };
  } catch (_) {
    return const {};
  }
}

class TechnicalScriptScreen extends ConsumerWidget {
  final int projectId;
  const TechnicalScriptScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final settings = ref.watch(technicalScriptSettingsProvider);
    final theme = ScriptSheetTheme.resolve(settings, palette);

    // Al salir del guion, el plano que se editaba queda libre al momento.
    return LiveEditingScope(child: Scaffold(
      appBar: AppBar(
        backgroundColor: palette.surface,
        title: Text('Guion técnico', style: AppTypography.titleLarge(palette)),
        actions: [
          GoodNotesPdfActions(
            projectId: projectId,
            moduleType: GoodNotesModuleType.guionTecnico,
            filenameBase: 'guion_tecnico',
            buildPdfBytes: () async {
              final doc = await buildNarrativeScriptDoc(
                ref.read(databaseProvider),
                projectId,
                ref.read(technicalScriptSettingsProvider),
              );
              if (doc == null) return Uint8List(0);
              return TechnicalScriptPdfExporter.buildBytes(doc);
            },
          ),
          IconButton(
            tooltip: 'Jornadas de rodaje',
            icon: Icon(Icons.event_note_outlined, color: palette.accent),
            onPressed: () => _showShootDays(context, ref, projectId),
          ),
          IconButton(
            tooltip: 'Exportar el guion técnico',
            icon: Icon(Icons.ios_share, color: palette.accent),
            onPressed: () => _export(context, ref),
          ),
          PopupMenuButton<String>(
            tooltip: 'Importar guion técnico',
            icon: Icon(Icons.upload_file_outlined, color: palette.accent),
            color: palette.surfaceElevated,
            onSelected: (action) => switch (action) {
              'undo' => restoreTechnicalScriptBeforeImport(
                context,
                ref,
                projectId: projectId,
              ),
              'dedupe' => removeRepeatedReferences(
                context,
                ref,
                projectId: projectId,
              ),
              _ => importTechnicalScriptDocx(
                context,
                ref,
                projectId: projectId,
              ),
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'import',
                child: Text('Importar desde Word (.docx)…'),
              ),
              PopupMenuItem(
                value: 'undo',
                child: Text('Volver al guion anterior…'),
              ),
              PopupMenuItem(
                value: 'dedupe',
                child: Text('Quitar imágenes de referencia repetidas…'),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Añadir escena',
            icon: Icon(Icons.add, color: palette.accent),
            onPressed: () => showSceneFormSheet(context, projectId: projectId),
          ),
        ],
      ),
      body: _HistoryKeys(
        child: _CompactSwitch(
          projectId: projectId,
          table: (readSwitch) => Column(
          children: [
            ?readSwitch,
            _FormatBar(settings: settings),
            Expanded(
              child: PlanDataBuilder(
                projectId: projectId,
                builder: (context, data) {
                  if (data.scenes.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Sin escenas. Importa el guion o añade una '
                            'manualmente.',
                            style: AppTypography.bodyMedium(palette),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AppButton(
                            label: 'Añadir escena',
                            icon: Icons.add,
                            onTap: () => showSceneFormSheet(
                              context,
                              projectId: projectId,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AppButton(
                            label: 'Importar guion técnico (.docx)',
                            icon: Icons.upload_file_outlined,
                            onTap: () => importTechnicalScriptDocx(
                              context,
                              ref,
                              projectId: projectId,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ScriptSheet(
                    theme: theme,
                    child: _PlanDataScope(
                      data: data,
                      child: _ScriptTable(data: data, settings: settings),
                    ),
                  );
                },
              ),
            ),
          ],
          ),
        ),
      ),
    ));
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final settings = ref.read(technicalScriptSettingsProvider);
    final choice = await showScriptExportDialog(context, screen: settings);
    if (choice == null || !context.mounted) return;
    final word = choice.word;
    final db = ref.read(databaseProvider);
    try {
      final built = await buildNarrativeScriptDoc(
        db,
        projectId,
        settings,
        hiddenColumns: choice.hiddenColumns,
      );
      final doc = built == null ? null : choice.applyTo(built);
      if (!context.mounted) return;
      if (doc == null || doc.sections.isEmpty) {
        AppSnackBar.show(context, 'No hay escenas para exportar.');
        return;
      }
      final project = await db.getProject(projectId);
      final fileName = technicalScriptFileName(project?.name ?? '');
      final path = word
          ? await TechnicalScriptDocxExporter.exportAndSave(
              doc,
              fileName: fileName,
            )
          : await TechnicalScriptPdfExporter.exportAndSave(
              doc,
              fileName: fileName,
            );
      if (!context.mounted) return;
      if (path != null) {
        AppSnackBar.show(context, '${word ? 'Word' : 'PDF'} guardado en $path');
      }
    } catch (e) {
      if (!context.mounted) return;
      AppSnackBar.show(context, userFriendlyError(e));
    }
  }
}

/// ⌘Z deshace y ⇧⌘Z rehace el último cambio de la tabla. Dentro de una
/// celda que se está escribiendo manda el deshacer del propio texto.
class _HistoryKeys extends ConsumerStatefulWidget {
  final Widget child;

  const _HistoryKeys({required this.child});

  @override
  ConsumerState<_HistoryKeys> createState() => _HistoryKeysState();
}

class _HistoryKeysState extends ConsumerState<_HistoryKeys> {
  @override
  void initState() {
    super.initState();
    // El historial es de esta visita a la pantalla.
    final history = ref.read(editHistoryProvider);
    Future.microtask(history.clear);
  }

  @override
  Widget build(BuildContext context) {
    void undo() => _stepHistory(context, ref, redo: false);
    void redo() => _stepHistory(context, ref, redo: true);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
            redo,
        const SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: true,
          shift: true,
        ): redo,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): redo,
      },
      child: Focus(autofocus: true, child: widget.child),
    );
  }
}

/// Deshace o rehace un paso y dice cuál ha sido.
Future<void> _stepHistory(
  BuildContext context,
  WidgetRef ref, {
  required bool redo,
}) async {
  final history = ref.read(editHistoryProvider);
  final label = redo ? await history.redo() : await history.undo();
  if (!context.mounted) return;
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1400),
        content: Text(
          label == null
              ? (redo
                    ? 'No hay nada que rehacer.'
                    : 'No hay nada que deshacer.')
              : '${redo ? 'Rehecho' : 'Deshecho'}: $label',
        ),
      ),
    );
}

/// Datos de plantas del proyecto, al alcance de la celda de planta sin
/// obligar a repintar la fila entera cuando cambian.
class _PlanDataScope extends InheritedWidget {
  final PlanProjectData data;

  const _PlanDataScope({required this.data, required super.child});

  static PlanProjectData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PlanDataScope>()!.data;

  @override
  bool updateShouldNotify(_PlanDataScope oldWidget) => oldWidget.data != data;
}

/// Barra de formato del guion técnico: vista, tipografía, columnas y color
/// del plano en el que se está trabajando.
class _FormatBar extends ConsumerWidget {
  final TechnicalScriptSettings settings;
  const _FormatBar({required this.settings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final notifier = ref.read(technicalScriptSettingsProvider.notifier);
    final activeShot = ref.watch(_activeShotProvider);
    final label = AppTypography.bodyMedium(
      palette,
    ).copyWith(color: palette.textPrimary);

    Widget divider() => Container(
      width: 1,
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: palette.divider,
    );

    Widget iconButton({
      required String tooltip,
      required IconData icon,
      required VoidCallback? onTap,
    }) => IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 18),
      color: palette.textPrimary,
      disabledColor: palette.textTertiary,
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
    );

    final history = ref.watch(editHistoryProvider);
    final cellTarget = ref.watch(_colorTargetIsCellProvider);
    final activeCell = ref.watch(_activeCellProvider);
    final canColor = cellTarget ? activeCell != null : activeShot != null;

    Future<void> setColor(String? value) async {
      final db = ref.read(databaseProvider);
      if (!cellTarget) {
        if (activeShot == null) return;
        await writeShotFields(
          db,
          history,
          activeShot,
          ShotsCompanion(notesHighlight: Value(value)),
          label: 'color del plano',
        );
        return;
      }
      final cell = activeCell;
      if (cell == null) return;
      final shot = await db.getShotById(cell.shotId);
      if (shot == null) return;
      final styles = {..._cellStyles(shot)};
      value == null ? styles.remove(cell.column) : styles[cell.column] = value;
      await writeShotFields(
        db,
        history,
        cell.shotId,
        ShotsCompanion(
          cellStylesJson: Value(styles.isEmpty ? null : jsonEncode(styles)),
        ),
        label: 'color de la celda',
      );
    }

    final swatches = ScriptSheetTheme.resolve(
      settings.copyWith(view: ScriptView.sheet),
      palette,
    );

    // Tocar la barra no saca el foco del campo que se está editando.
    return TextFieldTapRegion(
      child: Container(
        height: 44,
        width: double.infinity,
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border(bottom: BorderSide(color: palette.divider)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              iconButton(
                tooltip: 'Deshacer (${modKey}Z)',
                icon: Icons.undo,
                onTap: history.canUndo
                    ? () => _stepHistory(context, ref, redo: false)
                    : null,
              ),
              iconButton(
                tooltip: 'Rehacer (⇧${modKey}Z)',
                icon: Icons.redo,
                onTap: history.canRedo
                    ? () => _stepHistory(context, ref, redo: true)
                    : null,
              ),
              divider(),
              SegmentedButton<ScriptView>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: const [
                  ButtonSegment(
                    value: ScriptView.sheet,
                    icon: Icon(Icons.description_outlined, size: 16),
                    label: Text('Hoja'),
                  ),
                  ButtonSegment(
                    value: ScriptView.dark,
                    icon: Icon(Icons.dark_mode_outlined, size: 16),
                    label: Text('Oscura'),
                  ),
                ],
                selected: {settings.view},
                onSelectionChanged: (s) =>
                    notifier.update((v) => v.copyWith(view: s.first)),
              ),
              const SizedBox(width: 12),
              PopupMenuButton<String>(
                tooltip: 'Columnas visibles',
                color: palette.surfaceElevated,
                onSelected: notifier.toggleColumn,
                itemBuilder: (_) => [
                  for (final c in ScriptColumn.optional)
                    CheckedPopupMenuItem(
                      value: c,
                      checked: settings.shows(c),
                      child: Text(ScriptColumn.label(c)),
                    ),
                ],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.view_column_outlined,
                      size: 18,
                      color: palette.textPrimary,
                    ),
                    const SizedBox(width: 6),
                    Text('Columnas', style: label),
                  ],
                ),
              ),
              divider(),
              PopupMenuButton<String>(
                tooltip: 'Tipografía de la tabla',
                color: palette.surfaceElevated,
                onSelected: (f) =>
                    notifier.update((v) => v.copyWith(fontFamily: f)),
                itemBuilder: (_) => [
                  for (final f in kScriptFonts.entries)
                    CheckedPopupMenuItem(
                      value: f.key,
                      checked: settings.fontFamily == f.key,
                      child: Text(f.value),
                    ),
                ],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      kScriptFonts[settings.fontFamily] ?? settings.fontFamily,
                      style: label,
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      size: 18,
                      color: palette.textSecondary,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              iconButton(
                tooltip: 'Letra más pequeña',
                icon: Icons.remove,
                onTap: settings.fontSize <= TechnicalScriptSettings.minFontSize
                    ? null
                    : () => notifier.update(
                        (v) => v.copyWith(fontSize: v.fontSize - 1),
                      ),
              ),
              Container(
                width: 34,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(color: palette.border),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(settings.fontSize.round().toString(), style: label),
              ),
              iconButton(
                tooltip: 'Letra más grande',
                icon: Icons.add,
                onTap: settings.fontSize >= TechnicalScriptSettings.maxFontSize
                    ? null
                    : () => notifier.update(
                        (v) => v.copyWith(fontSize: v.fontSize + 1),
                      ),
              ),
              divider(),
              ValueListenableBuilder<TextEditingController?>(
                valueListenable: activeScriptEditor,
                builder: (context, editor, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    iconButton(
                      tooltip: 'Negrita (${modKey}B)',
                      icon: Icons.format_bold,
                      onTap: editor == null
                          ? null
                          : () => applyScriptMark(editor, ScriptMark.bold),
                    ),
                    iconButton(
                      tooltip: 'Cursiva (${modKey}I)',
                      icon: Icons.format_italic,
                      onTap: editor == null
                          ? null
                          : () => applyScriptMark(editor, ScriptMark.italic),
                    ),
                    iconButton(
                      tooltip: 'Subrayado (${modKey}U)',
                      icon: Icons.format_underlined,
                      onTap: editor == null
                          ? null
                          : () => applyScriptMark(editor, ScriptMark.underline),
                    ),
                    const SizedBox(width: 6),
                    Opacity(
                      opacity: editor == null ? 0.4 : 1,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.border_color_outlined,
                            size: 18,
                            color: palette.textPrimary,
                          ),
                          const SizedBox(width: 6),
                          for (final c in kScriptMarkerColors.entries)
                            Padding(
                              padding: const EdgeInsets.only(right: 3),
                              child: Tooltip(
                                message: 'Marcador ${c.value.toLowerCase()}',
                                child: InkResponse(
                                  radius: 14,
                                  onTap: editor == null
                                      ? null
                                      : () => applyScriptMark(
                                          editor,
                                          ScriptMark.marker,
                                          color: c.key,
                                        ),
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: kScriptMarkerFills[c.key],
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(color: palette.border),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(width: 4),
                          // Color de la letra: el mismo color otra vez lo
                          // quita.
                          for (final c in kScriptTextColors.entries)
                            Tooltip(
                              message: 'Letra ${c.value.toLowerCase()}',
                              child: InkResponse(
                                radius: 12,
                                onTap: editor == null
                                    ? null
                                    : () => applyScriptMark(
                                        editor,
                                        ScriptMark.textColor,
                                        color: c.key,
                                      ),
                                child: SizedBox(
                                  width: 16,
                                  height: 18,
                                  child: Center(
                                    child: Text(
                                      'A',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: kScriptTextColorValues[c.key],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          iconButton(
                            tooltip: 'Quitar el marcador y el color',
                            icon: Icons.format_clear,
                            onTap: editor == null
                                ? null
                                : () {
                                    applyScriptMark(editor, ScriptMark.marker);
                                    applyScriptMark(
                                      editor,
                                      ScriptMark.textColor,
                                    );
                                  },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              divider(),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: const [
                  ButtonSegment(value: false, label: Text('Plano')),
                  ButtonSegment(value: true, label: Text('Celda')),
                ],
                selected: {cellTarget},
                onSelectionChanged: (v) =>
                    ref.read(_colorTargetIsCellProvider.notifier).state =
                        v.first,
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: !canColor
                    ? (cellTarget
                          ? 'Toca una celda para darle color'
                          : 'Toca un plano para darle color')
                    : (cellTarget ? 'Color de la celda' : 'Color del plano'),
                child: Opacity(
                  opacity: canColor ? 1 : 0.4,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.format_color_fill,
                        size: 18,
                        color: palette.textPrimary,
                      ),
                      const SizedBox(width: 8),
                      for (final c in kScriptRowColors)
                        Padding(
                          padding: const EdgeInsets.only(right: 5),
                          child: Tooltip(
                            message: scriptRowColorLabel(c),
                            child: InkResponse(
                              radius: 14,
                              onTap: canColor ? () => setColor(c) : null,
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: swatches.rowFill(c),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: palette.border),
                                ),
                              ),
                            ),
                          ),
                        ),
                      iconButton(
                        tooltip: cellTarget
                            ? 'Quitar el color de la celda'
                            : 'Quitar el color del plano',
                        icon: Icons.format_color_reset_outlined,
                        onTap: canColor ? () => setColor(null) : null,
                      ),
                    ],
                  ),
                ),
              ),
              divider(),
              PopupMenuButton<ScriptPlanView>(
                tooltip: 'Qué enseña la casilla Planta (y el PDF/Word)',
                color: palette.surfaceElevated,
                onSelected: (v) =>
                    notifier.update((s) => s.copyWith(planView: v)),
                itemBuilder: (_) => [
                  for (final v in ScriptPlanView.values)
                    CheckedPopupMenuItem(
                      value: v,
                      checked: settings.planView == v,
                      child: Text(v.label),
                    ),
                ],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.grid_on_outlined,
                      size: 18,
                      color: palette.textPrimary,
                    ),
                    const SizedBox(width: 6),
                    Text(settings.planView.label, style: label),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Guion técnico: una tabla por escena, como hojas de un documento. Ocupa
/// todo el ancho; por debajo del mínimo, se desplaza entera.
/// Las jornadas del proyecto, para abrir una desde el guion técnico (G5):
/// en el iPhone, «En set»; si no, la jornada para ordenarla y exportarla.
Future<void> _showShootDays(
  BuildContext context,
  WidgetRef ref,
  int projectId,
) async {
  final db = ref.read(databaseProvider);
  final days = [
    for (final d in await db.watchShootDocumentsForProject(projectId).first)
      if (d.kind == kShootDayKind) d,
  ]..sort((a, b) => (a.shootDate ?? '').compareTo(b.shootDate ?? ''));
  if (!context.mounted) return;
  final palette = context.palette;
  final picked = await showModalBottomSheet<ShootDocument>(
    context: context,
    backgroundColor: palette.surfaceElevated,
    builder: (ctx) => SafeArea(
      child: days.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                'Aún no hay jornadas. Créalas en Documentos de rodaje.',
                style: AppTypography.bodyMedium(palette),
              ),
            )
          : ListView(
              shrinkWrap: true,
              children: [
                for (final d in days)
                  ListTile(
                    leading: const Icon(Icons.event_note_outlined),
                    title: Text(d.name),
                    subtitle: d.shootDate == null
                        ? null
                        : Text(formatShootDate(d.shootDate)),
                    onTap: () => Navigator.pop(ctx, d),
                  ),
              ],
            ),
    ),
  );
  if (picked == null || !context.mounted) return;
  if (AppLayout.isCompact(context)) {
    await ShootDayOnSetScreen.open(
      context,
      projectId: projectId,
      documentId: picked.id,
      title: picked.name,
    );
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          ShootDayScreen(projectId: projectId, documentId: picked.id),
    ),
  );
}

/// En el iPhone (IP.2.3) el guion se abre en lectura: escenas y planos en
/// tarjetas. La tabla sigue a un toque, para retocar algo suelto.
class _CompactSwitch extends StatefulWidget {
  final int projectId;

  /// La tabla de siempre; en el iPhone recibe arriba el selector.
  final Widget Function(Widget? readSwitch) table;

  const _CompactSwitch({required this.projectId, required this.table});

  @override
  State<_CompactSwitch> createState() => _CompactSwitchState();
}

class _CompactSwitchState extends State<_CompactSwitch> {
  bool _read = true;

  @override
  Widget build(BuildContext context) {
    if (!AppLayout.isCompact(context)) return widget.table(null);
    final selector = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppLayout.gutter(context),
        vertical: AppSpacing.sm,
      ),
      child: SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: true,
            icon: Icon(Icons.view_agenda_outlined, size: 18),
            label: Text('Lectura'),
          ),
          ButtonSegment(
            value: false,
            icon: Icon(Icons.table_chart_outlined, size: 18),
            label: Text('Tabla'),
          ),
        ],
        selected: {_read},
        onSelectionChanged: (v) => setState(() => _read = v.first),
      ),
    );
    if (!_read) return widget.table(selector);
    return Column(
      children: [
        selector,
        Expanded(child: _ScriptReadList(projectId: widget.projectId)),
      ],
    );
  }
}

/// El guion técnico en tarjetas, en orden de guion.
class _ScriptReadList extends ConsumerWidget {
  final int projectId;

  const _ScriptReadList({required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);
    final gutter = AppLayout.gutter(context);
    return StreamBuilder<List<Scene>>(
      stream: db.watchScenesForProject(projectId),
      builder: (context, sceneSnap) => StreamBuilder<List<Shot>>(
        stream: db.watchShotsForProject(projectId),
        builder: (context, shotSnap) {
          final scenes = sceneSnap.data ?? const <Scene>[];
          final byScene = <int, List<Shot>>{};
          for (final shot in shotSnap.data ?? const <Shot>[]) {
            byScene.putIfAbsent(shot.sceneId, () => []).add(shot);
          }
          return ListView(
            padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 40),
            children: [
              for (final scene in scenes) ...[
                Padding(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.lg,
                    bottom: 6,
                  ),
                  child: Text(
                    'ESC ${scene.label} · ${scene.locationCanonical}',
                    style: AppTypography.titleMedium(palette),
                  ),
                ),
                if ((byScene[scene.id] ?? const []).isEmpty)
                  Text('Sin planos.', style: AppTypography.caption(palette)),
                for (final shot in byScene[scene.id] ?? const <Shot>[])
                  OnSetShotCard(
                    order: shot.number,
                    shot: shot,
                    scene: scene,
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ScriptTable extends StatelessWidget {
  final PlanProjectData data;
  final TechnicalScriptSettings settings;

  const _ScriptTable({required this.data, required this.settings});

  @override
  Widget build(BuildContext context) {
    final shotsByScene = <int, List<Shot>>{};
    for (final shot in data.shots) {
      shotsByScene.putIfAbsent(shot.sceneId, () => []).add(shot);
    }
    final scenes = data.scenes;

    return LayoutBuilder(
      builder: (context, constraints) {
        final minWidth = _Cols.minWidth(settings);
        final width = math.max(constraints.maxWidth, minWidth);
        final cols = _Cols.forWidth(width, settings);
        final table = ListView.builder(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          itemCount: scenes.length + 1,
          // Al crear o borrar una escena las demás cambian de índice: con
          // esto conservan su estado (y la fila de nueva escena sigue
          // abierta para la siguiente).
          findChildIndexCallback: (key) {
            if (key == _newSceneKey) return scenes.length;
            if (key is ValueKey<int>) {
              final i = scenes.indexWhere((s) => s.id == key.value);
              return i < 0 ? null : i;
            }
            return null;
          },
          itemBuilder: (context, i) => i == scenes.length
              ? _NewSceneRow(
                  key: _newSceneKey,
                  projectId: scenes.first.projectId,
                  last: scenes.last,
                )
              : _SceneSection(
                  key: ValueKey(scenes[i].id),
                  scene: scenes[i],
                  shots: shotsByScene[scenes[i].id] ?? const [],
                  colors: data.colors,
                  cols: cols,
                ),
        );
        if (width <= constraints.maxWidth) return table;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            height: constraints.maxHeight,
            child: table,
          ),
        );
      },
    );
  }
}

const _newSceneKey = ValueKey<String>('new-scene');

/// Al final de la tabla: crear una escena diciendo solo dónde ocurre. Toma
/// INT/EXT y el momento de la última escena; se cambian luego en la suya.
class _NewSceneRow extends ConsumerStatefulWidget {
  final int projectId;
  final Scene last;

  const _NewSceneRow({super.key, required this.projectId, required this.last});

  @override
  ConsumerState<_NewSceneRow> createState() => _NewSceneRowState();
}

class _NewSceneRowState extends ConsumerState<_NewSceneRow> {
  final _where = GlobalKey<WhereFieldState>();
  bool _open = false;
  bool _creating = false;

  Future<void> _create(LocationChoice choice) async {
    if (_creating) return;
    _creating = true;
    try {
      await createSceneAt(
        db: ref.read(databaseProvider),
        projectId: widget.projectId,
        choice: choice,
        intExt: widget.last.intExt,
        dayNight: widget.last.dayNight,
      );
      // Listo para la siguiente.
      _where.currentState?.clear();
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, userFriendlyError(e));
    } finally {
      _creating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (!_open) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.sm),
          child: TextButton.icon(
            onPressed: () => setState(() => _open = true),
            icon: Icon(Icons.add, color: palette.accent, size: 18),
            label: Text(
              'Nueva escena',
              style: AppTypography.label(
                palette,
              ).copyWith(color: palette.accent),
            ),
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 520,
        margin: const EdgeInsets.only(left: AppSpacing.lg),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: palette.surfaceElevated,
          border: Border.all(color: palette.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Nueva escena',
                    style: AppTypography.titleMedium(palette),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _open = false),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            WhereField(
              key: _where,
              projectId: widget.projectId,
              autofocus: true,
              listHeight: 190,
              onChanged: (choice) {
                if (choice != null) _create(choice);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Elige un lugar o escribe uno nuevo y pulsa Intro. La escena se '
              'crea como ${widget.last.intExt} · ${widget.last.dayNight}; se '
              'cambia después con el lápiz.',
              style: AppTypography.caption(palette),
            ),
          ],
        ),
      ),
    );
  }
}

/// Anchos de columna para un ancho de tabla dado. Las columnas ocultas
/// miden cero; lo que sobra se reparte entre las de texto largo y la
/// referencia.
@immutable
class _Cols {
  final double handle;
  final double esc;
  final double plano;
  final double encuadre;
  final double lens;
  final double fStop;
  final double personajes;
  final double duracion;
  final double action;
  final double referencia;
  final double storyboard;
  final double planta;
  final double apuntes;
  final double acciones;

  const _Cols._({
    required this.handle,
    required this.esc,
    required this.plano,
    required this.encuadre,
    required this.lens,
    required this.fStop,
    required this.personajes,
    required this.duracion,
    required this.action,
    required this.referencia,
    required this.storyboard,
    required this.planta,
    required this.apuntes,
    required this.acciones,
  });

  static _Cols _min(TechnicalScriptSettings s) => _Cols._(
    handle: 28,
    esc: 40,
    plano: 52,
    encuadre: 150,
    lens: 140,
    fStop: s.shows(ScriptColumn.fStop) ? 52 : 0,
    personajes: s.shows(ScriptColumn.personajes) ? 110 : 0,
    duracion: s.shows(ScriptColumn.duracion) ? 56 : 0,
    action: 220,
    referencia: 140,
    storyboard: s.shows(ScriptColumn.storyboard) ? 140 : 0,
    planta: s.shows(ScriptColumn.planta) ? 110 : 0,
    apuntes: 140,
    acciones: 40,
  );

  List<double> get _all => [
    handle,
    esc,
    plano,
    encuadre,
    lens,
    fStop,
    personajes,
    duracion,
    action,
    referencia,
    storyboard,
    planta,
    apuntes,
    acciones,
  ];

  static double minWidth(TechnicalScriptSettings s) =>
      _min(s)._all.fold(0, (a, b) => a + b);

  factory _Cols.forWidth(double width, TechnicalScriptSettings s) {
    final m = _min(s);
    final extra = math.max(0.0, width - minWidth(s));
    double grow(double base, int weight) => base + extra * weight / 12;
    return _Cols._(
      handle: m.handle,
      esc: m.esc,
      plano: m.plano,
      encuadre: grow(m.encuadre, 3),
      lens: m.lens,
      fStop: m.fStop,
      personajes: m.personajes,
      duracion: m.duracion,
      action: grow(m.action, 5),
      referencia: grow(m.referencia, 1),
      storyboard: m.storyboard,
      planta: m.planta,
      apuntes: grow(m.apuntes, 3),
      acciones: m.acciones,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _Cols && listEquals(other._all, _all);

  @override
  int get hashCode => Object.hashAll(_all);
}

Future<bool> _confirmDelete(
  BuildContext context, {
  required String title,
  required String body,
}) async {
  final palette = context.palette;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: palette.surfaceElevated,
      title: Text(title, style: AppTypography.titleMedium(palette)),
      content: Text(body, style: AppTypography.bodyMedium(palette)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Cancelar', style: AppTypography.bodyMedium(palette)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            'Eliminar',
            style: AppTypography.bodyMedium(
              palette,
            ).copyWith(color: palette.error),
          ),
        ),
      ],
    ),
  );
  return ok ?? false;
}

class _SceneSection extends ConsumerStatefulWidget {
  final Scene scene;
  final List<Shot> shots;
  final ProjectColorScheme colors;
  final _Cols cols;

  const _SceneSection({
    super.key,
    required this.scene,
    required this.shots,
    required this.colors,
    required this.cols,
  });

  @override
  ConsumerState<_SceneSection> createState() => _SceneSectionState();
}

class _SceneSectionState extends ConsumerState<_SceneSection> {
  /// Orden recién soltado, mientras la base de datos no lo devuelve.
  List<int>? _pendingOrder;

  @override
  void didUpdateWidget(_SceneSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pending = _pendingOrder;
    if (pending == null) return;
    final ids = [for (final s in widget.shots) s.id];
    if (listEquals(ids, pending) || ids.length != pending.length) {
      _pendingOrder = null;
    }
  }

  List<Shot> get _orderedShots {
    final pending = _pendingOrder;
    if (pending == null) return widget.shots;
    final byId = {for (final s in widget.shots) s.id: s};
    if (pending.any((id) => !byId.containsKey(id))) return widget.shots;
    return [for (final id in pending) byId[id]!];
  }

  /// Filas ya construidas. Devolver el mismo widget cuando ni el plano, ni la
  /// escena, ni las columnas han cambiado hace que Flutter no repinte esa
  /// fila aunque cambie otra cosa del proyecto.
  final _rows = <int, _ShotRow>{};

  _ShotRow _rowFor(Shot shot) {
    final cached = _rows[shot.id];
    if (cached != null &&
        cached.shot == shot &&
        cached.scene == widget.scene &&
        cached.cols == widget.cols) {
      return cached;
    }
    return _rows[shot.id] = _ShotRow(
      shot: shot,
      scene: widget.scene,
      cols: widget.cols,
    );
  }

  /// Un plano soltado aquí: si es de esta escena cambia de sitio; si viene
  /// de otra, se pasa a esta.
  void _dropBefore(List<Shot> shots, _ShotDrag drag, int beforeIndex) {
    if (drag.sceneId == widget.scene.id) {
      _moveBefore(shots, drag.shotId, beforeIndex);
      return;
    }
    ref
        .read(databaseProvider)
        .moveShotToScene(
          drag.shotId,
          widget.scene.id,
          beforeIndex: beforeIndex,
        );
  }

  /// Coloca el plano arrastrado delante del que ocupa [beforeIndex]
  /// (`shots.length` = al final).
  void _moveBefore(List<Shot> shots, int draggedId, int beforeIndex) {
    final ids = [for (final s in shots) s.id];
    final from = ids.indexOf(draggedId);
    if (from < 0) return;
    final to = beforeIndex > from ? beforeIndex - 1 : beforeIndex;
    if (to == from) return;
    final before = [...ids];
    ids.insert(to, ids.removeAt(from));
    setState(() => _pendingOrder = ids);
    final db = ref.read(databaseProvider);
    final sceneId = widget.scene.id;
    db.reorderShotsInScene(sceneId, ids);
    ref
        .read(editHistoryProvider)
        .record(
          EditStep(
            label: 'orden de los planos',
            undo: () => db.reorderShotsInScene(sceneId, before),
            redo: () => db.reorderShotsInScene(sceneId, ids),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.read(databaseProvider);
    final palette = context.palette;
    final scene = widget.scene;
    final shots = _orderedShots;
    _rows.removeWhere((id, _) => !shots.any((s) => s.id == id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SceneHeader(
          scene: scene,
          shotCount: shots.length,
          colors: widget.colors,
        ),
        const SizedBox(height: AppSpacing.sm),
        _TableHeader(
          cols: widget.cols,
          sceneColor: widget.colors.sceneColor(scene),
        ),
        // Columna con claves y no una lista reordenable: al cambiar el orden
        // las filas se mueven sin desmontarse, y lo que tengan a medias (foco,
        // avisos, menús) sigue en su sitio.
        for (var i = 0; i < shots.length; i++)
          _ShotDropTarget(
            key: ValueKey(shots[i].id),
            sceneId: scene.id,
            shotId: shots[i].id,
            onDrop: (drag) => _dropBefore(shots, drag, i),
            child: _rowFor(shots[i]),
          ),
        _ShotDropTarget(
          sceneId: scene.id,
          shotId: null,
          onDrop: (drag) => _dropBefore(shots, drag, shots.length),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => db.insertShot(
                ShotsCompanion.insert(
                  sceneId: scene.id,
                  projectId: scene.projectId,
                  number: shots.length + 1,
                  sortOrder: Value(shots.length),
                ),
              ),
              icon: Icon(Icons.add, color: palette.accent, size: 16),
              label: Text(
                'Añadir plano',
                style: AppTypography.label(
                  palette,
                ).copyWith(color: palette.accent),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

/// Título de la escena con sus tres datos cambiables al toque: INT/EXT,
/// lugar y momento. El resto (nombre, descripción, color) va en «Editar».
class _SceneTitle extends ConsumerWidget {
  final Scene scene;
  const _SceneTitle({required this.scene});

  Future<void> _save(
    WidgetRef ref, {
    String? intExt,
    String? dayNight,
    LocationChoice? place,
  }) async {
    final db = ref.read(databaseProvider);
    final fresh = await db.getSceneById(scene.id);
    if (fresh == null) return;
    final oldPlace = locationFromCanonical(fresh.locationCanonical);
    final newIntExt = intExt ?? fresh.intExt;
    final newDayNight = dayNight ?? fresh.dayNight;
    final newPlace = place?.placeName ?? oldPlace;
    // El nombre sigue al título mientras nadie le haya puesto uno propio.
    final hadDefaultName =
        fresh.name ==
        formatSceneDefaultName(
          intExt: fresh.intExt,
          dayNight: fresh.dayNight,
          location: oldPlace,
        );
    final changed = fresh.copyWith(
      intExt: newIntExt,
      dayNight: newDayNight,
      locationCanonical: '$newIntExt. $newPlace - $newDayNight',
      name: hadDefaultName
          ? formatSceneDefaultName(
              intExt: newIntExt,
              dayNight: newDayNight,
              location: newPlace,
            )
          : fresh.name,
      locationPureName: place?.set.locationName ?? fresh.locationPureName,
      locationSiteId: place != null
          ? Value(place.site.id)
          : Value(fresh.locationSiteId),
      locationId: place != null ? Value(place.set.id) : Value(fresh.locationId),
    );
    await db.updateScene(changed);
    ref
        .read(editHistoryProvider)
        .record(
          EditStep(
            label: 'cabecera de la escena ${fresh.number}',
            undo: () => db.updateScene(fresh),
            redo: () => db.updateScene(changed),
          ),
        );
  }

  Future<void> _pickPlace(BuildContext context, WidgetRef ref) async {
    final palette = context.palette;
    final choice = await showDialog<LocationChoice>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: palette.surfaceElevated,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '¿Dónde ocurre la escena ${scene.label}?',
                  style: AppTypography.titleMedium(palette),
                ),
                const SizedBox(height: AppSpacing.md),
                WhereField(
                  projectId: scene.projectId,
                  autofocus: true,
                  onChanged: (choice) {
                    if (choice != null) Navigator.pop(dialogContext, choice);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (choice != null) await _save(ref, place: choice);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final style = AppTypography.titleMedium(
      palette,
    ).copyWith(color: palette.textPrimary, letterSpacing: 0.5);

    Widget chip(String text, String tooltip) => Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        child: Text(text, style: style),
      ),
    );

    Widget menu(
      String value,
      List<String> options,
      String tooltip,
      ValueChanged<String> onSelected,
    ) => PopupMenuButton<String>(
      tooltip: tooltip,
      initialValue: value,
      padding: EdgeInsets.zero,
      onSelected: (v) {
        if (v != value) onSelected(v);
      },
      itemBuilder: (_) => [
        for (final o in options) PopupMenuItem(value: o, child: Text(o)),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        child: Text(value, style: style),
      ),
    );

    return Row(
      children: [
        Text('${scene.label}.', style: style),
        const SizedBox(width: 3),
        menu(
          scene.intExt,
          kIntExtOptions,
          'Cambiar interior o exterior',
          (v) => _save(ref, intExt: v),
        ),
        Flexible(
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: () => _pickPlace(context, ref),
            child: chip(
              locationFromCanonical(scene.locationCanonical),
              'Cambiar el lugar',
            ),
          ),
        ),
        Text('-', style: style),
        menu(
          scene.dayNight,
          kDayNightOptions,
          'Cambiar el momento',
          (v) => _save(ref, dayNight: v),
        ),
        const SizedBox(width: 6),
        DayNightIcon(
          dayNight: scene.dayNight,
          size: 18,
          color: palette.textSecondary,
        ),
      ],
    );
  }
}

class _SceneHeader extends ConsumerWidget {
  final Scene scene;
  final int shotCount;
  final ProjectColorScheme colors;

  const _SceneHeader({
    required this.scene,
    required this.shotCount,
    required this.colors,
  });

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final planos = switch (shotCount) {
      0 => 'No tiene planos.',
      1 => 'Se borra también su plano, con su referencia y su planta.',
      _ =>
        'Se borran también sus $shotCount planos, con sus referencias y sus '
            'plantas.',
    };
    final ok = await _confirmDelete(
      context,
      title: 'Eliminar la escena ${scene.label}',
      body: '$planos Las demás escenas conservan su número.',
    );
    if (!ok) return;
    try {
      await ref.read(databaseProvider).deleteScene(scene.id);
    } catch (e) {
      if (context.mounted) AppSnackBar.showError(context, userFriendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final accent = colors.sceneColor(scene);

    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        border: Border(
          left: BorderSide(color: accent, width: 5),
          bottom: BorderSide(color: palette.divider),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.only(top: 4, right: AppSpacing.sm),
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SceneTitle(scene: scene),
                if (scene.offScript) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 14,
                        color: palette.highlightYellow.withValues(alpha: 1),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Ya no está en el guion literario. Se conserva '
                          'con sus planos; puedes eliminarla cuando no la '
                          'necesites.',
                          style: AppTypography.caption(palette).copyWith(
                            color: palette.highlightYellow.withValues(alpha: 1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (scene.description != null &&
                    scene.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    scene.description!,
                    style: AppTypography.bodyMedium(
                      palette,
                    ).copyWith(color: palette.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          if (scene.offScript)
            _MoveAllShotsButton(scene: scene, shotCount: shotCount)
          else if (scene.scriptLinked)
            Tooltip(
              message:
                  'Viene del guion literario: su número y su orden son '
                  'los del guion.',
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: palette.textTertiary,
                ),
              ),
            )
          else ...[
            IconButton(
              tooltip: 'Subir escena',
              icon: Icon(
                Icons.arrow_upward,
                color: palette.textSecondary,
                size: 18,
              ),
              onPressed: () =>
                  ref.read(databaseProvider).moveSceneBy(scene.id, -1),
            ),
            IconButton(
              tooltip: 'Bajar escena',
              icon: Icon(
                Icons.arrow_downward,
                color: palette.textSecondary,
                size: 18,
              ),
              onPressed: () =>
                  ref.read(databaseProvider).moveSceneBy(scene.id, 1),
            ),
          ],
          IconButton(
            tooltip: 'Editar escena',
            icon: Icon(
              Icons.edit_outlined,
              color: palette.textSecondary,
              size: 18,
            ),
            onPressed: () => showSceneFormSheet(
              context,
              projectId: scene.projectId,
              scene: scene,
            ),
          ),
          IconButton(
            tooltip: 'Eliminar escena',
            icon: Icon(
              Icons.delete_outline,
              color: palette.textSecondary,
              size: 18,
            ),
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
    );
  }
}

/// Fila de títulos de columna, una por escena, con el color de la escena.
class _TableHeader extends StatelessWidget {
  final _Cols cols;
  final Color sceneColor;
  const _TableHeader({required this.cols, required this.sceneColor});

  @override
  Widget build(BuildContext context) {
    final sheet = ScriptSheet.of(context);
    final side = sheet.side;

    Widget cell(String text, double width) => width == 0
        ? const SizedBox.shrink()
        : Container(
            width: width,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            decoration: BoxDecoration(border: Border(right: side)),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: sheet.headerText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );

    return Row(
      children: [
        SizedBox(width: cols.handle),
        Container(
          decoration: BoxDecoration(
            color: sheet.headerFill(sceneColor),
            border: Border(top: side, left: side, bottom: side),
          ),
          child: Row(
            children: [
              cell('ESC', cols.esc),
              cell('PLANO', cols.plano),
              cell('Encuadre', cols.encuadre),
              cell('LENTE/ANG/MOV', cols.lens),
              cell('F', cols.fStop),
              cell('PERS.', cols.personajes),
              cell('DUR.', cols.duracion),
              cell('ACCIÓN', cols.action),
              cell('REFERENCIA', cols.referencia),
              cell('STORYBOARD', cols.storyboard),
              cell('PLANTA', cols.planta),
              cell('APUNTES', cols.apuntes),
            ],
          ),
        ),
      ],
    );
  }
}

/// Celda de la hoja: línea a la derecha y, si lo que contiene tiene el foco,
/// borde de acento.
class _Cell extends ConsumerWidget {
  final double width;
  final Widget child;
  final EdgeInsets padding;
  final Alignment alignment;

  /// Plano y columna, en las celdas que admiten color propio.
  final Shot? shot;
  final String? column;

  const _Cell({
    required this.width,
    required this.child,
    this.padding = const EdgeInsets.all(6),
    this.alignment = Alignment.topLeft,
    this.shot,
    this.column,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (width == 0) return const SizedBox.shrink();
    final sheet = ScriptSheet.of(context);
    final shot = this.shot;
    final column = this.column;
    final fill = shot == null || column == null
        ? null
        : sheet.rowFill(_cellStyles(shot)[column]);
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: shot == null || column == null
          ? null
          : (focused) {
              if (focused) {
                ref.read(_activeCellProvider.notifier).state = (
                  shotId: shot.id,
                  column: column,
                );
              }
            },
      child: Builder(
        builder: (context) {
          // Depender del foco así repinta la celda sin `setState`.
          final focused = Focus.of(context).hasFocus;
          return Container(
            width: width,
            padding: padding,
            color: fill,
            foregroundDecoration: BoxDecoration(
              border: focused
                  ? Border.all(color: sheet.accent, width: 2)
                  : Border(right: sheet.side),
            ),
            child: Align(alignment: alignment, child: child),
          );
        },
      ),
    );
  }
}

const double _kRowMinHeight = 96;

/// Plano que se está arrastrando para cambiarlo de sitio en su escena.
class _ShotDrag {
  final int shotId;
  final int sceneId;
  const _ShotDrag({required this.shotId, required this.sceneId});
}

/// Hueco donde soltar un plano, de esta escena o de otra: delante de
/// [child]. Marca con una línea de acento dónde va a caer.
class _ShotDropTarget extends StatelessWidget {
  final int sceneId;

  /// Plano de esta fila; nulo en el hueco del final de la escena.
  final int? shotId;
  final ValueChanged<_ShotDrag> onDrop;
  final Widget child;

  const _ShotDropTarget({
    super.key,
    required this.sceneId,
    required this.shotId,
    required this.onDrop,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DragTarget<_ShotDrag>(
      onWillAcceptWithDetails: (d) => d.data.shotId != shotId,
      onAcceptWithDetails: (d) => onDrop(d.data),
      builder: (context, candidates, rejected) => DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: candidates.isEmpty
              ? null
              : Border(top: BorderSide(color: palette.accent, width: 3)),
        ),
        child: child,
      ),
    );
  }
}

/// Valor de una lista (movimiento, ángulo) como texto de la hoja: al tocarlo
/// abre sus opciones, con «＋» para añadir una propia.
class _OptionText extends ConsumerWidget {
  final String? value;
  final String hint;

  /// true = movimiento de cámara; false = ángulo.
  final bool movement;
  final ValueChanged<String?> onChanged;

  const _OptionText({
    required this.value,
    required this.hint,
    required this.movement,
    required this.onChanged,
  });

  static const _none = '\u0000none';
  static const _add = '\u0000add';

  Future<void> _addNew(BuildContext context, WidgetRef ref) async {
    final palette = context.palette;
    final ctrl = TextEditingController();
    final what = movement ? 'movimiento' : 'ángulo';
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surfaceElevated,
        title: Text('Nuevo $what', style: AppTypography.titleMedium(palette)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          style: AppTypography.bodyLarge(palette),
          decoration: InputDecoration(
            hintText: movement ? 'Ej. CAMERA CAR, SLIDER' : 'Ej. Holandés',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: AppTypography.bodyMedium(palette)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
    if (name == null) return;
    final notifier = ref.read(technicalScriptSettingsProvider.notifier);
    final saved = movement
        ? await notifier.addMovement(name, kMovements)
        : await notifier.addAngle(name, kAngles);
    if (saved != null) onChanged(saved);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final sheet = ScriptSheet.of(context);
    final custom = ref.watch(
      technicalScriptSettingsProvider.select(
        (s) => movement ? s.customMovements : s.customAngles,
      ),
    );
    final builtIn = movement ? kMovements : kAngles;
    final current = (value ?? '').trim();
    final menuText = AppTypography.bodyMedium(palette);

    return PopupMenuButton<String>(
      tooltip: hint,
      padding: EdgeInsets.zero,
      position: PopupMenuPosition.under,
      color: palette.surfaceElevated,
      onSelected: (v) {
        if (v == _add) {
          _addNew(context, ref);
        } else {
          onChanged(v == _none ? null : v);
        }
      },
      itemBuilder: (menuContext) => [
        for (final o in {
          ...builtIn,
          ...custom,
          if (current.isNotEmpty) current,
        })
          PopupMenuItem(
            value: o,
            height: 36,
            child: Row(
              children: [
                Expanded(child: Text(o, style: menuText)),
                if (custom.contains(o))
                  InkResponse(
                    radius: 14,
                    onTap: () {
                      Navigator.pop(menuContext);
                      final notifier = ref.read(
                        technicalScriptSettingsProvider.notifier,
                      );
                      movement
                          ? notifier.removeMovement(o)
                          : notifier.removeAngle(o);
                    },
                    child: Tooltip(
                      message: 'Quitar de la lista',
                      child: Icon(
                        Icons.close,
                        size: 14,
                        color: palette.textTertiary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _add,
          height: 36,
          child: Row(
            children: [
              Icon(Icons.add, size: 16, color: palette.accent),
              const SizedBox(width: 6),
              Text(
                movement ? 'Añadir movimiento…' : 'Añadir ángulo…',
                style: menuText.copyWith(color: palette.accent),
              ),
            ],
          ),
        ),
        if (current.isNotEmpty)
          PopupMenuItem(
            value: _none,
            height: 36,
            child: Text(
              'Quitar',
              style: menuText.copyWith(color: palette.textSecondary),
            ),
          ),
      ],
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
          child: Text(
            current.isEmpty ? hint : current,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: current.isEmpty ? sheet.hintText : sheet.text,
          ),
        ),
      ),
    );
  }
}

/// Fila de un plano.
class _ShotRow extends ConsumerStatefulWidget {
  final Shot shot;
  final Scene scene;
  final _Cols cols;

  const _ShotRow({required this.shot, required this.scene, required this.cols});

  @override
  ConsumerState<_ShotRow> createState() => _ShotRowState();
}

class _ShotRowState extends ConsumerState<_ShotRow> {
  /// Con el ratón encima, el asa y las acciones se ven del todo.
  final _hovered = ValueNotifier(false);

  @override
  void dispose() {
    _hovered.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.read(databaseProvider);
    final palette = context.palette;
    final sheet = ScriptSheet.of(context);
    final shot = widget.shot;
    final scene = widget.scene;
    final cols = widget.cols;
    final active = ref.watch(_activeShotProvider.select((id) => id == shot.id));
    // Si otro equipo edita este plano: quién y lo que va escribiendo.
    final lock = ref.watch(
      liveEditingProvider.select((l) => _RowLock.of(l, shot.uid)),
    );
    final live = ref.read(liveEditingProvider);

    Widget field({
      required String column,
      required String? value,
      required String hintText,
      required ValueChanged<String> onChanged,
      int minLines = 1,
      TextAlign align = TextAlign.start,
      bool rich = false,
    }) => EditableCell(
      rich: rich,
      value: value,
      hint: hintText,
      style: sheet.text,
      hintStyle: sheet.hintText,
      minLines: minLines,
      textAlign: align,
      onChanged: onChanged,
      onTyping: (text) => live.typing(shot.uid, column, text),
      onEditEnd: () => live.typingEnd(shot.uid, column),
      liveText: lock?.typing[column],
      liveColor: _kPeerColor,
    );

    void write(ShotsCompanion fields) => writeShotFields(
      db,
      ref.read(editHistoryProvider),
      shot.id,
      fields,
      label: 'plano ${shot.number}',
    );

    Widget side(Widget child) => ValueListenableBuilder<bool>(
      valueListenable: _hovered,
      builder: (context, hovered, child) => AnimatedOpacity(
        opacity: hovered || active ? 1 : 0.35,
        duration: const Duration(milliseconds: 120),
        child: child,
      ),
      child: child,
    );

    final sheetRow = Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) {
        if (focused) {
          ref.read(_activeShotProvider.notifier).state = shot.id;
          // Los demás equipos lo ven bloqueado mientras se trabaja en él.
          live.focusShot(shot.uid);
        } else {
          live.blurShot(shot.uid);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: sheet.rowFill(shot.notesHighlight) ?? sheet.paper,
          border: Border(left: sheet.side, bottom: sheet.side),
        ),
        child: IntrinsicHeight(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _kRowMinHeight),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Cell(
                  width: cols.esc,
                  alignment: Alignment.center,
                  child: Text(scene.label, style: sheet.text),
                ),
                _Cell(
                  width: cols.plano,
                  alignment: Alignment.center,
                  child: Text('${shot.number}', style: sheet.text),
                ),
                _Cell(
                  width: cols.encuadre,
                  shot: shot,
                  column: 'encuadre',
                  alignment: Alignment.center,
                  child: field(
                    column: 'encuadre',
                    value: shot.framing,
                    hintText: 'PD, PMC...',
                    rich: true,
                    align: TextAlign.center,
                    onChanged: (v) => write(ShotsCompanion(framing: Value(v))),
                  ),
                ),
                _Cell(
                  width: cols.lens,
                  shot: shot,
                  column: 'lens',
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      field(
                        column: 'lens',
                        value: shot.lens,
                        hintText: '50mm',
                        align: TextAlign.center,
                        onChanged: (v) => write(ShotsCompanion(lens: Value(v))),
                      ),
                      _OptionText(
                        value: shot.angle,
                        hint: 'Ángulo',
                        movement: false,
                        onChanged: (v) =>
                            write(ShotsCompanion(angle: Value(v))),
                      ),
                      _OptionText(
                        value: shot.movement,
                        hint: 'Movimiento',
                        movement: true,
                        onChanged: (v) =>
                            write(ShotsCompanion(movement: Value(v))),
                      ),
                    ],
                  ),
                ),
                _Cell(
                  width: cols.fStop,
                  shot: shot,
                  column: 'f',
                  alignment: Alignment.center,
                  child: field(
                    column: 'f',
                    value: shot.fStop,
                    hintText: 'T2.8',
                    align: TextAlign.center,
                    onChanged: (v) => write(ShotsCompanion(fStop: Value(v))),
                  ),
                ),
                _Cell(
                  width: cols.personajes,
                  shot: shot,
                  column: 'pers',
                  child: field(
                    column: 'pers',
                    value: decodeSceneCharacters(
                      shot.charactersJson,
                    ).join(', '),
                    hintText: 'Ana, Luis…',
                    minLines: 2,
                    onChanged: (v) => write(
                      ShotsCompanion(
                        charactersJson: Value(
                          encodeSceneCharacters(parseCharactersInput(v)),
                        ),
                      ),
                    ),
                  ),
                ),
                _Cell(
                  width: cols.duracion,
                  shot: shot,
                  column: 'dur',
                  alignment: Alignment.center,
                  child: field(
                    column: 'dur',
                    value: shot.durationSeconds?.toString(),
                    hintText: 'seg',
                    align: TextAlign.center,
                    onChanged: (v) => write(
                      ShotsCompanion(
                        durationSeconds: Value(int.tryParse(v.trim())),
                      ),
                    ),
                  ),
                ),
                _Cell(
                  width: cols.action,
                  shot: shot,
                  column: 'action',
                  child: field(
                    column: 'action',
                    value: shot.action,
                    hintText: 'Descripción de la acción...',
                    rich: true,
                    minLines: 3,
                    onChanged: (v) => write(ShotsCompanion(action: Value(v))),
                  ),
                ),
                _Cell(
                  width: cols.referencia,
                  padding: const EdgeInsets.all(4),
                  child: SizedBox(
                    width: double.infinity,
                    child: _ShotImageCell(shot: shot),
                  ),
                ),
                _Cell(
                  width: cols.storyboard,
                  padding: const EdgeInsets.all(4),
                  child: SizedBox(
                    width: double.infinity,
                    child: _ShotImageCell(
                      shot: shot,
                      target: ShotImageTarget.storyboard,
                    ),
                  ),
                ),
                _Cell(
                  width: cols.planta,
                  padding: const EdgeInsets.all(4),
                  child: SizedBox(
                    width: double.infinity,
                    child: _PlanCell(shot: shot, scene: scene),
                  ),
                ),
                _Cell(
                  width: cols.apuntes,
                  shot: shot,
                  column: 'notes',
                  child: field(
                    column: 'notes',
                    value: shot.notes,
                    hintText: 'Apuntes...',
                    rich: true,
                    minLines: 3,
                    onChanged: (v) => write(ShotsCompanion(notes: Value(v))),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final content = MouseRegion(
      onEnter: (_) => _hovered.value = true,
      onExit: (_) => _hovered.value = false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: cols.handle,
            child: side(
              Draggable<_ShotDrag>(
                data: _ShotDrag(shotId: shot.id, sceneId: scene.id),
                axis: Axis.vertical,
                dragAnchorStrategy: pointerDragAnchorStrategy,
                // El texto a medias se guarda antes de mover la fila.
                onDragStarted: () =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                feedback: Material(
                  color: palette.surfaceElevated,
                  elevation: 6,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      'Plano ${shot.number}'
                      '${scriptMarkupToPlain(shot.framing).trim().isEmpty ? '' : ' · ${scriptMarkupToPlain(shot.framing).trim()}'}',
                      style: AppTypography.bodyMedium(
                        palette,
                      ).copyWith(color: palette.textPrimary),
                    ),
                  ),
                ),
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Tooltip(
                    message: 'Arrastra para cambiar el orden',
                    child: SizedBox(
                      width: cols.handle,
                      height: 36,
                      child: Icon(
                        Icons.drag_indicator,
                        size: 18,
                        color: active ? palette.accent : palette.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          sheetRow,
          SizedBox(
            width: cols.acciones - sheet.lineWidth,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: side(
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MoveShotButton(shot: shot),
                    const SizedBox(height: 10),
                    _DeleteShotButton(shot: shot),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (lock == null) return content;
    return _LockedShot(device: lock.device, child: content);
  }
}

/// Miniatura de la planta del plano. Al tocarla abre la planta; si la escena
/// aún no tiene set, lleva a la localización para elegirlo o crearlo. Admite
/// además bocetos: imágenes que hacen de planta mientras no está dibujada.
class _PlanCell extends ConsumerWidget {
  final Shot shot;
  final Scene scene;

  const _PlanCell({required this.shot, required this.scene});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sheet = ScriptSheet.of(context);
    final data = _PlanDataScope.of(context);
    final setId = shot.locationBasePlanId ?? scene.locationId;
    final own = [...data.lightOfShot(shot), ...data.ownOfShot(shot)];
    final base = data.baseOfShot(shot);
    final drawings = data.drawingsOfShot(shot);
    // Planta, boceto o las dos: lo que diga la tabla o, si la tiene, la
    // excepción de este plano.
    final view = ScriptPlanView.of(
      shot.cellStylesJson,
      ref.watch(technicalScriptSettingsProvider.select((s) => s.planView)),
    );
    final hasDrawing =
        view.showsPlan &&
        (own.isNotEmpty || base.isNotEmpty || drawings.isNotEmpty);

    final String caption;
    final IconData icon;
    if (setId != null) {
      caption = 'Abrir planta';
      icon = Icons.grid_on_outlined;
    } else if (scene.locationSiteId != null) {
      caption = 'Elegir set';
      icon = Icons.add_location_alt_outlined;
    } else {
      caption = 'Elegir localización';
      icon = Icons.add_location_alt_outlined;
    }

    // Sin localización o sin set, la planta guía: localización › sets ›
    // planos, y al final abre la de este plano.
    void open() => openShotPlan(
      context,
      ProviderScope.containerOf(context).read(databaseProvider),
      shot,
      label: 'Esc ${scene.label} · Plano ${shot.number}',
    );

    // Imágenes y bocetos dibujados que el plano ha elegido enseñar.
    final sketches = [
      for (final entry
          in view.showsSketch ? planSketchEntriesOf(shot) : const <String>[])
        if (planSketchSetupId(entry) case final id?)
          if (data.setup(id) != null) entry else ...const <String>[]
        else
          entry,
    ];
    void sketchMenu() => showShotImageMenu(
      context,
      shot,
      target: ShotImageTarget.planSketch,
      sketches: planSketchDelegate,
      footer: (_) => _PlanViewChoice(shotId: shot.id),
    );

    Widget tappable(String message, VoidCallback onTap, Widget child) {
      return Tooltip(
        message: message,
        child: GestureDetector(
          onTap: onTap,
          child: MouseRegion(cursor: SystemMouseCursors.click, child: child),
        ),
      );
    }

    // La planta dibujada, o su hueco. Con bocetos y sin dibujo, el hueco se
    // queda en una línea: lo que se ve es el boceto.
    final Widget plan;
    if (hasDrawing) {
      plan = SizedBox(
        height: 84,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: PlanThumbnail(
            elements: own,
            inherited: base,
            drawings: drawings,
            focus: data.zoneOf(data.set(setId)),
            emptyIcon: Icons.videocam_outlined,
          ),
        ),
      );
    } else if (sketches.isNotEmpty) {
      plan = Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: sheet.hint, size: 13),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: sheet.hintText.copyWith(fontSize: 11),
              ),
            ),
          ],
        ),
      );
    } else {
      plan = SizedBox(
        height: 84,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: sheet.tile,
            border: Border.all(color: sheet.tileBorder),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: sheet.hint, size: 20),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  caption,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: sheet.hintText.copyWith(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final planTile = tappable(caption, open, plan);

    return ShotImagePasteTarget(
      shot: shot,
      target: ShotImageTarget.planSketch,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sketches.isEmpty || hasDrawing)
            Stack(
              children: [
                planTile,
                // Sin bocetos aún: la entrada para poner el primero.
                if (sketches.isEmpty)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: tappable(
                      'Añadir un boceto de planta (imagen)',
                      sketchMenu,
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: sheet.tile.withValues(alpha: 0.9),
                          border: Border.all(color: sheet.tileBorder),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 14,
                          color: sheet.hint,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          for (final (i, sketch) in sketches.indexed) ...[
            if (i > 0 || hasDrawing) const SizedBox(height: 4),
            tappable(
              'Boceto de planta · clic para añadir o quitar',
              sketchMenu,
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 84,
                  child: switch (planSketchSetupId(sketch)) {
                    final id? => PlanSketchThumbnail(
                      data: data,
                      setup: data.setup(id)!,
                    ),
                    null => Image.file(File(sketch), fit: BoxFit.contain),
                  },
                ),
              ),
            ),
          ],
          if (sketches.isNotEmpty && !hasDrawing) planTile,
        ],
      ),
    );
  }
}

/// En el menú de la casilla Planta: qué enseña este plano, si no es lo que
/// dice la tabla.
class _PlanViewChoice extends ConsumerWidget {
  final int shotId;

  const _PlanViewChoice({required this.shotId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);
    final general = ref.watch(
      technicalScriptSettingsProvider.select((s) => s.planView),
    );
    return StreamBuilder<Shot?>(
      stream: (db.select(
        db.shots,
      )..where((s) => s.id.equals(shotId))).watchSingleOrNull(),
      builder: (context, snap) {
        final shot = snap.data;
        if (shot == null) return const SizedBox.shrink();
        final own = ScriptPlanView.parse(
          _cellStyles(shot)[ScriptPlanView.shotKey],
        );

        Future<void> choose(ScriptPlanView? value) async {
          final styles = {..._cellStyles(shot)};
          value == null
              ? styles.remove(ScriptPlanView.shotKey)
              : styles[ScriptPlanView.shotKey] = value.name;
          await writeShotFields(
            db,
            ref.read(editHistoryProvider),
            shotId,
            ShotsCompanion(
              cellStylesJson: Value(styles.isEmpty ? null : jsonEncode(styles)),
            ),
            label: 'qué enseña la planta del plano ${shot.number}',
          );
        }

        return Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'En este plano se ve:',
              style: AppTypography.bodyMedium(palette),
            ),
            SizedBox(
              width: 250,
              child: DropdownButton<ScriptPlanView?>(
                value: own,
                isDense: true,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                dropdownColor: palette.surfaceElevated,
                onChanged: choose,
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(
                      'Como la tabla (${general.label.toLowerCase()})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  for (final v in ScriptPlanView.values)
                    DropdownMenuItem(
                      value: v,
                      child: Text(v.label, overflow: TextOverflow.ellipsis),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// En una escena que ya no está en el guion: llevarse todos sus planos a
/// otra, para poder eliminarla sin perder trabajo.
class _MoveAllShotsButton extends ConsumerWidget {
  final Scene scene;
  final int shotCount;

  const _MoveAllShotsButton({required this.scene, required this.shotCount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final others = [
      for (final s in _PlanDataScope.of(context).scenes)
        if (s.id != scene.id && !s.offScript) s,
    ];
    return PopupMenuButton<int>(
      tooltip: 'Pasar todos sus planos a otra escena',
      enabled: shotCount > 0 && others.isNotEmpty,
      color: palette.surfaceElevated,
      onSelected: (target) =>
          ref.read(databaseProvider).moveAllShotsToScene(scene.id, target),
      itemBuilder: (_) => [
        for (final s in others)
          PopupMenuItem(
            value: s.id,
            height: 36,
            child: Text(
              '${s.number}. ${s.locationCanonical}',
              style: AppTypography.bodyMedium(palette),
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          Icons.drive_file_move_outline,
          size: 18,
          color: shotCount > 0 ? palette.textSecondary : palette.textTertiary,
        ),
      ),
    );
  }
}

/// Fuera de la hoja: pasar el plano a otra escena.
class _MoveShotButton extends ConsumerWidget {
  final Shot shot;

  const _MoveShotButton({required this.shot});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final scenes = _PlanDataScope.of(context).scenes;
    final others = [
      for (final s in scenes)
        if (s.id != shot.sceneId) s,
    ];
    return PopupMenuButton<int>(
      tooltip: 'Mover a otra escena',
      padding: EdgeInsets.zero,
      enabled: others.isNotEmpty,
      color: palette.surfaceElevated,
      onSelected: (sceneId) =>
          ref.read(databaseProvider).moveShotToScene(shot.id, sceneId),
      itemBuilder: (_) => [
        for (final s in others)
          PopupMenuItem(
            value: s.id,
            height: 36,
            child: Text(
              '${s.number}. ${s.locationCanonical}'
              '${s.offScript ? ' · fuera del guion' : ''}',
              style: AppTypography.bodyMedium(palette),
            ),
          ),
      ],
      child: Icon(
        Icons.drive_file_move_outline,
        size: 18,
        color: others.isEmpty ? palette.textTertiary : palette.textSecondary,
      ),
    );
  }
}

/// Fuera de la hoja: eliminar el plano.
class _DeleteShotButton extends ConsumerWidget {
  final Shot shot;

  const _DeleteShotButton({required this.shot});

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await _confirmDelete(
      context,
      title: 'Eliminar el plano ${shot.number}',
      body:
          'Se borran también sus referencias y su planta, y se quita de los '
          'documentos de rodaje. Los planos siguientes se renumeran.',
    );
    if (!ok) return;
    try {
      await ref.read(databaseProvider).deleteShot(shot.id);
    } catch (e) {
      if (context.mounted) AppSnackBar.showError(context, userFriendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    return Tooltip(
      message: 'Eliminar plano',
      child: InkResponse(
        onTap: () => _delete(context, ref),
        radius: 14,
        child: Icon(
          Icons.delete_outline,
          size: 18,
          color: palette.textSecondary,
        ),
      ),
    );
  }
}

/// Imagen de referencia o de storyboard del plano; tocarla abre su menú.
class _ShotImageCell extends ConsumerWidget {
  final Shot shot;
  final ShotImageTarget target;

  const _ShotImageCell({
    required this.shot,
    this.target = ShotImageTarget.reference,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sheet = ScriptSheet.of(context);
    final story = target == ShotImageTarget.storyboard;
    final own = story ? shot.storyboardImagePath : shot.referenceImagePath;
    final path = story ? storyboardImageOf(shot) : referenceImageOf(shot);
    final hasImage = path != null && File(path).existsSync();
    // Sin imagen propia se enseña la del otro uso, con su rótulo.
    final inherited = hasImage && own == null;
    final single = _body(context, sheet, story, path, hasImage, inherited);

    return ShotImagePasteTarget(
      shot: shot,
      target: target,
      // La referencia puede llevar varias imágenes, una por encuadre: se
      // enseñan todas, una debajo de otra.
      child: story
          ? single
          : StreamBuilder<List<ShotReference>>(
              stream: ref
                  .watch(databaseProvider)
                  .watchReferencesForShot(shot.id),
              builder: (context, snap) {
                final paths = referenceImagesOf(shot, snap.data ?? const []);
                if (paths.length < 2) return single;
                return GestureDetector(
                  onTap: () => showShotImageMenu(context, shot, target: target),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final (i, image) in paths.indexed) ...[
                        if (i > 0) const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            height: 84,
                            width: double.infinity,
                            child: Image.file(File(image), fit: BoxFit.contain),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _body(
    BuildContext context,
    ScriptSheetTheme sheet,
    bool story,
    String? path,
    bool hasImage,
    bool inherited,
  ) {
    return GestureDetector(
      onTap: () => showShotImageMenu(context, shot, target: target),
      child: Container(
        height: 84,
        decoration: BoxDecoration(
          color: hasImage ? null : sheet.tile,
          border: hasImage ? null : Border.all(color: sheet.tileBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        clipBehavior: Clip.antiAlias,
        child: hasImage
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(File(path!), fit: BoxFit.contain),
                  if (inherited)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.55),
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          story ? 'de la referencia' : 'del storyboard',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    color: sheet.hint,
                    size: 20,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    story ? 'Story' : 'Ref.',
                    style: sheet.hintText.copyWith(fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    );
  }
}
