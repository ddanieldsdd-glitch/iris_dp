import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/visual_bible/bible_cards.dart';
import 'bible_point_panel.dart';

/// Cómo se reparten las tarjetas de un punto.
enum BibleCardsLayout {
  /// Una debajo de otra: título y desarrollo.
  list,

  /// En columnas, una idea por pilar.
  columns,
}

/// Tarjetas con título y desarrollo, reutilizables en cualquier pantalla.
///
/// Con [acts], cada tarjeta es un acto: se numera sola y lleva una fase.
class BibleCardsWidget extends StatelessWidget {
  final List<BibleCard> cards;
  final ValueChanged<List<BibleCard>> onChanged;
  final BibleCardsLayout layout;
  final bool acts;

  const BibleCardsWidget({
    super.key,
    required this.cards,
    required this.onChanged,
    this.layout = BibleCardsLayout.list,
    this.acts = false,
  });

  String get _itemName => acts ? 'acto' : 'tarjeta';

  Future<void> _edit(BuildContext context, int? index) async {
    final result = await showDialog<_CardEdit>(
      context: context,
      builder: (_) => _CardDialog(
        title: index == null
            ? 'Añadir $_itemName'
            : acts
            ? 'Acto ${index + 1}'
            : 'Editar tarjeta',
        card: index == null ? const BibleCard() : cards[index],
        withPhase: acts,
        canDelete: index != null,
        canMoveBack: index != null && index > 0,
        canMoveForward: index != null && index < cards.length - 1,
      ),
    );
    if (result == null) return;
    final next = [...cards];
    switch (result.action) {
      case _CardAction.delete:
        next.removeAt(index!);
      case _CardAction.save:
        if (index == null) {
          if (result.card.isEmpty) return;
          next.add(result.card);
        } else {
          next[index] = result.card;
        }
      case _CardAction.moveBack:
        next[index!] = result.card;
        next.insert(index - 1, next.removeAt(index));
      case _CardAction.moveForward:
        next[index!] = result.card;
        next.insert(index + 1, next.removeAt(index));
    }
    onChanged(next);
  }

  String _kicker(int index) {
    if (!acts) return cards[index].kicker;
    final phase = cards[index].kicker.trim();
    return phase.isEmpty ? 'ACTO ${index + 1}' : 'ACTO ${index + 1} · $phase';
  }

  @override
  Widget build(BuildContext context) {
    final addLabel = 'AÑADIR ${_itemName.toUpperCase()}';
    if (layout == BibleCardsLayout.list) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++)
            _CardRow(
              kicker: _kicker(i),
              card: cards[i],
              onTap: () => _edit(context, i),
            ),
          _AddCard(label: addLabel, onTap: () => _edit(context, null)),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final wide = acts ? 3 : 4;
        final columns = width >= 720 ? wide : (width >= 480 ? 2 : 1);
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
  final VoidCallback onTap;

  const _CardRow({
    required this.kicker,
    required this.card,
    required this.onTap,
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
        child: _CardText(kicker: kicker, card: card),
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  final String kicker;
  final BibleCard card;
  final VoidCallback onTap;

  const _CardTile({
    required this.kicker,
    required this.card,
    required this.onTap,
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
        child: _CardText(kicker: kicker, card: card),
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

enum _CardAction { save, delete, moveBack, moveForward }

typedef _CardEdit = ({BibleCard card, _CardAction action});

class _CardDialog extends StatefulWidget {
  final String title;
  final BibleCard card;
  final bool withPhase;
  final bool canDelete;
  final bool canMoveBack;
  final bool canMoveForward;

  const _CardDialog({
    required this.title,
    required this.card,
    required this.withPhase,
    required this.canDelete,
    required this.canMoveBack,
    required this.canMoveForward,
  });

  @override
  State<_CardDialog> createState() => _CardDialogState();
}

class _CardDialogState extends State<_CardDialog> {
  late final _phase = TextEditingController(text: widget.card.kicker);
  late final _title = TextEditingController(text: widget.card.title);
  late final _body = TextEditingController(text: widget.card.body);

  @override
  void dispose() {
    _phase.dispose();
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _close(_CardAction action) => Navigator.pop<_CardEdit>(context, (
    card: BibleCard(
      kicker: _phase.text.trim(),
      title: _title.text.trim(),
      body: _body.text.trim(),
    ),
    action: action,
  ));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(widget.title)),
          if (widget.canMoveBack)
            IconButton(
              tooltip: 'Mover antes',
              icon: const Icon(Icons.arrow_back, size: 18),
              onPressed: () => _close(_CardAction.moveBack),
            ),
          if (widget.canMoveForward)
            IconButton(
              tooltip: 'Mover después',
              icon: const Icon(Icons.arrow_forward, size: 18),
              onPressed: () => _close(_CardAction.moveForward),
            ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.withPhase)
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
              decoration: const InputDecoration(labelText: 'Desarrollo'),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.canDelete)
          TextButton(
            onPressed: () => _close(_CardAction.delete),
            child: Text(
              'Eliminar',
              style: TextStyle(color: context.palette.error),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => _close(_CardAction.save),
          child: const Text('Guardar'),
        ),
      ],
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
