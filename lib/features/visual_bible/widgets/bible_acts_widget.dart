import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/visual_bible/bible_acts.dart';
import '../../../shared/visual_bible/bible_cards.dart';
import 'bible_card_editor.dart';
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
    final source = BibleCardImageSource(
      projectId: projectId,
      bibleId: bibleId,
      sectionId: sectionId,
    );
    return BibleImagePaths(
      source: source,
      builder: (context, paths) => BibleActsView(
        acts: acts,
        onChanged: onChanged,
        shared: shared,
        imagePaths: paths,
        imageSource: source,
      ),
    );
  }
}

/// Vista de los actos, sin acceso a datos: recibe las rutas de las imágenes.
class BibleActsView extends StatelessWidget {
  final List<BibleCard> acts;
  final ValueChanged<List<BibleCard>> onChanged;
  final Map<int, String> imagePaths;

  /// Moodboard del que la ficha de un acto toma sus imágenes.
  final BibleCardImageSource? imageSource;
  final bool shared;

  const BibleActsView({
    super.key,
    required this.acts,
    required this.onChanged,
    this.imagePaths = const {},
    this.imageSource,
    this.shared = false,
  });

  /// Abre la ficha del acto [index], o la de uno nuevo.
  Future<void> _edit(BuildContext context, int? index) => openBibleCardEditor(
    context,
    cards: acts,
    index: index,
    onChanged: onChanged,
    copy: BibleCardEditorCopy.forAct(shared: shared),
    imageSource: imageSource,
    imagePaths: imagePaths,
    // Un acto nace con identidad para que su ficha guarde siempre sobre él.
    newCard: BibleSharedActs.withIds(const [BibleCard()]).single,
  );

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
                          ? 'Toca para desarrollar el acto…'
                          : act.body,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium(palette).copyWith(
                        height: 1.45,
                        color: act.body.trim().isEmpty
                            ? palette.textTertiary
                            : palette.textSecondary,
                      ),
                    ),
                    if (act.points.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      for (final point in act.points.take(4))
                        if (point.title.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              '· ${point.title.trim()}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption(palette),
                            ),
                          ),
                    ],
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
