import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'live_editing.dart';
import 'realtime_hub.dart';

/// Pantalla donde se edita en compartido: al salir de ella, lo que este
/// equipo tenía queda libre para los demás al momento (sin esperar a
/// [LiveEditing.releaseDelay]).
class LiveEditingScope extends ConsumerStatefulWidget {
  final Widget child;

  const LiveEditingScope({super.key, required this.child});

  @override
  ConsumerState<LiveEditingScope> createState() => _LiveEditingScopeState();
}

class _LiveEditingScopeState extends ConsumerState<LiveEditingScope> {
  late final LiveEditing _live;

  @override
  void initState() {
    super.initState();
    _live = ref.read(liveEditingProvider);
  }

  @override
  void dispose() {
    // Fuera del desmontaje: avisar mientras se quita el árbol no se puede.
    final live = _live;
    Future.microtask(live.releaseAll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
