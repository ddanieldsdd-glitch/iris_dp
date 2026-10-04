import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_snackbar.dart';
import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';
import 'light_beam.dart';

/// Una línea de la lista de material: cantidad y descripción.
class GearLine {
  final int count;
  final String label;

  const GearLine(this.count, this.label);

  @override
  String toString() => '$count× $label';
}

/// Lista de material de una planta, agrupada como en una hoja de rodaje.
class GearList {
  final List<GearLine> lights;
  final List<GearLine> grip;
  final List<GearLine> cameras;

  const GearList({
    this.lights = const [],
    this.grip = const [],
    this.cameras = const [],
  });

  bool get isEmpty => lights.isEmpty && grip.isEmpty && cameras.isEmpty;

  /// Agrupa los elementos iguales y los cuenta.
  factory GearList.from(Iterable<PlanElement> elements) {
    final lights = <String, int>{};
    final grip = <String, int>{};
    final cameras = <String, int>{};
    void add(Map<String, int> map, String key) =>
        map.update(key, (n) => n + 1, ifAbsent: () => 1);

    for (final el in elements) {
      switch (el.type) {
        case ElementType.light:
          final name =
              (el.props['name'] as String?) ?? el.lightType?.label ?? 'Luz';
          add(LightBeam.emits(el.lightType) ? lights : grip, name);
        case ElementType.camera:
          add(
            cameras,
            [
              'Cámara ${el.cameraLetter}',
              if (el.lens?.isNotEmpty == true) el.lens!,
              if (el.stabilization?.isNotEmpty == true) el.stabilization!,
            ].join(' · '),
          );
        case ElementType.actor || ElementType.prop || ElementType.wall:
          break;
      }
    }

    List<GearLine> lines(Map<String, int> map) => [
      for (final e in map.entries) GearLine(e.value, e.key),
    ];
    return GearList(
      lights: lines(lights),
      grip: lines(grip),
      cameras: lines(cameras),
    );
  }

  /// Texto para pegar en un correo o en la orden de material.
  String toText({String? title}) {
    final buffer = StringBuffer();
    if (title != null) buffer.writeln(title);
    void section(String name, List<GearLine> lines) {
      if (lines.isEmpty) return;
      buffer.writeln(name);
      for (final line in lines) {
        buffer.writeln('  $line');
      }
    }

    section('LUCES', lights);
    section('GRIP', grip);
    section('CÁMARA', cameras);
    return buffer.toString().trimRight();
  }
}

/// Panel con la lista de material del esquema de luz y del plano abiertos.
class PlanGearListPanel extends StatelessWidget {
  final GearList gear;
  final String title;

  const PlanGearListPanel({super.key, required this.gear, required this.title});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    Widget section(String name, List<GearLine> lines) {
      if (lines.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: AppTypography.caption(palette).copyWith(
                color: palette.accent,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Text(
                  line.toString(),
                  style: AppTypography.bodyMedium(palette),
                ),
              ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lista de material', style: AppTypography.label(palette)),
          Text(title, style: AppTypography.caption(palette)),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: gear.isEmpty
                ? Text(
                    'Añade luces, grip o cámaras desde la paleta y aparecerán '
                    'aquí, contadas.',
                    style: AppTypography.bodyMedium(
                      palette,
                    ).copyWith(color: palette.textTertiary),
                  )
                : ListView(
                    children: [
                      section('LUCES', gear.lights),
                      section('GRIP', gear.grip),
                      section('CÁMARA', gear.cameras),
                    ],
                  ),
          ),
          if (!gear.isEmpty)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copiar lista'),
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: gear.toText(title: title)),
                  );
                  if (context.mounted) {
                    AppSnackBar.show(context, 'Lista de material copiada.');
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}
