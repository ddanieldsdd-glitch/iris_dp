import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/cloud_link_panel.dart';

/// Vincular / desvincular la nube desde Ajustes (modo local-first).
class SettingsCloudLinkSection extends ConsumerWidget {
  const SettingsCloudLinkSection({
    super.key,
    this.onLoginAction,
    this.onMigrationAction,
  });

  final VoidCallback? onLoginAction;
  final Future<void> Function()? onMigrationAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CloudLinkPanel(
      onLoginAction: onLoginAction,
      onMigrationAction: onMigrationAction,
      promptRestart: true,
      showTitle: true,
      showCloudinaryStatus: true,
    );
  }
}
