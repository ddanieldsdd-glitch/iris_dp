import 'dart:io';

import 'package:flutter/foundation.dart';

/// La tecla de los atajos tal como se escribe en este sistema: «⌘» en el
/// Mac y el iPad, «Ctrl+» en Windows y Linux. Para los textos de ayuda
/// («pega con ⌘V»).
String get modKey {
  if (kIsWeb) return 'Ctrl+';
  return Platform.isMacOS || Platform.isIOS ? '⌘' : 'Ctrl+';
}
