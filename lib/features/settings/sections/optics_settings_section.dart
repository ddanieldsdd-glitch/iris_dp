import 'package:flutter/material.dart';

import '../../../core/settings/app_prefs.dart';
import '../../../core/settings/settings_widgets.dart';
import '../../optics_lab/optics_prefs.dart';

/// Ajustes del laboratorio óptico.
class OpticsSettingsSection extends StatelessWidget {
  final SettingsScope scope;

  const OpticsSettingsSection({super.key, required this.scope});

  @override
  Widget build(BuildContext context) {
    return SettingsGroupBox(
      title: 'Líneas de encuadre',
      footer:
          'El formato de la línea A sale del proyecto: el de la biblia o el '
          'de la cámara.',
      children: [
        PrefChoiceRow<double>(
          pref: OpticsPrefs.lineWidth,
          scope: scope,
          title: 'Grosor',
          choices: [
            for (final v in const <double>[1, 2, 3, 4, 6, 8])
              PrefChoice(v, '${v.toStringAsFixed(0)} px'),
          ],
        ),
        PrefChoiceRow<int>(
          pref: OpticsPrefs.lineColorA,
          scope: scope,
          title: 'Color de la línea A',
          choices: const [
            PrefChoice(0xFFFFD600, 'Amarillo'),
            PrefChoice(0xFFFFFFFF, 'Blanco'),
            PrefChoice(0xFF00E5FF, 'Cian'),
            PrefChoice(0xFFFF5252, 'Rojo'),
            PrefChoice(0xFF69F0AE, 'Verde'),
            PrefChoice(0xFFFF4081, 'Magenta'),
          ],
        ),
        PrefChoiceRow<String>(
          pref: OpticsPrefs.style,
          scope: scope,
          title: 'Estilo',
          choices: const [
            PrefChoice('fullBox', 'Caja'),
            PrefChoice('corners', 'Esquinas'),
            PrefChoice('crosshair', 'Cruz'),
          ],
        ),
        PrefChoiceRow<String>(
          pref: OpticsPrefs.shading,
          scope: scope,
          title: 'Sombreado',
          choices: const [
            PrefChoice('none', 'Sin sombreado'),
            PrefChoice('outsideFrameLine', 'Fuera de la línea'),
            PrefChoice('outsideSensor', 'Fuera del sensor'),
          ],
        ),
        PrefChoiceRow<String>(
          pref: OpticsPrefs.centerMark,
          scope: scope,
          title: 'Marca de centro',
          choices: const [
            PrefChoice('none', 'Ninguna'),
            PrefChoice('cross', 'Cruz'),
            PrefChoice('dot', 'Punto'),
            PrefChoice('crossDot', 'Cruz y punto'),
          ],
        ),
      ],
    );
  }
}
