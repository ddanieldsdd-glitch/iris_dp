import 'package:flutter/material.dart';

import '../../core/cloud/supabase_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import 'app_tutorial_store.dart';

/// Tour breve sobre la pantalla de proyectos (sync, crear proyecto, ajustes).
class HomeTutorialOverlay extends StatefulWidget {
  final Widget child;
  final VoidCallback? onComplete;

  const HomeTutorialOverlay({
    super.key,
    required this.child,
    this.onComplete,
  });

  @override
  State<HomeTutorialOverlay> createState() => _HomeTutorialOverlayState();
}

class _HomeTutorialOverlayState extends State<HomeTutorialOverlay> {
  var _step = 0;
  var _visible = false;
  var _checked = false;

  static const _steps = [
    _HomeTourStep(
      title: 'Tus proyectos',
      body:
          'Aquí ves todos tus proyectos. Cada tarjeta resume guion, moodboard '
          'y estado de la biblia de fotografía.',
      icon: Icons.grid_view_outlined,
    ),
    _HomeTourStep(
      title: 'Crear proyecto',
      body:
          'Pulsa «Nuevo proyecto» para empezar. Puedes agrupar varios en '
          '«Nuevo grupo» si trabajas en varias producciones.',
      icon: Icons.add_circle_outline,
    ),
    _HomeTourStep(
      title: 'Sincronizar con la nube',
      body:
          'El icono de nube sincroniza con Supabase. Úsalo tras actualizar '
          'la app en otro dispositivo o cuando vuelvas a tener internet.',
      icon: Icons.cloud_sync_outlined,
      cloudOnly: true,
    ),
    _HomeTourStep(
      title: 'Ajustes y ayuda',
      body:
          'En Ajustes cambias carpetas, cierras sesión y puedes volver a ver '
          'el tutorial o la guía de instalación y actualización.',
      icon: Icons.settings_outlined,
    ),
  ];

  List<_HomeTourStep> get _activeSteps {
    final cloud = SupabaseConfig.isConfigured;
    return _steps.where((s) => !s.cloudOnly || cloud).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final done = await AppTutorialStore.isHomeTourComplete();
    if (mounted) {
      setState(() {
        _visible = !done;
        _checked = true;
      });
    }
  }

  void _next() {
    if (_step < _activeSteps.length - 1) {
      setState(() => _step++);
    } else {
      _dismiss();
    }
  }

  void _dismiss() {
    setState(() => _visible = false);
    AppTutorialStore.setHomeTourComplete(true);
    widget.onComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return widget.child;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_visible) ...[
          ModalBarrier(
            color: Colors.black.withValues(alpha: 0.45),
            dismissible: false,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _TourCard(
              step: _activeSteps[_step],
              stepIndex: _step,
              totalSteps: _activeSteps.length,
              onNext: _next,
              onSkip: _dismiss,
              isLast: _step == _activeSteps.length - 1,
            ),
          ),
        ],
      ],
    );
  }
}

class _HomeTourStep {
  final String title;
  final String body;
  final IconData icon;
  final bool cloudOnly;

  const _HomeTourStep({
    required this.title,
    required this.body,
    required this.icon,
    this.cloudOnly = false,
  });
}

class _TourCard extends StatelessWidget {
  final _HomeTourStep step;
  final int stepIndex;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final bool isLast;

  const _TourCard({
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.onNext,
    required this.onSkip,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.lg),
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: palette.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(step.icon, color: palette.accent, size: 28),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(step.title, style: AppTypography.titleMedium(palette)),
                ),
                Text(
                  '${stepIndex + 1}/$totalSteps',
                  style: AppTypography.caption(palette).copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              step.body,
              style: AppTypography.bodyMedium(palette).copyWith(
                color: palette.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                TextButton(onPressed: onSkip, child: const Text('Omitir tour')),
                const Spacer(),
                AppButton(
                  label: isLast ? 'Empezar' : 'Siguiente',
                  icon: isLast ? Icons.check : Icons.arrow_forward,
                  onTap: onNext,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
