import 'package:flutter/material.dart';

import '../../../core/settings/app_prefs.dart';
import '../../../core/settings/settings_widgets.dart';
import '../../storyboard/storyboard_prefs.dart';

/// Ajustes del storyboard.
class StoryboardSettingsSection extends StatelessWidget {
  final SettingsScope scope;

  const StoryboardSettingsSection({super.key, required this.scope});

  @override
  Widget build(BuildContext context) {
    return SettingsGroupBox(
      title: 'Al abrir',
      children: [
        PrefChoiceRow<String>(
          pref: StoryboardPrefs.layout,
          scope: scope,
          title: 'Vista',
          choices: const [
            PrefChoice('linear', 'Lineal'),
            PrefChoice('grid', 'Rejilla'),
            PrefChoice('list', 'Lista'),
          ],
        ),
        PrefChoiceRow<String>(
          pref: StoryboardPrefs.filter,
          scope: scope,
          title: 'Planos',
          choices: const [
            PrefChoice('all', 'Todos los planos'),
            PrefChoice('withImage', 'Con imagen'),
            PrefChoice('missing', 'Sin imagen'),
          ],
        ),
      ],
    );
  }
}
