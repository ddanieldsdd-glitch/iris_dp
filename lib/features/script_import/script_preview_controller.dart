import 'package:flutter/material.dart';

import 'script_preview_panel.dart';
import 'script_scanned_view.dart';

/// Estado compartido del visor de guion (panel embebido y pantalla completa).
class ScriptPreviewController {
  final scannedScrollController = ScrollController();
  final textScrollController = ScrollController();
  final scannedViewKey = GlobalKey<ScriptScannedViewState>();

  double fontSize = ScriptPreviewPanel.defaultFontSize;
  ScriptPreviewMode mode = ScriptPreviewMode.scanned;

  /// Índice de carácter bajo el cursor de lectura (vista escaneada).
  int? activeCharIndex;

  /// Índice en la lista de escenas del workspace.
  int? activeSceneIndex;

  void dispose() {
    scannedScrollController.dispose();
    textScrollController.dispose();
  }

  Future<void> scrollToCharIndex(int charIndex) async {
    await scannedViewKey.currentState?.scrollToCharIndex(charIndex);
  }

  Future<void> scrollToSluglineStartIndex(int startIndex) =>
      scrollToCharIndex(startIndex);
}
