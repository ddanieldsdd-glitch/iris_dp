import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/shot_reference_import.dart';
import '../../shared/rich_text/script_markup.dart';
import '../camera_plan/plan_renderer.dart';
import 'shoot_day_timeline.dart';
import 'shoot_day_widgets.dart';

/// Duraciones que se ponen de un toque.
const shootDurationPresets = [5, 10, 15, 20, 30, 45, 60, 90, 120];

/// Lo que se elige en el chip de duración.
sealed class ShootDurationPick {
  const ShootDurationPick();
}

class ShootDurationSet extends ShootDurationPick {
  /// Nula para quitarla.
  final int? minutes;
  const ShootDurationSet(this.minutes);
}

class ShootDurationPin extends ShootDurationPick {
  /// «HH:mm», o nula para soltar la hora y volver a encadenar.
  final String? at;
  const ShootDurationPin(this.at);
}

/// La hora y la duración de una línea del orden, a la izquierda de la fila:
/// «10:15» arriba y el chip «30 min» debajo. Tocarlo cambia la duración o
/// fija la hora, sin hojas ni «Guardar».
class ShootTimeColumn extends StatelessWidget {
  final ShootSpan? span;
  final int? minutes;
  final bool pinned;

  /// Si se puede fijar la hora (las franjas y las escenas; los planos van
  /// seguidos dentro de su escena).
  final bool canPin;

  /// La duración la dan sus planos: no se escribe a mano.
  final bool fromShots;
  final String? warning;
  final ValueChanged<ShootDurationPick> onPick;
  final double width;

  const ShootTimeColumn({
    super.key,
    required this.span,
    required this.minutes,
    required this.onPick,
    this.pinned = false,
    this.canPin = true,
    this.fromShots = false,
    this.warning,
    this.width = 64,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final warn = warning != null;
    final color = warn ? const Color(0xFFF2B84B) : palette.accent;
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tooltip(
            message: warning ?? (pinned ? 'Hora fijada' : 'Hora calculada'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pinned)
                  Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: Icon(Icons.push_pin, size: 11, color: color),
                  ),
                if (warn)
                  const Padding(
                    padding: EdgeInsets.only(right: 2),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      size: 12,
                      color: Color(0xFFF2B84B),
                    ),
                  ),
                Flexible(
                  child: Text(
                    span == null ? '—' : formatClock(span!.start),
                    style: AppTypography.mono(palette).copyWith(
                      color: span == null ? palette.textTertiary : color,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (span != null && span!.end != span!.start)
            Text(
              formatClock(span!.end),
              style: AppTypography.mono(
                palette,
              ).copyWith(color: palette.textTertiary, fontSize: 11),
            ),
          const SizedBox(height: 4),
          ShootDurationChip(
            minutes: minutes,
            pinned: pinned,
            canPin: canPin,
            fromShots: fromShots,
            pinnedAt: span == null ? null : formatClock(span!.start),
            onPick: onPick,
          ),
        ],
      ),
    );
  }
}

/// «30 min» o «+ tiempo»: abre el menú de duraciones.
class ShootDurationChip extends StatelessWidget {
  final int? minutes;
  final bool pinned;
  final bool canPin;
  final bool fromShots;
  final String? pinnedAt;
  final ValueChanged<ShootDurationPick> onPick;
  final bool dense;

  const ShootDurationChip({
    super.key,
    required this.minutes,
    required this.onPick,
    this.pinned = false,
    this.canPin = true,
    this.fromShots = false,
    this.pinnedAt,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final has = minutes != null;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _open(context),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 6 : 7,
          vertical: dense ? 1 : 2,
        ),
        decoration: BoxDecoration(
          color: has
              ? palette.accent.withValues(alpha: 0.14)
              : palette.surfaceOverlay,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: has ? palette.accent.withValues(alpha: 0.4) : palette.border,
          ),
        ),
        child: Text(
          has ? formatDuration(minutes!) : '+ tiempo',
          maxLines: 1,
          style: AppTypography.caption(palette).copyWith(
            fontSize: dense ? 10.5 : 11,
            color: has ? palette.textPrimary : palette.textSecondary,
            fontWeight: has ? FontWeight.w600 : null,
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final rect = RelativeRect.fromRect(
      box.localToGlobal(Offset.zero, ancestor: overlay) & box.size,
      Offset.zero & overlay.size,
    );
    final palette = context.palette;
    final picked = await showMenu<Object>(
      context: context,
      position: rect,
      items: [
        if (fromShots)
          PopupMenuItem<Object>(
            enabled: false,
            child: Text(
              'La suma de sus planos. Pon el tiempo en cada plano.',
              style: AppTypography.caption(palette),
            ),
          )
        else ...[
          PopupMenuItem<Object>(
            enabled: false,
            height: 36,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in shootDurationPresets)
                  ChoiceChip(
                    label: Text(formatDuration(m)),
                    selected: minutes == m,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) =>
                        Navigator.pop(context, ShootDurationSet(m)),
                  ),
              ],
            ),
          ),
          if (minutes != null) ...[
            PopupMenuItem<Object>(
              value: ShootDurationSet(minutes! + 5),
              child: const Text('+5 min'),
            ),
            if (minutes! > 5)
              PopupMenuItem<Object>(
                value: ShootDurationSet(minutes! - 5),
                child: const Text('−5 min'),
              ),
          ],
          const PopupMenuItem<Object>(value: 'other', child: Text('Otra…')),
          if (minutes != null)
            const PopupMenuItem<Object>(
              value: ShootDurationSet(null),
              child: Text('Quitar tiempo'),
            ),
        ],
        if (canPin) ...[
          const PopupMenuDivider(),
          if (pinned)
            const PopupMenuItem<Object>(
              value: ShootDurationPin(null),
              child: Text('Soltar la hora (seguir a lo anterior)'),
            )
          else
            const PopupMenuItem<Object>(
              value: 'pin',
              child: Text('Fijar hora…'),
            ),
          if (pinned)
            const PopupMenuItem<Object>(
              value: 'pin',
              child: Text('Cambiar la hora fijada…'),
            ),
        ],
      ],
    );
    if (!context.mounted || picked == null) return;
    switch (picked) {
      case final ShootDurationPick pick:
        onPick(pick);
      case 'other':
        final value = await _askMinutes(context, minutes);
        if (value != null) onPick(ShootDurationSet(value));
      case 'pin':
        final at = await pickClockTime(
          context,
          current: pinnedAt,
          fallback: '14:00',
          help: 'Empieza a las',
        );
        if (at != null) onPick(ShootDurationPin(at));
    }
  }
}

/// Minutos escritos a mano: «40», «1:30» o «1h30».
int? parseDurationText(String text) {
  final t = text.trim().toLowerCase().replaceAll(' ', '');
  if (t.isEmpty) return null;
  final hm = RegExp(r'^(\d+)(?:[:h])(\d{0,2})(?:m|min)?$').firstMatch(t);
  if (hm != null) {
    final h = int.parse(hm.group(1)!);
    final m = hm.group(2)!.isEmpty ? 0 : int.parse(hm.group(2)!);
    return h * 60 + m;
  }
  final m = RegExp(r'^(\d+)(?:m|min)?$').firstMatch(t);
  return m == null ? null : int.parse(m.group(1)!);
}

Future<int?> _askMinutes(BuildContext context, int? current) {
  final controller = TextEditingController(
    text: current == null ? '' : '$current',
  );
  return showDialog<int>(
    context: context,
    builder: (ctx) {
      void submit() {
        final v = parseDurationText(controller.text);
        if (v != null && v > 0) Navigator.pop(ctx, v);
      }

      return AlertDialog(
        title: const Text('Cuánto dura'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.text,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9:hm ]')),
          ],
          decoration: const InputDecoration(
            hintText: '40, 1:30 o 1h30',
            suffixText: 'min',
          ),
          onSubmitted: (_) => submit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(onPressed: submit, child: const Text('Poner')),
        ],
      );
    },
  );
}

/// Lo que implica un plano, al tocarlo en el orden: su planta, su
/// storyboard y referencias, lo técnico y su tiempo.
class ShootShotPanel extends ConsumerStatefulWidget {
  final int projectId;
  final Shot shot;
  final String sceneTitle;
  final ShootSpan? span;
  final int? minutes;
  final ValueChanged<ShootDurationPick> onPick;
  final VoidCallback? onClose;

  const ShootShotPanel({
    super.key,
    required this.projectId,
    required this.shot,
    required this.sceneTitle,
    required this.span,
    required this.minutes,
    required this.onPick,
    this.onClose,
  });

  @override
  ConsumerState<ShootShotPanel> createState() => _ShootShotPanelState();
}

class _ShootShotPanelState extends ConsumerState<ShootShotPanel> {
  // Las plantas del proyecto se cargan una vez mientras el panel esté abierto.
  Future<PlanRenderer>? _renderer;
  Future<Uint8List?>? _plan;
  Future<List<String>>? _images;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ShootShotPanel old) {
    super.didUpdateWidget(old);
    if (old.shot != widget.shot) _load();
  }

  void _load() {
    final db = ref.read(databaseProvider);
    final shot = widget.shot;
    final renderer = _renderer ??= PlanRenderer.load(db, widget.projectId);
    _plan = renderer.then(
      (r) => r.shot(shot, size: const Size(420, 300), pixelRatio: 2),
    );
    _images = db.getReferencesForShot(shot.id).then((refs) {
      final paths = <String>[
        ?storyboardImageOf(shot),
        ...referenceImagesOf(shot, refs),
      ];
      final seen = <String>{};
      return [
        for (final p in paths)
          if (seen.add(p) && File(p).existsSync()) p,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final shot = widget.shot;
    String plain(String? s) => scriptMarkupToPlain(s).trim();
    final tech = [
      plain(shot.lens),
      plain(shot.movement),
      plain(shot.angle),
      if (plain(shot.fStop).isNotEmpty) 'T${plain(shot.fStop)}',
    ].where((s) => s.isNotEmpty).join(' · ');
    final action = plain(shot.action);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.sceneTitle,
                    style: AppTypography.caption(
                      palette,
                    ).copyWith(color: palette.accent),
                  ),
                  Text(
                    shootShotTitle(shot),
                    style: AppTypography.titleMedium(palette),
                  ),
                ],
              ),
            ),
            if (widget.onClose != null)
              IconButton(
                tooltip: 'Cerrar',
                icon: const Icon(Icons.close, size: 18),
                onPressed: widget.onClose,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Text(
              widget.span == null
                  ? 'Sin hora'
                  : shootTimeRange(
                      formatClock(widget.span!.start),
                      formatClock(widget.span!.end),
                    ),
              style: AppTypography.mono(
                palette,
              ).copyWith(color: palette.accent, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: AppSpacing.sm),
            ShootDurationChip(
              minutes: widget.minutes,
              canPin: false,
              onPick: widget.onPick,
            ),
          ],
        ),
        if (tech.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(tech, style: AppTypography.bodyMedium(palette)),
        ],
        const SizedBox(height: AppSpacing.md),
        Text('Planta', style: AppTypography.label(palette)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: AspectRatio(
            aspectRatio: 420 / 300,
            child: FutureBuilder<Uint8List?>(
              future: _plan,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return ColoredBox(
                    color: palette.surfaceOverlay,
                    child: const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                final bytes = snap.data;
                return bytes == null
                    ? ColoredBox(
                        color: palette.surfaceOverlay,
                        child: Center(
                          child: Text(
                            'Este plano aún no tiene planta.',
                            style: AppTypography.caption(palette),
                          ),
                        ),
                      )
                    : Image.memory(bytes, fit: BoxFit.contain);
              },
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Storyboard y referencias', style: AppTypography.label(palette)),
        const SizedBox(height: 6),
        FutureBuilder<List<String>>(
          future: _images,
          builder: (context, snap) {
            final paths = snap.data ?? const <String>[];
            if (paths.isEmpty) {
              return Text(
                snap.connectionState == ConnectionState.done
                    ? 'Sin imágenes.'
                    : '…',
                style: AppTypography.caption(palette),
              );
            }
            return Column(
              children: [
                for (final p in paths)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(
                        File(p),
                        fit: BoxFit.contain,
                        cacheWidth: 900,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        if (action.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text('Acción', style: AppTypography.label(palette)),
          const SizedBox(height: 4),
          Text(action, style: AppTypography.bodyMedium(palette)),
        ],
      ],
    );
  }
}
