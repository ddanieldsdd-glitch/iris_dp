import 'package:flutter/material.dart';

import '../../../core/settings/app_prefs.dart';
import '../../../core/settings/settings_widgets.dart';
import '../../../core/theme/app_spacing.dart';
import '../../camera_plan/light/ambient.dart';
import '../../camera_plan/light/exposure.dart';
import '../../camera_plan/plan_prefs.dart';

/// Ajustes de la planta de cámara.
class CameraPlanSettingsSection extends StatelessWidget {
  final SettingsScope scope;

  const CameraPlanSettingsSection({super.key, required this.scope});

  static String _number(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroupBox(
          title: 'Lienzo al abrir',
          children: [
            PrefSwitchRow(
              pref: PlanPrefs.snap,
              scope: scope,
              title: 'Imán',
              subtitle:
                  'Lo que se mueve o se dibuja se ajusta a la rejilla y a '
                  'otros tramos',
            ),
            PrefSwitchRow(
              pref: PlanPrefs.otherCameras,
              scope: scope,
              title: 'Cámaras de otros planos',
              subtitle: 'Las de los planos que comparten el esquema de luz',
            ),
            PrefSwitchRow(
              pref: PlanPrefs.exposureMap,
              scope: scope,
              title: 'Mapa de exposición',
              subtitle: 'Falso color en lugar de los haces de luz',
            ),
            PrefSwitchRow(
              pref: PlanPrefs.readings,
              scope: scope,
              title: 'Lecturas bajo cada actor',
            ),
            PrefSwitchRow(
              pref: PlanPrefs.unrealNav,
              scope: scope,
              title: '3D como Unreal',
              subtitle:
                  'Botón derecho pulsado: mirar con el ratón y moverse con '
                  'W A S D (Q y E, bajar y subir; la rueda, la velocidad). '
                  'Apagado: girar alrededor como antes',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SettingsGroupBox(
          title: 'Exposición de partida',
          footer:
              'Se usan cuando ni la cámara de la planta ni el plano dicen '
              'otra cosa.',
          children: [
            PrefChoiceRow<double>(
              pref: PlanPrefs.iso,
              scope: scope,
              title: 'ISO',
              choices: [
                for (final v in const <double>[
                  100, 160, 200, 250, 320, 400, 500, 640, 800, 1000, 1280, //
                  1600, 2000, 2500, 3200, 4000, 5000, 6400, 8000, 12800,
                ])
                  PrefChoice(v, _number(v)),
              ],
            ),
            PrefChoiceRow<double>(
              pref: PlanPrefs.shutterDeg,
              scope: scope,
              title: 'Obturador',
              choices: [
                for (final v in const <double>[
                  45,
                  90,
                  144,
                  172.8,
                  180,
                  270,
                  360,
                ])
                  PrefChoice(v, '${_number(v)}°'),
              ],
            ),
            PrefChoiceRow<double>(
              pref: PlanPrefs.fps,
              scope: scope,
              title: 'Fotogramas por segundo',
              choices: [
                for (final v in const <double>[
                  23.976,
                  24,
                  25,
                  29.97,
                  30,
                  48,
                  50,
                  60,
                  120,
                ])
                  PrefChoice(v, '${_number(v)} fps'),
              ],
            ),
            PrefChoiceRow<double>(
              pref: PlanPrefs.tStop,
              scope: scope,
              title: 'Diafragma de trabajo',
              choices: [
                for (final v in kThirdStops.where((s) => s >= 1.4 && s <= 22))
                  PrefChoice(v, formatStop(v)),
              ],
            ),
            PrefChoiceRow<double>(
              pref: PlanPrefs.ndStops,
              scope: scope,
              title: 'Filtro ND',
              choices: [
                for (var i = 0; i <= 7; i++)
                  PrefChoice(
                    i.toDouble(),
                    i == 0
                        ? 'Sin ND'
                        : 'ND ${(i * 0.3).toStringAsFixed(1)} · $i stop${i == 1 ? '' : 's'}',
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SettingsGroupBox(
          title: 'Esquema de luz nuevo',
          children: [
            PrefChoiceRow<bool>(
              pref: PlanPrefs.ambientDay,
              scope: scope,
              title: 'Momento',
              choices: const [
                PrefChoice(true, 'Día'),
                PrefChoice(false, 'Noche'),
              ],
            ),
            PrefChoiceRow<String>(
              pref: PlanPrefs.ambientSky,
              scope: scope,
              title: 'Cielo',
              choices: [
                for (final c in SkyCondition.values)
                  PrefChoice(c.name, c.label),
              ],
            ),
            PrefSwitchRow(
              pref: PlanPrefs.ambientBounce,
              scope: scope,
              title: 'Rebote en paredes',
            ),
          ],
        ),
      ],
    );
  }
}
