import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Tamaño de la ventana según su ancho (docs/PLAN_IPHONE.md, IP.1.1).
enum AppSizeClass {
  /// iPhone y ventanas estrechas: < 600.
  compact,

  /// iPad en vertical y ventanas medianas: 600–959.
  medium,

  /// iPad en horizontal y escritorio: ≥ 960.
  wide,
}

abstract final class AppLayout {
  static const double wideBreakpoint = 960;
  static const double tabletBreakpoint = 768;
  static const double compactBreakpoint = 600;
  static const double sidebarWidth = 300;

  /// Margen lateral de las pantallas en compacto (el resto usa AppSpacing.xl).
  static const double compactGutter = 16;

  /// Espacio que ocupan los márgenes de AlertDialog (40 por lado) y su
  /// contenido (24 por lado).
  static const double _dialogChrome = 2 * 40 + 2 * 24;

  /// iPad / tablet: biblia y moodboard en una columna más ancha.
  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletBreakpoint;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wideBreakpoint;

  /// iPhone: barra inferior, una columna y cabeceras recogidas.
  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compactBreakpoint;

  static AppSizeClass sizeClassFor(double width) {
    if (width >= wideBreakpoint) return AppSizeClass.wide;
    if (width >= compactBreakpoint) return AppSizeClass.medium;
    return AppSizeClass.compact;
  }

  static AppSizeClass sizeClass(BuildContext context) =>
      sizeClassFor(MediaQuery.sizeOf(context).width);

  /// Margen lateral de pantalla: estrecho en el iPhone.
  static double gutter(BuildContext context, {double regular = 32}) =>
      isCompact(context) ? compactGutter : regular;

  /// Ancho del contenido de un AlertDialog: el preferido, o lo que quepa en
  /// la pantalla si es más estrecha (un SizedBox(width: 340) se sale a 390).
  static double dialogWidth(BuildContext context, double preferred) {
    final available = MediaQuery.sizeOf(context).width - _dialogChrome;
    return math.max(0, math.min(preferred, available));
  }
}
