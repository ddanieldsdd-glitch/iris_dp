import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/visual_bible/bible_cards.dart';
import 'bible_card_editor.dart';
import 'bible_point_images.dart';
import 'bible_point_panel.dart';

/// Cómo se reparten las tarjetas de un punto.
enum BibleCardsLayout {
  /// Una debajo de otra: título y desarrollo.
  list,

  /// En columnas, una idea por pilar.
  columns,

  /// Mosaico de imágenes con nota: la primera grande, el resto en fila;
  /// cada una con su imagen de fondo, sus datos cortos y su texto.
  mosaic,
}

/// Tarjetas con título y desarrollo, reutilizables en cualquier pantalla:
/// pilares en columnas o puntos con título en lista.
class BibleCardsWidget extends StatelessWidget {
  final List<BibleCard> cards;
  final ValueChanged<List<BibleCard>> onChanged;
  final BibleCardsLayout layout;

  /// Moodboard del que la ficha de una tarjeta toma sus imágenes; sin él,
  /// las tarjetas son solo texto.
  final BibleCardImageSource? imageSource;

  const BibleCardsWidget({
    super.key,
    required this.cards,
    required this.onChanged,
    this.layout = BibleCardsLayout.list,
    this.imageSource,
  });

  /// Abre la ficha de la tarjeta [index], o la de una nueva.
  Future<void> _edit(BuildContext context, int? index) => openBibleCardEditor(
    context,
    cards: cards,
    index: index,
    onChanged: onChanged,
    copy: layout == BibleCardsLayout.mosaic
        ? BibleCardEditorCopy.mosaic
        : BibleCardEditorCopy.card,
    imageSource: imageSource,
  );

  String _kicker(int index) => cards[index].kicker;

  @override
  Widget build(BuildContext context) => BibleImagePaths(
    source: imageSource,
    builder: (context, paths) => _build(context, paths),
  );

  String? _cover(int index, Map<int, String> paths) {
    for (final id in cards[index].imageIds) {
      if (paths[id] != null) return paths[id];
    }
    return null;
  }

  Widget _build(BuildContext context, Map<int, String> paths) {
    const addLabel = 'AÑADIR TARJETA';
    if (layout == BibleCardsLayout.list) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++)
            _CardRow(
              kicker: _kicker(i),
              card: cards[i],
              cover: _cover(i, paths),
              onTap: () => _edit(context, i),
            ),
          _AddCard(label: addLabel, onTap: () => _edit(context, null)),
        ],
      );
    }

    if (layout == BibleCardsLayout.mosaic) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          const gap = AppSpacing.md;
          final columns = width >= 900 ? 3 : (width >= 520 ? 2 : 1);
          final unit = (width - gap * (columns - 1)) / columns;
          // La primera ocupa dos columnas cuando hay sitio.
          double widthOf(int i) =>
              i == 0 && columns > 1 ? unit * 2 + gap : unit;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (var i = 0; i < cards.length; i++)
                SizedBox(
                  width: widthOf(i),
                  height: 240,
                  child: _MosaicTile(
                    card: cards[i],
                    cover: _cover(i, paths),
                    onTap: () => _edit(context, i),
                  ),
                ),
              SizedBox(
                width: cards.isEmpty ? width : unit,
                height: cards.isEmpty ? 120 : 240,
                child: _AddCard(
                  label: 'AÑADIR IMAGEN CON NOTA',
                  onTap: () => _edit(context, null),
                ),
              ),
            ],
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final columns = width >= 720 ? 4 : (width >= 480 ? 2 : 1);
        const gap = AppSpacing.md;
        final cardWidth = (width - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < cards.length; i++)
              SizedBox(
                width: cardWidth,
                child: _CardTile(
                  kicker: _kicker(i),
                  card: cards[i],
                  cover: _cover(i, paths),
                  onTap: () => _edit(context, i),
                ),
              ),
            SizedBox(
              width: cardWidth,
              child: _AddCard(
                label: addLabel,
                minHeight: cards.isEmpty ? null : 96,
                onTap: () => _edit(context, null),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CardText extends StatelessWidget {
  final String kicker;
  final BibleCard card;

  const _CardText({required this.kicker, required this.card});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (kicker.trim().isNotEmpty) ...[
          Text(
            kicker.toUpperCase(),
            style: BiblePointPanel.labelStyle(
              palette,
            ).copyWith(color: palette.accent),
          ),
          const SizedBox(height: 6),
        ],
        Text(
          card.title.trim().isEmpty ? 'Sin título' : card.title,
          style: AppTypography.titleMedium(palette).copyWith(
            fontSize: 15,
            color: card.title.trim().isEmpty
                ? palette.textTertiary
                : palette.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          card.body.trim().isEmpty ? 'Toca para escribir…' : card.body,
          style: AppTypography.bodyMedium(palette).copyWith(
            height: 1.45,
            color: card.body.trim().isEmpty
                ? palette.textTertiary
                : palette.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _CardRow extends StatelessWidget {
  final String kicker;
  final BibleCard card;
  final String? cover;
  final VoidCallback onTap;

  const _CardRow({
    required this.kicker,
    required this.card,
    required this.onTap,
    this.cover,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: palette.border)),
        ),
        child: cover == null
            ? _CardText(kicker: kicker, card: card)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BibleImageThumb(path: cover!, height: 72, width: 128),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: _CardText(kicker: kicker, card: card)),
                ],
              ),
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  final String kicker;
  final BibleCard card;
  final String? cover;
  final VoidCallback onTap;

  const _CardTile({
    required this.kicker,
    required this.card,
    required this.onTap,
    this.cover,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (cover != null) ...[
              AspectRatio(
                aspectRatio: 16 / 9,
                child: LayoutBuilder(
                  builder: (context, c) => BibleImageThumb(
                    path: cover!,
                    height: c.maxHeight,
                    width: c.maxWidth,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            _CardText(kicker: kicker, card: card),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de mosaico: la imagen llena la tarjeta y el texto va encima,
/// sobre un degradado que lo hace legible.
class _MosaicTile extends StatelessWidget {
  final BibleCard card;
  final String? cover;
  final VoidCallback onTap;

  const _MosaicTile({required this.card, required this.onTap, this.cover});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // «CONTRASTE 8:1 · CAÍDA RÁPIDA» → dos pastillas.
    final chips = [
      for (final part in card.kicker.split(RegExp(r'[·|;]')))
        if (part.trim().isNotEmpty) part.trim(),
    ];
    final more = card.imageIds.length - 1;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (cover != null)
              LayoutBuilder(
                builder: (context, c) => BibleImageThumb(
                  path: cover!,
                  height: c.maxHeight,
                  width: c.maxWidth,
                ),
              )
            else
              ColoredBox(
                color: palette.background.withValues(alpha: 0.5),
                child: Align(
                  alignment: const Alignment(0, -0.4),
                  child: Icon(
                    Icons.add_photo_alternate_outlined,
                    color: palette.textTertiary,
                  ),
                ),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xE6000000)],
                  stops: [0.25, 1],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.border),
              ),
            ),
            if (more > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+$more',
                    style: AppTypography.caption(
                      palette,
                    ).copyWith(color: Colors.white),
                  ),
                ),
              ),
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.md,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    card.title.trim().isEmpty ? 'Sin título' : card.title,
                    style: AppTypography.titleMedium(palette).copyWith(
                      color: card.title.trim().isEmpty
                          ? Colors.white54
                          : Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (chips.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final chip in chips.take(4))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(
                              chip.toUpperCase(),
                              style: BiblePointPanel.labelStyle(
                                palette,
                              ).copyWith(fontSize: 10, color: Colors.white70),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (card.body.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      card.body,
                      style: AppTypography.bodyMedium(
                        palette,
                      ).copyWith(color: Colors.white70, height: 1.35),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddCard extends StatelessWidget {
  final String label;
  final double? minHeight;
  final VoidCallback onTap;

  const _AddCard({required this.label, required this.onTap, this.minHeight});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight ?? 44),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.borderBright),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 16, color: palette.accent),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(label, style: BiblePointPanel.labelStyle(palette)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Etiquetas sueltas: emociones, conceptos, palabras clave.
class BibleTagsWidget extends StatelessWidget {
  final List<String> tags;
  final ValueChanged<List<String>> onChanged;

  const BibleTagsWidget({
    super.key,
    required this.tags,
    required this.onChanged,
  });

  Future<void> _add(BuildContext context) async {
    final controller = TextEditingController();
    final tag = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Añadir etiqueta'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Tensión, melancolía, calma…',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
    if (tag == null || tag.isEmpty || tags.contains(tag)) return;
    onChanged([...tags, tag]);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = BiblePointPanel.labelStyle(palette);
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final tag in tags)
          InputChip(
            label: Text(
              tag.toUpperCase(),
              style: style.copyWith(color: palette.textPrimary),
            ),
            backgroundColor: Colors.transparent,
            side: BorderSide(color: palette.borderBright),
            deleteIconColor: palette.textTertiary,
            onDeleted: () => onChanged([...tags]..remove(tag)),
          ),
        ActionChip(
          avatar: Icon(Icons.add, size: 14, color: palette.accent),
          label: Text('ETIQUETA', style: style.copyWith(color: palette.accent)),
          backgroundColor: Colors.transparent,
          side: BorderSide(color: palette.borderBright),
          onPressed: () => _add(context),
        ),
      ],
    );
  }
}
