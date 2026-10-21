import 'package:flutter/material.dart';

import '../../../core/settings/app_prefs.dart';
import '../../../core/settings/settings_widgets.dart';
import '../../visual_bible/bible_prefs.dart';
import '../../visual_bible/visual_bible_model.dart';

/// Ajustes de la biblia de fotografía.
class BibleSettingsSection extends StatelessWidget {
  final SettingsScope scope;

  const BibleSettingsSection({super.key, required this.scope});

  @override
  Widget build(BuildContext context) {
    return SettingsGroupBox(
      title: 'Primera exportación a PDF',
      footer:
          'Después, cada proyecto recuerda su última exportación. Las '
          'secciones, el orden y los campos se cambian en «Configuración de '
          'la biblia», dentro de la propia biblia.',
      children: [
        PrefChoiceRow<String>(
          pref: BiblePrefs.exportMode,
          scope: scope,
          title: 'Tipo de documento',
          choices: [
            for (final m in const [
              VisualBibleExportMode.full,
              VisualBibleExportMode.pitch,
              VisualBibleExportMode.techScout,
            ])
              PrefChoice(m, VisualBibleExportMode.label(m)),
          ],
        ),
        PrefChoiceRow<String>(
          pref: BiblePrefs.exportDestination,
          scope: scope,
          title: 'Al terminar',
          choices: const [
            PrefChoice('saveFile', 'Guardar archivo'),
            PrefChoice('share', 'Compartir'),
          ],
        ),
      ],
    );
  }
}
