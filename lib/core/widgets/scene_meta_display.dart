import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/scene_format.dart';

/// Periodo del día normalizado para iconografía consistente.
enum DayNightPeriod {
  dia,
  noche,
  amanecer,
  atardecer,
  continuo,
  unknown,
}

DayNightPeriod dayNightPeriodFrom(String dayNight) {
  final value = dayNight.trim().toUpperCase();
  if (value.contains('NOCHE') || value == 'NIGHT') {
    return DayNightPeriod.noche;
  }
  if (value.contains('AMANECER') ||
      value.contains('DAWN') ||
      value.contains('SUNRISE')) {
    return DayNightPeriod.amanecer;
  }
  if (value.contains('ATARDECER') ||
      value.contains('ANOCHECER') ||
      value.contains('DUSK') ||
      value.contains('SUNSET') ||
      value.contains('EVENING')) {
    return DayNightPeriod.atardecer;
  }
  if (value.contains('CONTINUO') ||
      value.contains('CONTINUOUS') ||
      value.contains('CONTINUED') ||
      value.contains('LATER') ||
      value.contains('TARDE')) {
    return DayNightPeriod.continuo;
  }
  if (value.contains('DÍA') ||
      value.contains('DIA') ||
      value.contains('DAY') ||
      value.contains('MORNING')) {
    return DayNightPeriod.dia;
  }
  return DayNightPeriod.unknown;
}

IconData dayNightIconData(DayNightPeriod period) {
  return switch (period) {
    DayNightPeriod.dia => Icons.wb_sunny_outlined,
    DayNightPeriod.noche => Icons.nightlight_round,
    DayNightPeriod.amanecer => Icons.wb_twilight,
    DayNightPeriod.atardecer => Icons.wb_twilight,
    DayNightPeriod.continuo => Icons.more_time,
    DayNightPeriod.unknown => Icons.schedule_outlined,
  };
}

String dayNightTooltip(DayNightPeriod period, String rawValue) {
  return switch (period) {
    DayNightPeriod.dia => 'Día',
    DayNightPeriod.noche => 'Noche',
    DayNightPeriod.amanecer => 'Amanecer',
    DayNightPeriod.atardecer => 'Atardecer',
    DayNightPeriod.continuo => 'Continuo',
    DayNightPeriod.unknown => rawValue.trim().isEmpty ? 'Momento del día' : rawValue,
  };
}

/// Icono centralizado de día/noche para todas las pantallas.
class DayNightIcon extends StatelessWidget {
  final String dayNight;
  final double size;
  final Color? color;

  const DayNightIcon({
    super.key,
    required this.dayNight,
    this.size = 16,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final period = dayNightPeriodFrom(dayNight);
    final iconColor = color ?? palette.textSecondary;

    return Tooltip(
      message: dayNightTooltip(period, dayNight),
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(
          dayNightIconData(period),
          size: size,
          color: iconColor,
        ),
      ),
    );
  }
}

/// Metadatos de escena (slugline + icono día/noche) con layout uniforme.
class SceneMetaDisplay extends StatelessWidget {
  final String intExt;
  final String dayNight;
  final String location;
  final TextStyle? style;
  final Color? iconColor;
  final double iconSize;
  final int maxLines;
  final TextOverflow overflow;

  const SceneMetaDisplay({
    super.key,
    required this.intExt,
    required this.dayNight,
    required this.location,
    this.style,
    this.iconColor,
    this.iconSize = 16,
    this.maxLines = 2,
    this.overflow = TextOverflow.ellipsis,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textStyle = style ?? AppTypography.bodyLarge(palette);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            formatSceneMetaLine(
              intExt: intExt,
              dayNight: dayNight,
              location: location,
            ),
            style: textStyle,
            maxLines: maxLines,
            overflow: overflow,
          ),
        ),
        const SizedBox(width: 6),
        DayNightIcon(
          dayNight: dayNight,
          size: iconSize,
          color: iconColor ?? palette.textSecondary,
        ),
      ],
    );
  }
}

/// Título numerado de escena con metadatos e icono de día/noche.
class SceneTitleDisplay extends StatelessWidget {
  final int number;
  final String intExt;
  final String dayNight;
  final String location;
  final TextStyle? style;
  final Color? iconColor;
  final double iconSize;

  const SceneTitleDisplay({
    super.key,
    required this.number,
    required this.intExt,
    required this.dayNight,
    required this.location,
    this.style,
    this.iconColor,
    this.iconSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textStyle = style ?? AppTypography.titleMedium(palette);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('$number. ', style: textStyle),
        Expanded(
          child: SceneMetaDisplay(
            intExt: intExt,
            dayNight: dayNight,
            location: location,
            style: textStyle,
            iconColor: iconColor,
            iconSize: iconSize,
          ),
        ),
      ],
    );
  }
}

/// Compatibilidad con exports de texto plano (PDF, etc.).
String formatSceneMetaLineWithIconLabel({
  required String intExt,
  required String dayNight,
  required String location,
}) =>
    formatSceneMetaLine(intExt: intExt, dayNight: dayNight, location: location);
