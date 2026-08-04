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

  /// Suma de columnas (936) + padding horizontal md×2 (32).
  static const double technicalScriptTableWidth = 968;
}
