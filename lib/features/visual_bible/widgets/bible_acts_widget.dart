import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/visual_bible/bible_acts.dart';
import '../../../shared/visual_bible/bible_cards.dart';
import 'bible_point_images.dart';
import 'bible_point_panel.dart';

/// División por actos: cada acto es una tarjeta con su imagen, su número, su
/// fase y su intención, unidas por una línea de progreso.
class BibleActsWidget extends ConsumerWidget {
  final int projectId;
  final int bibleId;
  final String sectionId;
  final List<BibleCard> acts;
  final ValueChanged<List<BibleCard>> onChanged;

  /// Los actos son los del proyecto: el diálogo avisa de que título, fase y
  /// orden cambian en todas las pantallas.
  final bool shared;

  const BibleActsWidget({
    super.key,
    required this.projectId,
    required this.bibleId,
    required this.sectionId,
    required this.acts,
    required this.onChanged,
    this.shared = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return StreamBuilder<List<MoodboardImage>>(
      stream: db.watchMoodboardImages(projectId),
      builder: (context, snap) => BibleActsView(
        acts: acts,
        onChanged: onChanged,
        shared: shared,
        imagePaths: {
          for (final image in snap.data ?? const <MoodboardImage>[])
            image.id: image.imagePath,
        },
        imagesEditor: (ids, onIds) => BiblePointImages(
          projectId: projectId,
          bibleId: bibleId,
          sectionId: sectionId,
          imageIds: ids,
          onChanged: onIds,
        ),
      ),
    );
  }
}

/// Editor de las imágenes de un acto, dentro de su diálogo.
typedef BibleActImagesEditor =
    Widget Function(List<int> imageIds, ValueChanged<List<int>> onChanged);

/// Vista de los actos, sin acceso a datos: recibe las rutas de las imágenes.
class BibleActsView extends StatelessWidget {
  final List<BibleCard> acts;
  final ValueChanged<List<BibleCard>> onChanged;
  final Map<int, String> imagePaths;
  final BibleActImagesEditor? imagesEditor;
  final bool shared;

  const BibleActsView({
    super.key,
    required this.acts,
    required this.onChanged,
    this.imagePaths = const {},
    this.imagesEditor,
    this.shared = false,
  });

  Future<void> _edit(BuildContext context, int? index) async {
    final result = await showDialog<_ActEdit>(
      context: context,
      builder: (_) => _ActDialog(
        // Número que le toca si es un acto y no un punto de giro.
        number:
            BibleCard.actNumbers(
              acts.sublist(0, index ?? acts.length),
            ).whereType<int>().length +
            1,
        act: index == null ? const BibleCard() : acts[index],
        isNew: index == null,
        shared: shared,
        canMoveBack: index != null && index > 0,
        canMoveForward: index != null && index < acts.length - 1,
        imagesEditor: imagesEditor,
      ),
    );
    if (result == null) return;
    final next = [...acts];
    switch (result.action) {
      case _ActAction.delete:
        next.removeAt(index!);
      case _ActAction.save:
        if (index == null) {
          if (result.act.isEmpty) return;
          next.add(result.act);
        } else {
          next[index] = result.act;
        }
      case _ActAction.moveBack:
        next[index!] = result.act;
        next.insert(index - 1, next.removeAt(index));
      case _ActAction.moveForward:
        next[index!] = result.act;
        next.insert(index + 1, next.removeAt(index));
    }
    onChanged(next);
  }

  String? _imagePath(BibleCard act) {
    for (final id in act.imageIds) {
      final path = imagePaths[id];
      if (path != null) return path;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final columns = width >= 720 ? 3 : (width >= 480 ? 2 : 1);
        const gap = AppSpacing.md;
        final cardWidth = (width - gap * (columns - 1)) / columns;
        final numbers = BibleCard.actNumbers(acts);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (acts.isNotEmpty) ...[
              _ActsProgress(numbers: numbers),
              const SizedBox(height: AppSpacing.md),
            ],
            Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (var i = 0; i < acts.length; i++)
                  SizedBox(
                    width: cardWidth,
                    child: _ActCard(
                      number: numbers[i],
                      act: acts[i],
                      imagePath: _imagePath(acts[i]),
                      onTap: () => _edit(context, i),
                    ),
                  ),
                SizedBox(
                  width: cardWidth,
                  child: _AddAct(
                    tall: acts.isNotEmpty,
                    onTap: () => _edit(context, null),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Línea con un nodo por acto: numerado, o un rombo en los puntos de giro.
class _ActsProgress extends StatelessWidget {
  final List<int?> numbers;

  const _ActsProgress({required this.numbers});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final count = numbers.length;
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (numbers[i] == null)
            Transform.rotate(
              angle: 0.785398,
              child: Container(width: 12, height: 12, color: palette.accent),
            )
          else
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: palette.accent, width: 1.5),
              ),
              child: Text(
                '${numbers[i]}',
                style: AppTypography.mono(palette).copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: palette.accent,
                ),
              ),
            ),
          Expanded(
            child: Container(
              height: 1.5,
              color: i == count - 1
                  ? palette.border
                  : palette.accent.withValues(alpha: 0.5),
            ),
          ),
        ],
      ],
    );
  }
}

class _ActCard extends StatelessWidget {
  /// `null` en un punto de giro.
  final int? number;
  final BibleCard act;
  final String? imagePath;
  final VoidCallback onTap;

  const _ActCard({
    required this.number,
    required this.act,
    required this.imagePath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final file = imagePath == null ? null : File(imagePath!);
    final hasImage = file != null && file.existsSync();
    final phase = act.kicker.trim();
    final name = number == null ? 'PUNTO DE GIRO' : 'ACTO $number';

    return Material(
      color: palette.surface.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.borderBright),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasImage)
                      Image.file(file, fit: BoxFit.cover)
                    else
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 20,
                              color: palette.textTertiary,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              number == null ? 'IMAGEN' : 'IMAGEN DEL ACTO',
                              style: BiblePointPanel.labelStyle(
                                palette,
                              ).copyWith(color: palette.textTertiary),
                            ),
                          ],
                        ),
                      ),
                    if (hasImage)
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black87],
                            stops: [0.45, 1],
                          ),
                        ),
                      ),
                    Positioned(
                      left: AppSpacing.md,
                      bottom: AppSpacing.sm,
                      child: Text(
                        number?.toString().padLeft(2, '0') ?? '◆',
                        style: AppTypography.mono(palette).copyWith(
                          fontSize: 40,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          color: hasImage
                              ? Colors.white
                              : palette.accent.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                    if (act.imageIds.length > 1)
                      Positioned(
                        right: AppSpacing.sm,
                        bottom: AppSpacing.sm,
                        child: Text(
                          '+${act.imageIds.length - 1}',
                          style: AppTypography.mono(
                            palette,
                          ).copyWith(fontSize: 11, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
              Container(height: 2, color: palette.accent),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      phase.isEmpty ? name : '$name · ${phase.toUpperCase()}',
                      style: BiblePointPanel.labelStyle(
                        palette,
                      ).copyWith(color: palette.accent),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      act.title.trim().isEmpty ? 'Sin título' : act.title,
                      style: AppTypography.titleMedium(palette).copyWith(
                        color: act.title.trim().isEmpty
                            ? palette.textTertiary
                            : palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      act.body.trim().isEmpty
                          ? 'Toca para escribir la intención…'
                          : act.body,
                      style: AppTypography.bodyMedium(palette).copyWith(
                        height: 1.45,
                        color: act.body.trim().isEmpty
                            ? palette.textTertiary
                            : palette.textSecondary,
                      ),
                    ),
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

class _AddAct extends StatelessWidget {
  final bool tall;
  final VoidCallback onTap;

  const _AddAct({required this.tall, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: BoxConstraints(minHeight: tall ? 140 : 56),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 16, color: palette.accent),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                'AÑADIR ACTO O PUNTO DE GIRO',
                textAlign: TextAlign.center,
                style: BiblePointPanel.labelStyle(palette),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ActAction { save, delete, moveBack, moveForward }

typedef _ActEdit = ({BibleCard act, _ActAction action});

class _ActDialog extends StatefulWidget {
  final int number;
  final BibleCard act;
  final bool isNew;
  final bool shared;
  final bool canMoveBack;
  final bool canMoveForward;
  final BibleActImagesEditor? imagesEditor;

  const _ActDialog({
    required this.number,
    required this.act,
    required this.isNew,
    required this.shared,
    required this.canMoveBack,
    required this.canMoveForward,
    required this.imagesEditor,
  });

  @override
  State<_ActDialog> createState() => _ActDialogState();
}

class _ActDialogState extends State<_ActDialog> {
  late final _phase = TextEditingController(text: widget.act.kicker);
  late final _title = TextEditingController(text: widget.act.title);
  late final _body = TextEditingController(text: widget.act.body);
  late List<int> _imageIds = [...widget.act.imageIds];
  late bool _turn = widget.act.turn;

  @override
  void dispose() {
    _phase.dispose();
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _close(_ActAction action) => Navigator.pop<_ActEdit>(context, (
    act: widget.act.copyWith(
      kicker: _phase.text.trim(),
      title: _title.text.trim(),
      body: _body.text.trim(),
      imageIds: _imageIds,
      turn: _turn,
    ),
    action: action,
  ));

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(_turn ? 'Punto de giro' : 'Acto ${widget.number}'),
          ),
          if (widget.canMoveBack)
            IconButton(
              tooltip: 'Mover antes',
              icon: const Icon(Icons.arrow_back, size: 18),
              onPressed: () => _close(_ActAction.moveBack),
            ),
          if (widget.canMoveForward)
            IconButton(
              tooltip: 'Mover después',
              icon: const Icon(Icons.arrow_forward, size: 18),
              onPressed: () => _close(_ActAction.moveForward),
            ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.shared)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    'Acto del proyecto: la fase, el título y el orden son los '
                    'mismos en todas las pantallas. La intención y las '
                    'imágenes son de esta.',
                    style: AppTypography.caption(palette),
                  ),
                ),
              TextField(
                controller: _phase,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Fase',
                  hintText: 'Establecimiento, desestabilización, resolución…',
                ),
              ),
              TextField(
                controller: _title,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              TextField(
                controller: _body,
                maxLines: 6,
                minLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Intención'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Punto de giro'),
                subtitle: const Text('Un hito entre actos. No se numera.'),
                value: _turn,
                onChanged: (v) => setState(() => _turn = v),
              ),
              if (widget.imagesEditor != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'IMÁGENES',
                  style: BiblePointPanel.labelStyle(palette),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'La primera encabeza la tarjeta.',
                  style: AppTypography.caption(palette),
                ),
                const SizedBox(height: AppSpacing.sm),
                widget.imagesEditor!(
                  _imageIds,
                  (ids) => setState(() => _imageIds = ids),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (!widget.isNew)
          TextButton(
            onPressed: () => _close(_ActAction.delete),
            child: Text('Eliminar', style: TextStyle(color: palette.error)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => _close(_ActAction.save),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

/// Punto «División por actos» completo: los actos del proyecto, compartidos
/// con las demás pantallas, o unos propios de esta.
class BibleActsPoint extends StatelessWidget {
  final int projectId;
  final int bibleId;
  final String sectionId;
  final BibleActsValue value;
  final ValueChanged<BibleActsValue> onChanged;

  /// Los actos del proyecto.
  final List<BibleCard> sharedActs;

  /// Guarda los actos del proyecto. Sin él, el punto solo admite actos
  /// propios.
  final ValueChanged<List<BibleCard>>? onSharedActsChanged;

  const BibleActsPoint({
    super.key,
    required this.projectId,
    required this.bibleId,
    required this.sectionId,
    required this.value,
    required this.onChanged,
    this.sharedActs = const [],
    this.onSharedActsChanged,
  });

  bool get _shared => value.shared && onSharedActsChanged != null;

  void _onActs(List<BibleCard> next) {
    if (!_shared) {
      onChanged(value.copyWith(shared: false, own: next));
      return;
    }
    final acts = BibleSharedActs.withIds(next);
    onSharedActsChanged!([
      for (final act in acts)
        BibleCard(
          id: act.id,
          kicker: act.kicker,
          title: act.title,
          turn: act.turn,
        ),
    ]);
    onChanged(value.withLayersOf(acts));
  }

  void _toggle() {
    if (_shared) {
      // Los propios nacen como copia de los del proyecto, para partir de ahí.
      onChanged(
        value.copyWith(
          shared: false,
          own: value.own.isNotEmpty
              ? value.own
              : [
                  for (final act in value.resolve(sharedActs))
                    act.copyWith(id: ''),
                ],
        ),
      );
    } else {
      onChanged(value.copyWith(shared: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final acts = _shared ? value.resolve(sharedActs) : value.own;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onSharedActsChanged != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              children: [
                Icon(
                  _shared ? Icons.link : Icons.link_off,
                  size: 14,
                  color: palette.textTertiary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _shared
                        ? 'Actos del proyecto, los mismos en todas las '
                              'pantallas. Aquí va lo que toca a esta.'
                        : 'Actos propios de esta pantalla, independientes de '
                              'los del proyecto.',
                    style: AppTypography.caption(palette),
                  ),
                ),
                TextButton(
                  onPressed: _toggle,
                  child: Text(
                    _shared ? 'Usar actos propios' : 'Usar los del proyecto',
                  ),
                ),
              ],
            ),
          ),
        BibleActsWidget(
          projectId: projectId,
          bibleId: bibleId,
          sectionId: sectionId,
          acts: acts,
          shared: _shared,
          onChanged: _onActs,
        ),
      ],
    );
  }
}
