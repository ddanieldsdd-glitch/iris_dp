import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/visual_bible/bible_cards.dart';
import 'bible_point_images.dart';
import 'bible_point_panel.dart';
import 'bible_references_deck.dart';

/// De dónde salen las imágenes de una ficha: el moodboard del proyecto.
class BibleCardImageSource {
  final int projectId;
  final int bibleId;
  final String sectionId;

  const BibleCardImageSource({
    required this.projectId,
    required this.bibleId,
    required this.sectionId,
  });
}

/// Qué es la ficha que se edita y cómo se rotulan sus campos.
class BibleCardEditorCopy {
  /// Título de la página («Acto», «Tarjeta»).
  final String pageTitle;
  final String titleHint;
  final String bodyLabel;
  final String bodyHint;

  /// La ficha es un acto: lleva fase, puntos y puede ser un punto de giro.
  final bool act;

  /// El acto es del proyecto: fase, título y orden se comparten.
  final bool sharedAct;

  const BibleCardEditorCopy({
    required this.pageTitle,
    this.titleHint = 'Título',
    this.bodyLabel = 'Desarrollo',
    this.bodyHint = 'Escribe aquí…',
    this.act = false,
    this.sharedAct = false,
  });

  static const card = BibleCardEditorCopy(pageTitle: 'Tarjeta');

  static BibleCardEditorCopy forAct({required bool shared}) =>
      BibleCardEditorCopy(
        pageTitle: 'Acto',
        titleHint: 'Título del acto',
        bodyLabel: 'Intención',
        bodyHint: 'Qué pasa con la imagen en este acto y por qué…',
        act: true,
        sharedAct: shared,
      );
}

/// Pinta [builder] con la ruta en disco de las imágenes del moodboard.
class BibleImagePaths extends ConsumerWidget {
  final BibleCardImageSource? source;
  final Widget Function(BuildContext context, Map<int, String> paths) builder;

  const BibleImagePaths({super.key, required this.source, required this.builder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = this.source;
    if (source == null) return builder(context, const {});
    return StreamBuilder<List<MoodboardImage>>(
      stream: ref.watch(databaseProvider).watchMoodboardImages(source.projectId),
      builder: (context, snap) => builder(context, {
        for (final image in snap.data ?? const <MoodboardImage>[])
          image.id: image.imagePath,
      }),
    );
  }
}

/// Abre la ficha de la tarjeta [index] de [cards] (una nueva si es `null`)
/// dentro del contenido de la pantalla. Cada cambio se guarda al momento con
/// [onChanged]; al volver, una ficha que quedó vacía se descarta.
Future<void> openBibleCardEditor(
  BuildContext context, {
  required List<BibleCard> cards,
  required int? index,
  required ValueChanged<List<BibleCard>> onChanged,
  required BibleCardEditorCopy copy,
  BibleCardImageSource? imageSource,
  Map<int, String> imagePaths = const {},
  BibleCard newCard = const BibleCard(),
}) async {
  var current = [...cards, if (index == null) newCard];
  var at = index ?? current.length - 1;
  var deleted = false;
  var saved = index != null;
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => BibleImagePaths(
        source: imageSource,
        builder: (context, paths) => BibleCardEditor(
          copy: copy,
          initial: current[at],
          imagePaths: imageSource == null ? imagePaths : paths,
          position: at,
          count: current.length,
          onChanged: (card) {
            saved = true;
            current = [...current]..[at] = card;
            onChanged(current);
          },
          onMove: (card, delta) {
            current = [...current]
              ..removeAt(at)
              ..insert(at + delta, card);
            at += delta;
            onChanged(current);
          },
          onDelete: () {
            deleted = true;
            onChanged([...current]..removeAt(at));
          },
          onPickImages: imageSource == null
              ? null
              : (selected) => showMoodboardImagePicker(
                  context,
                  projectId: imageSource.projectId,
                  bibleId: imageSource.bibleId,
                  sectionId: imageSource.sectionId,
                  selected: selected,
                ),
        ),
      ),
    ),
  );
  // Una ficha nueva que nunca se rellenó no llegó a guardarse.
  if (!deleted && saved && current[at].isEmpty) {
    onChanged([...current]..removeAt(at));
  }
}

/// Ficha ampliada de una tarjeta o de un acto. No depende de la base de
/// datos: recibe las rutas de las imágenes y avisa de cada cambio.
class BibleCardEditor extends StatefulWidget {
  final BibleCardEditorCopy copy;
  final BibleCard initial;
  final Map<int, String> imagePaths;

  /// Posición de la ficha entre sus [count] hermanas, para moverla.
  final int position;
  final int count;
  final ValueChanged<BibleCard> onChanged;
  final void Function(BibleCard card, int delta) onMove;
  final VoidCallback onDelete;

  /// Abre el selector de imágenes; sin él, la ficha no lleva imágenes.
  final Future<List<int>?> Function(List<int> selected)? onPickImages;

  const BibleCardEditor({
    super.key,
    required this.copy,
    required this.initial,
    required this.onChanged,
    required this.onMove,
    required this.onDelete,
    this.imagePaths = const {},
    this.position = 0,
    this.count = 1,
    this.onPickImages,
  });

  @override
  State<BibleCardEditor> createState() => _BibleCardEditorState();
}

class _PointControllers {
  final TextEditingController title;
  final TextEditingController body;

  _PointControllers(BibleCard point)
    : title = TextEditingController(text: point.title),
      body = TextEditingController(text: point.body);

  BibleCard get value =>
      BibleCard(title: title.text.trim(), body: body.text.trim());

  void dispose() {
    title.dispose();
    body.dispose();
  }
}

class _BibleCardEditorState extends State<BibleCardEditor> {
  static const _saveDelay = Duration(milliseconds: 500);

  late final _phase = TextEditingController(text: widget.initial.kicker);
  late final _title = TextEditingController(text: widget.initial.title);
  late final _body = TextEditingController(text: widget.initial.body);
  late List<int> _imageIds = [...widget.initial.imageIds];
  late bool _turn = widget.initial.turn;
  late final List<_PointControllers> _points = [
    for (final point in widget.initial.points) _PointControllers(point),
  ];
  late int _position = widget.position;
  Timer? _debounce;
  bool _dirty = false;
  bool _deleted = false;

  BibleCard get _current => widget.initial.copyWith(
    kicker: _phase.text.trim(),
    title: _title.text.trim(),
    body: _body.text.trim(),
    imageIds: _imageIds,
    turn: _turn,
    points: [for (final point in _points) point.value],
  );

  @override
  void dispose() {
    _debounce?.cancel();
    if (_dirty && !_deleted) widget.onChanged(_current);
    for (final c in [_phase, _title, _body]) {
      c.dispose();
    }
    for (final point in _points) {
      point.dispose();
    }
    super.dispose();
  }

  /// Guarda tras una pausa al escribir.
  void _touch() {
    setState(() => _dirty = true);
    _debounce?.cancel();
    _debounce = Timer(_saveDelay, _flush);
  }

  /// Guarda ya (imágenes, puntos, giro).
  void _flush() {
    _debounce?.cancel();
    widget.onChanged(_current);
    if (mounted) setState(() => _dirty = false);
  }

  void _move(int delta) {
    _debounce?.cancel();
    widget.onMove(_current, delta);
    setState(() {
      _position += delta;
      _dirty = false;
    });
  }

  Future<void> _pickImages() async {
    final picked = await widget.onPickImages!(_imageIds);
    if (picked == null || !mounted) return;
    setState(() => _imageIds = picked);
    _flush();
  }

  void _setCover(int id) {
    setState(() => _imageIds = [id, ..._imageIds.where((i) => i != id)]);
    _flush();
  }

  void _removeImage(int id) {
    setState(() => _imageIds = _imageIds.where((i) => i != id).toList());
    _flush();
  }

  void _addPoint() {
    setState(() => _points.add(_PointControllers(const BibleCard())));
  }

  void _removePoint(int index) {
    setState(() => _points.removeAt(index).dispose());
    _flush();
  }

  void _movePoint(int index, int delta) {
    setState(() => _points.insert(index + delta, _points.removeAt(index)));
    _flush();
  }

  Future<void> _confirmDelete() async {
    final copy = widget.copy;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Eliminar ${copy.pageTitle.toLowerCase()}'),
        content: Text(
          copy.sharedAct
              ? 'Es un acto del proyecto: se quita de todas las pantallas. '
                    'Las imágenes siguen en el moodboard.'
              : 'Se borra la ficha. Las imágenes siguen en el moodboard.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _deleted = true;
    _debounce?.cancel();
    widget.onDelete();
    Navigator.pop(context);
  }

  InputDecoration _bare(AppPalette palette, String hint, TextStyle style) =>
      InputDecoration(
        hintText: hint,
        hintStyle: style.copyWith(color: palette.textTertiary),
        isDense: true,
        filled: false,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      );

  Widget _gallery(AppPalette palette) {
    final label = BiblePointPanel.labelStyle(palette);
    final existing = [
      for (final id in _imageIds)
        if (widget.imagePaths[id] != null) id,
    ];
    final cover = existing.isEmpty ? null : widget.imagePaths[existing.first];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cover != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(BiblePointPanel.radius),
            child: InkWell(
              onTap: () => showBibleImageViewer(context, path: cover),
              child: Image.file(File(cover), fit: BoxFit.contain),
            ),
          )
        else
          InkWell(
            onTap: _pickImages,
            borderRadius: BorderRadius.circular(BiblePointPanel.radius),
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(BiblePointPanel.radius),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 32,
                    color: palette.textSecondary,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text('AÑADIR IMÁGENES', style: label),
                  const SizedBox(height: 4),
                  Text(
                    'Del moodboard, de un archivo o pegadas con ⌘V.',
                    style: AppTypography.caption(palette),
                  ),
                ],
              ),
            ),
          ),
        if (existing.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final id in existing)
                BibleEditorThumb(
                  path: widget.imagePaths[id]!,
                  isCover: id == existing.first,
                  onTap: () => _setCover(id),
                  onRemove: () => _removeImage(id),
                ),
              InkWell(
                onTap: _pickImages,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 72 * 16 / 9,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: palette.border),
                  ),
                  child: Icon(Icons.add, color: palette.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Toca una imagen para ponerla de portada.',
            style: AppTypography.caption(palette),
          ),
        ],
      ],
    );
  }

  Widget _pointPanel(AppPalette palette, int index) {
    final point = _points[index];
    final titleStyle = AppTypography.titleMedium(palette);
    final bodyStyle = AppTypography.bodyLarge(palette).copyWith(height: 1.55);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: BiblePointPanel(
        label: 'Punto ${index + 1}',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (index > 0)
              IconButton(
                tooltip: 'Subir punto',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.arrow_upward, size: 16),
                onPressed: () => _movePoint(index, -1),
              ),
            if (index < _points.length - 1)
              IconButton(
                tooltip: 'Bajar punto',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.arrow_downward, size: 16),
                onPressed: () => _movePoint(index, 1),
              ),
            IconButton(
              tooltip: 'Quitar punto',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 16),
              onPressed: () => _removePoint(index),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: ValueKey('point_title_${identityHashCode(point)}'),
              controller: point.title,
              style: titleStyle,
              textCapitalization: TextCapitalization.sentences,
              decoration: _bare(palette, 'De qué trata', titleStyle),
              onChanged: (_) => _touch(),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: ValueKey('point_body_${identityHashCode(point)}'),
              controller: point.body,
              minLines: 2,
              maxLines: null,
              style: bodyStyle,
              textCapitalization: TextCapitalization.sentences,
              decoration: _bare(palette, 'Desarróllalo aquí…', bodyStyle),
              onChanged: (_) => _touch(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final copy = widget.copy;
    final label = BiblePointPanel.labelStyle(palette);
    final titleStyle = AppTypography.displayMedium(
      palette,
    ).copyWith(fontSize: 30, height: 1.2);
    final phaseStyle = AppTypography.mono(
      palette,
    ).copyWith(fontSize: 13, color: palette.accent);
    final bodyStyle = AppTypography.bodyLarge(palette).copyWith(height: 1.55);

    final fields = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (copy.sharedAct)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              'Acto del proyecto: la fase, el título y el orden son los '
              'mismos en todas las pantallas. La intención, los puntos y las '
              'imágenes son de esta.',
              style: AppTypography.caption(palette),
            ),
          ),
        if (copy.act) ...[
          TextField(
            controller: _phase,
            style: phaseStyle,
            textCapitalization: TextCapitalization.characters,
            decoration: _bare(
              palette,
              'FASE: PLANTEAMIENTO, NUDO, DESENLACE…',
              phaseStyle,
            ),
            onChanged: (_) => _touch(),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        TextField(
          controller: _title,
          minLines: 1,
          maxLines: null,
          style: titleStyle,
          textCapitalization: TextCapitalization.sentences,
          decoration: _bare(palette, copy.titleHint, titleStyle),
          onChanged: (_) => _touch(),
        ),
        const SizedBox(height: AppSpacing.lg),
        BiblePointPanel(
          label: copy.bodyLabel,
          icon: Icons.notes_outlined,
          child: TextField(
            controller: _body,
            minLines: 4,
            maxLines: null,
            style: bodyStyle,
            textCapitalization: TextCapitalization.sentences,
            decoration: _bare(palette, copy.bodyHint, bodyStyle),
            onChanged: (_) => _touch(),
          ),
        ),
        if (copy.act) ...[
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < _points.length; i++) _pointPanel(palette, i),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _addPoint,
              icon: Icon(Icons.add, size: 16, color: palette.accent),
              label: Text('AÑADIR PUNTO', style: label),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Punto de giro'),
            subtitle: const Text('Un hito entre actos. No se numera.'),
            value: _turn,
            onChanged: (v) {
              setState(() => _turn = v);
              _flush();
            },
          ),
        ],
      ],
    );

    final hasGallery = widget.onPickImages != null;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(_turn ? 'Punto de giro' : copy.pageTitle),
        actions: [
          Center(
            child: Text(
              _dirty ? 'GUARDANDO…' : 'GUARDADO',
              style: label.copyWith(
                color: _dirty ? palette.warning : palette.textTertiary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            tooltip: 'Mover antes',
            onPressed: _position > 0 ? () => _move(-1) : null,
            icon: const Icon(Icons.arrow_back),
          ),
          IconButton(
            tooltip: 'Mover después',
            onPressed: _position < widget.count - 1 ? () => _move(1) : null,
            icon: const Icon(Icons.arrow_forward),
          ),
          IconButton(
            tooltip: 'Eliminar',
            onPressed: _confirmDelete,
            icon: const Icon(Icons.delete_outline),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = hasGallery && constraints.maxWidth >= 900;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: hasGallery ? 1280 : 760),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 6, child: _gallery(palette)),
                          const SizedBox(width: AppSpacing.xl),
                          Expanded(flex: 5, child: fields),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (hasGallery) ...[
                            _gallery(palette),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                          fields,
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}
