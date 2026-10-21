import 'package:flutter/material.dart';

import '../../../core/settings/app_prefs.dart';
import '../../../core/settings/settings_widgets.dart';
import '../../../core/settings/user_templates_settings_section.dart';
import '../../../core/theme/app_spacing.dart';
import '../../shoot_documents/shoot_document_block_types.dart';
import '../../shoot_documents/shoot_document_prefs.dart';
import '../../shoot_documents/shoot_template_editor_screen.dart';

/// Ajustes de los documentos de rodaje.
class ShootDocumentsSettingsSection extends StatelessWidget {
  final SettingsScope scope;

  const ShootDocumentsSettingsSection({super.key, required this.scope});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroupBox(
          title: 'Documento nuevo',
          footer: 'Un documento hecho desde una plantilla usa los de ella.',
          children: [
            PrefChoiceRow<String>(
              pref: ShootDocumentPrefs.layoutPreset,
              scope: scope,
              title: 'Disposición',
              choices: [
                for (final p in const [
                  ShootLayoutPreset.freeform,
                  ShootLayoutPreset.scriptLeftShotsRight,
                  ShootLayoutPreset.stacked,
                  ShootLayoutPreset.shotsOnly,
                ])
                  PrefChoice(p, ShootLayoutPreset.label(p)),
              ],
            ),
            PrefSwitchRow(
              pref: ShootDocumentPrefs.coverInPdf,
              scope: scope,
              title: 'Portada en el PDF',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SettingsGroupBox(
          title: 'Campos visibles en los bloques',
          children: [
            PrefSwitchRow(
              pref: ShootDocumentPrefs.showThumbnail,
              scope: scope,
              title: 'Miniatura',
            ),
            PrefSwitchRow(
              pref: ShootDocumentPrefs.showCharacters,
              scope: scope,
              title: 'Personajes',
            ),
            PrefSwitchRow(
              pref: ShootDocumentPrefs.showDuration,
              scope: scope,
              title: 'Duración',
            ),
            PrefSwitchRow(
              pref: ShootDocumentPrefs.showCamera,
              scope: scope,
              title: 'Cámara',
            ),
            PrefSwitchRow(
              pref: ShootDocumentPrefs.showAction,
              scope: scope,
              title: 'Acción',
            ),
            PrefSwitchRow(
              pref: ShootDocumentPrefs.showScript,
              scope: scope,
              title: 'Guion',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SettingsGroupBox(
          title: 'Plantillas',
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: UserTemplatesSettingsSection(
                onCreateTemplate: () => Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => const ShootTemplateEditorScreen(),
                  ),
                ),
                onEditShootTemplate: (id) async =>
                    await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) =>
                            ShootTemplateEditorScreen(templateId: id),
                      ),
                    ) ??
                    false,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
