import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/error_log.dart';
import '../../core/widgets/app_snackbar.dart';
import '../auth/auth_screen.dart';
import '../migration/cloud_migration_wizard.dart';
import '../onboarding/app_tutorial_store.dart';
import '../onboarding/auth_required_banner.dart';
import '../onboarding/initial_tutorial_flow.dart';
import '../onboarding/install_update_guide_screen.dart';
import '../projects/projects_screen.dart';

/// Acciones que lanzan los ajustes globales: iniciar sesión, subir los
/// proyectos locales, repetir el tutorial, la guía y el registro de errores.
abstract final class SettingsActions {
  static void login(BuildContext context) => openAuthScreen(context);

  static Future<void> migrateToCloud(BuildContext context) async {
    final done = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: CloudMigrationWizard(
            onComplete: () => Navigator.pop(dialogContext, true),
            onSkip: () => Navigator.pop(dialogContext, false),
          ),
        ),
      ),
    );
    if (done == true && context.mounted) {
      AppSnackBar.show(context, 'Proyectos locales subidos a la nube.');
    }
  }

  /// Cierra los ajustes y vuelve a empezar el tutorial inicial.
  static Future<void> replayTutorial(BuildContext context) async {
    final navigator = Navigator.of(context);
    navigator.popUntil((route) => route.isFirst);
    await AppTutorialStore.resetAll();
    await navigator.push<void>(
      MaterialPageRoute(
        builder: (_) => InitialTutorialFlow(
          replayFromStart: true,
          homeContentBuilder: (_) => const Column(
            children: [
              AuthRequiredBanner(),
              Expanded(child: ProjectsScreen()),
            ],
          ),
        ),
      ),
    );
  }

  static void openInstallGuide(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const InstallUpdateGuideScreen()),
    );
  }

  static Future<void> shareErrorLog(BuildContext context) async {
    final log = await ErrorLog.file();
    if (!context.mounted) return;
    if (!log.existsSync() || log.lengthSync() == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay errores registrados')),
      );
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    await Share.shareXFiles(
      [XFile(log.path)],
      subject: 'Registro de errores de IRIS DP',
      // iPad necesita saber desde dónde abrir el menú de compartir.
      sharePositionOrigin: box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size,
    );
  }
}
