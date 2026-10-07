import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Lista que se reordena arrastrando, sin desmontar sus filas.
///
/// `ReorderableListView` mueve cada fila desmontándola y volviéndola a
/// activar. Si la fila lleva un aviso emergente o un menú (un `IconButton`
/// con `tooltip`, un `PopupMenuButton`), esa reactivación toca la capa de
/// superposición en mitad del cálculo de tamaños del `Scaffold` y la pantalla
/// colapsa («_RenderLayoutBuilder was mutated in performLayout», y después
/// `_elements.contains(element)`). Aquí las filas son hijos con clave de una
/// columna: al cambiar el orden solo cambian de sitio.
class SafeReorderableColumn extends StatefulWidget {
  final int itemCount;

  /// Clave estable de cada fila (su id), para que conserve su estado.
  final Key Function(int index) keyOf;
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// Mueve la fila de [oldIndex] a [newIndex], que ya es su posición final:
  /// `list.insert(newIndex, list.removeAt(oldIndex))`.
  final void Function(int oldIndex, int newIndex) onReorder;

  /// Texto de la etiqueta que acompaña al puntero al arrastrar.
  final String Function(int index)? dragLabel;

  final EdgeInsetsGeometry padding;

  /// Con desplazamiento propio. Sin él, la lista mide lo que sus filas.
  final bool scrollable;

  /// Pone el asa sobre la fila, a la derecha y centrada, como hacía
  /// `ReorderableListView` en escritorio. Si es falso, la fila coloca el
  /// asa donde quiera con [SafeReorderableColumn.handle].
  final bool overlayHandle;

  const SafeReorderableColumn({
    super.key,
    required this.itemCount,
    required this.keyOf,
    required this.itemBuilder,
    required this.onReorder,
    this.dragLabel,
    this.padding = EdgeInsets.zero,
    this.scrollable = true,
    this.overlayHandle = true,
  });

  /// Asa de arrastre de la fila [index], para colocarla a mano dentro de
  /// `itemBuilder` cuando [overlayHandle] es falso.
  static Widget handle(BuildContext context, int index) {
    final state = context
        .findAncestorStateOfType<_SafeReorderableColumnState>();
    assert(state != null, 'handle() fuera de una SafeReorderableColumn');
    return state!._handle(index);
  }

  @override
  State<SafeReorderableColumn> createState() => _SafeReorderableColumnState();
}

class _Drag {
  final Object list;
  final int index;
  const _Drag(this.list, this.index);
}

class _SafeReorderableColumnState extends State<SafeReorderableColumn> {
  /// Identifica esta lista: una fila no se puede soltar en otra lista.
  final _token = Object();
  final _scroll = ScrollController();
  final _viewportKey = GlobalKey();
  Timer? _autoScroll;
  double _autoScrollSpeed = 0;

  @override
  void dispose() {
    _autoScroll?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _drop(int from, int before) {
    final to = before > from ? before - 1 : before;
    if (to == from) return;
    widget.onReorder(from, to);
  }

  /// Desplaza la lista mientras el arrastre esté cerca de un borde.
  void _onDragUpdate(DragUpdateDetails details) {
    if (!widget.scrollable || !_scroll.hasClients) return;
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final y = box.globalToLocal(details.globalPosition).dy;
    const edge = 48.0;
    if (y < edge) {
      _autoScrollSpeed = -(edge - y).clamp(4, edge) / 3;
    } else if (y > box.size.height - edge) {
      _autoScrollSpeed = (y - (box.size.height - edge)).clamp(4, edge) / 3;
    } else {
      _autoScrollSpeed = 0;
    }
    if (_autoScrollSpeed == 0) {
      _stopAutoScroll();
      return;
    }
    _autoScroll ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_scroll.hasClients) return;
      final position = _scroll.position;
      final next = (position.pixels + _autoScrollSpeed).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if (next != position.pixels) _scroll.jumpTo(next);
    });
  }

  void _stopAutoScroll() {
    _autoScroll?.cancel();
    _autoScroll = null;
  }

  Widget _handle(int index) {
    final palette = context.palette;
    final label = widget.dragLabel?.call(index);
    return Draggable<_Drag>(
      data: _Drag(_token, index),
      axis: Axis.vertical,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      // Lo que se esté escribiendo se guarda antes de mover la fila.
      onDragStarted: () => FocusManager.instance.primaryFocus?.unfocus(),
      onDragUpdate: _onDragUpdate,
      onDragEnd: (_) => _stopAutoScroll(),
      onDraggableCanceled: (_, _) => _stopAutoScroll(),
      feedback: Material(
        color: palette.surfaceElevated,
        elevation: 6,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: label == null || label.trim().isEmpty
              ? Icon(Icons.drag_handle, size: 18, color: palette.textPrimary)
              : Text(
                  label,
                  style: TextStyle(fontSize: 13, color: palette.textPrimary),
                ),
        ),
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            Icons.drag_handle,
            size: 20,
            color: palette.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _target({required int before, required Widget child, Key? key}) {
    final palette = context.palette;
    return DragTarget<_Drag>(
      key: key,
      onWillAcceptWithDetails: (d) =>
          identical(d.data.list, _token) &&
          d.data.index != before &&
          d.data.index + 1 != before,
      onAcceptWithDetails: (d) => _drop(d.data.index, before),
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

  @override
  Widget build(BuildContext context) {
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < widget.itemCount; i++)
          _target(
            key: widget.keyOf(i),
            before: i,
            child: widget.overlayHandle
                ? Stack(
                    children: [
                      Builder(builder: (c) => widget.itemBuilder(c, i)),
                      Positioned(
                        top: 0,
                        bottom: 0,
                        right: 4,
                        child: Center(child: _handle(i)),
                      ),
                    ],
                  )
                : Builder(builder: (c) => widget.itemBuilder(c, i)),
          ),
        // Soltar bajo la última fila la lleva al final.
        _target(before: widget.itemCount, child: const SizedBox(height: 28)),
      ],
    );

    if (!widget.scrollable) {
      return Padding(padding: widget.padding, child: column);
    }
    return SingleChildScrollView(
      key: _viewportKey,
      controller: _scroll,
      padding: widget.padding,
      child: column,
    );
  }
}
