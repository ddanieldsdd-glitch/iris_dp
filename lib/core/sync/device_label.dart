import 'dart:io';
import 'dart:ui';

/// Nombre corto de este equipo para «editado en iPad hace 2 min».
String deviceLabel() {
  if (Platform.isMacOS) return 'Mac';
  if (Platform.isIOS) {
    // Sin plugin: un iPad tiene el lado corto de la pantalla de 600 pt o más.
    final views = PlatformDispatcher.instance.views;
    if (views.isNotEmpty) {
      final view = views.first;
      final size = view.physicalSize / view.devicePixelRatio;
      return size.shortestSide >= 600 ? 'iPad' : 'iPhone';
    }
    return 'iPad';
  }
  if (Platform.isAndroid) return 'Android';
  if (Platform.isWindows) return 'Windows';
  if (Platform.isLinux) return 'Linux';
  return 'otro equipo';
}

/// La última subida a la nube de cualquiera de los proyectos de aquí.
class CloudEdit {
  final DateTime at;

  /// `null` si la subió una versión sin esta columna.
  final String? device;

  const CloudEdit({required this.at, this.device});

  /// «editado en iPad hace 2 min».
  String describe(DateTime now) {
    final ago = now.difference(at);
    final when = ago.inMinutes < 1
        ? 'ahora'
        : ago.inHours < 1
            ? 'hace ${ago.inMinutes} min'
            : ago.inDays < 1
                ? 'hace ${ago.inHours} h'
                : 'hace ${ago.inDays} d';
    return device == null ? 'editado $when' : 'editado en $device $when';
  }
}
