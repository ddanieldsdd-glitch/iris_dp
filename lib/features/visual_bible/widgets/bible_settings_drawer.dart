import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'bible_quick_adjust_panel.dart';

/// Drawer lateral de ajuste rápido contextual.
class BibleSettingsDrawer extends StatelessWidget {
  final int bibleId;
  final int projectId;
  final String sectionId;
  final VoidCallback onOpenMasterConfig;

  const BibleSettingsDrawer({
    super.key,
    required this.bibleId,
    required this.projectId,
    required this.sectionId,
    required this.onOpenMasterConfig,
  });

  static const double width = 400;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final screenW = MediaQuery.sizeOf(context).width;
    final drawerW = screenW < 700 ? screenW : width.clamp(340, screenW * 0.42);

    return Drawer(
      width: drawerW.toDouble(),
      backgroundColor: palette.surfaceElevated,
      child: SafeArea(
        child: BibleQuickAdjustPanel(
          bibleId: bibleId,
          projectId: projectId,
          sectionId: sectionId,
          onOpenMasterConfig: () {
            Navigator.of(context).maybePop();
            onOpenMasterConfig();
          },
          onClose: () => Navigator.of(context).maybePop(),
        ),
      ),
    );
  }
}
