import '../database/app_database.dart';

const kShotMovements = [
  'STEADY',
  'TRÍPODE',
  'MANO',
  'DOLLY',
  'STEADICAM',
  'GRÚA',
  'DRONE',
];

const kShotAngles = [
  'Normal',
  'Picado',
  'Contrapicado',
  'Cenital',
  'Nadir',
];

/// Línea técnica compacta bajo el fotograma (estilo Artemis / guion técnico).
String formatShotTechnicalLine(Shot shot) {
  return [
    if (shot.framing?.isNotEmpty == true) shot.framing,
    if (shot.lens?.isNotEmpty == true) shot.lens,
    if (shot.movement?.isNotEmpty == true) shot.movement,
    if (shot.angle?.isNotEmpty == true) shot.angle,
  ].join(' · ');
}
