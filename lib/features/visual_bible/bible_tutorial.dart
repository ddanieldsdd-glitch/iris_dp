import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Acciones enlazadas desde la pantalla principal al tutorial.
abstract final class BibleTutorialActions {
  static void Function(int step)? goToStep;
}

/// Tutorial de la Biblia Visual (primera apertura por proyecto).
abstract final class BibleTutorial {
  static String _key(int projectId) => 'iris_bible_tutorial_done_$projectId';

  static Future<bool> isDone(int projectId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(projectId)) ?? false;
  }

  static Future<void> markDone(int projectId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(projectId), true);
  }

  static Future<void> reset(int projectId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(projectId));
  }

  static Future<void> maybeShow(BuildContext context, int projectId) async {
    if (await isDone(projectId)) return;
    if (!context.mounted) return;
    await show(context, projectId);
  }

  static Future<void> show(BuildContext context, int projectId) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _BibleTutorialDialog(projectId: projectId),
    );
  }
}

class _BibleTutorialDialog extends StatefulWidget {
  final int projectId;

  const _BibleTutorialDialog({required this.projectId});

  @override
  State<_BibleTutorialDialog> createState() => _BibleTutorialDialogState();
}

class _BibleTutorialDialogState extends State<_BibleTutorialDialog> {
  int _step = 0;

  static const _steps = <(String, String, IconData)>[
    (
      'Bienvenido a la Biblia Visual',
      'Es el documento vivo de intención fotográfica: narrativa, técnica, '
          'moodboard y export. Cada pantalla del lateral es un capítulo.',
      Icons.auto_stories_outlined,
    ),
    (
      'Estilos Cinematic / Technical / Minimalist',
      'Cada pantalla puede cambiar de densidad y look. Abre Ajustes de pantalla '
          '(icono tune o panel derecho) y elige el estilo sin salir de la sección.',
      Icons.tune,
    ),
    (
      'Estructuras y plantillas',
      'En el panel derecho → pestaña Estructura reordenas pantallas en vivo. '
          'Para plantillas completas usa Estructura y plantillas (modo avanzado).',
      Icons.dashboard_customize_outlined,
    ),
    (
      'Moodboard y Visual Sources',
      'Las imágenes ocupan todo el canvas del moodboard. Importa stills con + '
          'o desde Ajustes de pantalla → Fuentes visuales cuando estés en Moodboard.',
      Icons.collections_outlined,
    ),
    (
      'Guardar y exportar',
      'Los cambios se guardan solos (indicador en la barra). Exporta PDF '
          'completo, pitch o ficha por departamento con el botón Exportar PDF.',
      Icons.picture_as_pdf_outlined,
    ),
  ];

  Future<void> _finish() async {
    await BibleTutorial.markDone(widget.projectId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final step = _steps[_step];
    final isLast = _step == _steps.length - 1;

    return AlertDialog(
      backgroundColor: palette.surfaceElevated,
      title: Row(
        children: [
          Icon(step.$3, color: palette.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(step.$1, style: AppTypography.titleMedium(palette)),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Paso ${_step + 1} de ${_steps.length}',
              style: AppTypography.caption(
                palette,
              ).copyWith(color: palette.textTertiary),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              step.$2,
              style: AppTypography.bodyMedium(palette).copyWith(height: 1.45),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                for (var i = 0; i < _steps.length; i++)
                  Expanded(
                    child: Container(
                      height: 3,
                      margin: EdgeInsets.only(
                        right: i < _steps.length - 1 ? 4 : 0,
                      ),
                      decoration: BoxDecoration(
                        color: i <= _step ? palette.accent : palette.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _finish, child: const Text('Saltar')),
        if (_step > 0)
          TextButton(
            onPressed: () => setState(() => _step--),
            child: const Text('Atrás'),
          ),
        if (!isLast && _step >= 1 && _step <= 3)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              BibleTutorialActions.goToStep?.call(_step);
            },
            child: const Text('Ir ahora'),
          ),
        FilledButton(
          onPressed: () {
            if (isLast) {
              _finish();
            } else {
              setState(() => _step++);
            }
          },
          child: Text(isLast ? 'Empezar' : 'Siguiente'),
        ),
      ],
    );
  }
}
