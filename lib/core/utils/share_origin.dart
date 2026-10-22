import 'package:flutter/widgets.dart';

/// Rectángulo desde el que se abre el menú de compartir.
///
/// En iPad el menú sale como globo y `share_plus` falla si no sabe desde
/// dónde; en iPhone, Mac y Windows se ignora. Usa el widget de [context] si
/// está pintado y, si no, el centro de la pantalla.
Rect shareOrigin([BuildContext? context]) {
  final box = context?.findRenderObject();
  if (box is RenderBox && box.hasSize && box.attached) {
    return box.localToGlobal(Offset.zero) & box.size;
  }
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final size = view.physicalSize / view.devicePixelRatio;
  return Rect.fromCenter(
    center: size.center(Offset.zero),
    width: 1,
    height: 1,
  );
}
