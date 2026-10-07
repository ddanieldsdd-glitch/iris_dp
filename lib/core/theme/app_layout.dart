import 'package:flutter/material.dart';

abstract final class AppLayout {
  static const double wideBreakpoint = 960;
  static const double tabletBreakpoint = 768;
  static const double sidebarWidth = 300;

  /// iPad / tablet: biblia y moodboard en una columna más ancha.
  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletBreakpoint;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wideBreakpoint;

  /// Ancho mínimo de la tabla del guion técnico: la suma de los anchos
  /// mínimos de sus columnas. Por encima, la tabla ocupa todo el ancho.
  static const double technicalScriptTableWidth = 1146;
}
