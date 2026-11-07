import 'package:flutter/widgets.dart';

/// Un [StreamBuilder] que crea su stream una sola vez por [streamKey].
///
/// Los `watch()` de Drift devuelven un stream nuevo en cada llamada. Escrito
/// dentro de un `build`, cada reconstrucción del padre cancela la suscripción
/// y abre otra: se repite la consulta y se vuelve a reconstruir lo de debajo.
class StableStreamBuilder<T> extends StatefulWidget {
  /// Lo que identifica la consulta, como `(db, shot.id)`.
  final Object? streamKey;
  final Stream<T> Function() stream;
  final AsyncWidgetBuilder<T> builder;

  const StableStreamBuilder({
    super.key,
    required this.streamKey,
    required this.stream,
    required this.builder,
  });

  @override
  State<StableStreamBuilder<T>> createState() => _StableStreamBuilderState<T>();
}

class _StableStreamBuilderState<T> extends State<StableStreamBuilder<T>> {
  late Stream<T> _stream = widget.stream();

  @override
  void didUpdateWidget(StableStreamBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamKey != widget.streamKey) _stream = widget.stream();
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<T>(stream: _stream, builder: widget.builder);
}
