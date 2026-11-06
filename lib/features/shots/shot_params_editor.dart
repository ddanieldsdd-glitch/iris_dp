import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/sync/live_editing.dart';
import '../../core/sync/realtime_hub.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/scene_characters.dart';
import '../../core/utils/shot_technical_options.dart';
import '../../shared/history/edit_history.dart';
import '../../shared/history/shot_edits.dart';
import '../technical_script/table/editable_cell.dart';

/// Abre los datos del plano en una hoja, para editarlos fuera de la tabla.
Future<void> showShotParamsSheet(BuildContext context, Shot shot) {
  final palette = context.palette;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: palette.surfaceElevated,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            'Plano ${shot.number}',
            style: AppTypography.titleLarge(palette),
          ),
          const SizedBox(height: AppSpacing.md),
          ShotParamsEditor(shotId: shot.id),
        ],
      ),
    ),
  );
}

/// Todos los datos de un plano, editables. Escribe en la misma fila que el
/// guion técnico: lo que se cambia aquí se ve al momento en todas partes.
class ShotParamsEditor extends ConsumerStatefulWidget {
  final int shotId;

  const ShotParamsEditor({super.key, required this.shotId});

  @override
  ConsumerState<ShotParamsEditor> createState() => _ShotParamsEditorState();
}

class _ShotParamsEditorState extends ConsumerState<ShotParamsEditor> {
  late final LiveEditing _live = ref.read(liveEditingProvider);
  late final Stream<Shot?> _shot = () {
    final db = ref.read(databaseProvider);
    return (db.select(
      db.shots,
    )..where((s) => s.id.equals(widget.shotId))).watchSingleOrNull();
  }();
  String? _uid;

  @override
  void dispose() {
    if (_uid != null) _live.blurShot(_uid!);
    super.dispose();
  }

  void _claim(Shot shot) {
    final uid = shot.uid;
    if (uid == null || uid == _uid) return;
    _uid = uid;
    // Los demás equipos lo ven bloqueado mientras se trabaja en él.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _live.focusShot(uid);
    });
  }

  Future<void> _save(Shot shot, ShotsCompanion fields) => saveShotFields(
    ref.read(databaseProvider),
    ref.read(editHistoryProvider),
    shot,
    fields,
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Shot?>(
      stream: _shot,
      builder: (context, snap) {
        final shot = snap.data;
        if (shot == null) return const SizedBox.shrink();
        final holder = ref.watch(
          liveEditingProvider.select((l) => l.holderOf(shot.uid)?.device),
        );
        if (holder == null) _claim(shot);
        return _form(context, shot, holder);
      },
    );
  }

  Widget _form(BuildContext context, Shot shot, String? holder) {
    final palette = context.palette;

    Widget text(
      String label,
      String? value,
      String hint,
      ValueChanged<String> onChanged, {
      bool rich = false,
      int minLines = 1,
    }) => _Labeled(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: palette.divider),
          borderRadius: BorderRadius.circular(6),
        ),
        child: EditableCell(
          value: value,
          hint: hint,
          rich: rich,
          minLines: minLines,
          style: AppTypography.bodyMedium(palette),
          hintStyle: AppTypography.bodyMedium(
            palette,
          ).copyWith(color: palette.textTertiary),
          onChanged: onChanged,
        ),
      ),
    );

    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        text(
          'Encuadre',
          shot.framing,
          'PMC de ANA',
          (v) => _save(shot, ShotsCompanion(framing: Value(v))),
          rich: true,
        ),
        LayoutBuilder(
          builder: (context, box) {
            final fields = [
              text(
                'Lente',
                shot.lens,
                '50mm',
                (v) => _save(shot, ShotsCompanion(lens: Value(v))),
              ),
              text(
                'T-stop',
                shot.fStop,
                'T2.8',
                (v) => _save(shot, ShotsCompanion(fStop: Value(v))),
              ),
              text(
                'Obturador',
                shot.shutterAngle,
                '180°',
                (v) => _save(shot, ShotsCompanion(shutterAngle: Value(v))),
              ),
              text(
                'FPS',
                shot.fps?.toString(),
                '24',
                (v) => _save(
                  shot,
                  ShotsCompanion(fps: Value(int.tryParse(v.trim()))),
                ),
              ),
              text(
                'Duración (seg)',
                shot.durationSeconds?.toString(),
                'seg',
                (v) => _save(
                  shot,
                  ShotsCompanion(
                    durationSeconds: Value(int.tryParse(v.trim())),
                  ),
                ),
              ),
            ];
            final columns = box.maxWidth >= 520 ? 3 : 2;
            final width =
                (box.maxWidth - AppSpacing.sm * (columns - 1)) / columns;
            return Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final field in fields)
                  SizedBox(width: width, child: field),
              ],
            );
          },
        ),
        _OptionChips(
          label: 'Ángulo',
          options: kShotAngles,
          value: shot.angle,
          onChanged: (v) => _save(shot, ShotsCompanion(angle: Value(v))),
        ),
        _OptionChips(
          label: 'Movimiento',
          options: kShotMovements,
          value: shot.movement,
          onChanged: (v) => _save(shot, ShotsCompanion(movement: Value(v))),
        ),
        text(
          'Personajes',
          decodeSceneCharacters(shot.charactersJson).join(', '),
          'Ana, Luis…',
          (v) => _save(
            shot,
            ShotsCompanion(
              charactersJson: Value(
                encodeSceneCharacters(parseCharactersInput(v)),
              ),
            ),
          ),
        ),
        text(
          'Acción',
          shot.action,
          'Descripción de la acción...',
          (v) => _save(shot, ShotsCompanion(action: Value(v))),
          rich: true,
          minLines: 2,
        ),
        text(
          'Apuntes',
          shot.notes,
          'Apuntes...',
          (v) => _save(shot, ShotsCompanion(notes: Value(v))),
          rich: true,
          minLines: 2,
        ),
      ],
    );

    if (holder == null) return form;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Lo está editando $holder. Podrás cambiarlo en cuanto termine.',
          style: AppTypography.bodyMedium(palette),
        ),
        const SizedBox(height: AppSpacing.sm),
        IgnorePointer(child: Opacity(opacity: 0.5, child: form)),
      ],
    );
  }
}

class _Labeled extends StatelessWidget {
  final String label;
  final Widget child;

  const _Labeled({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: AppTypography.caption(context.palette)),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

/// Opciones de un parámetro. Un valor escrito a mano en la tabla sale como
/// una opción más, para que no se pierda de vista.
class _OptionChips extends StatelessWidget {
  final String label;
  final List<String> options;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _OptionChips({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final current = value?.trim() ?? '';
    final all = [
      ...options,
      if (current.isNotEmpty && !options.contains(current)) current,
    ];
    return _Labeled(
      label: label,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final option in all)
            ChoiceChip(
              label: Text(option),
              selected: option == current,
              onSelected: (on) => onChanged(on ? option : null),
            ),
        ],
      ),
    );
  }
}
