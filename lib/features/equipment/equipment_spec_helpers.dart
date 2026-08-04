import 'dart:convert';

import '../../core/database/app_database.dart';
import '../optics_lab/sensor_mode_utils.dart';

/// Entrada de ficha técnica agrupada para pantallas de equipo.
class EquipmentSpecSection {
  final String title;
  final List<EquipmentSpecRow> rows;

  const EquipmentSpecSection({required this.title, required this.rows});
}

class EquipmentSpecRow {
  final String label;
  final String value;

  const EquipmentSpecRow(this.label, this.value);
}

List<String> formatRentalTags(String? jsonStr) {
  if (jsonStr == null || jsonStr.isEmpty) return [];
  try {
    final list = jsonDecode(jsonStr) as List<dynamic>;
    return list.map((e) => e.toString()).toList();
  } catch (_) {
    return [];
  }
}

Map<String, dynamic>? parseLensNotes(String? notes) {
  if (notes == null || notes.isEmpty) return null;
  try {
    final decoded = jsonDecode(notes);
    if (decoded is Map<String, dynamic>) return decoded;
  } catch (_) {}
  return null;
}

String cameraListSubtitle(Camera c) {
  final modes = parseSensorModesJson(c.sensorModesJson);
  final parts = <String>[
    if (c.mountType != null) c.mountType!,
    '${c.sensorWidthMm.toStringAsFixed(1)} × ${c.sensorHeightMm.toStringAsFixed(1)} mm',
    if (modes.isNotEmpty) '${modes.length} modos',
    if (c.dynamicRangeStops != null) '${c.dynamicRangeStops!.toStringAsFixed(0)} stops',
    if (c.nativeIso != null) 'ISO ${c.nativeIso}',
    if (c.lukaCompatible) 'LUKA',
  ];
  return parts.join(' · ');
}

String lensListSubtitle(Lense l) {
  final focal = l.focalLength > 0
      ? '${l.focalLength.toStringAsFixed(0)} mm'
      : '${l.focalMin?.toStringAsFixed(0)}–${l.focalMax?.toStringAsFixed(0)} mm';
  final parts = <String>[
    focal,
    'T${l.minTStop.toStringAsFixed(1)}',
    l.formatCoverage,
    if (l.mountType != null) l.mountType!,
    if (l.imageCircleMm != null) 'Ø${l.imageCircleMm!.toStringAsFixed(0)} mm',
    if (l.isAnamorphic) '${l.squeezeRatio ?? 2.0}x',
    if (l.lukaCompatible) 'LUKA',
  ];
  return parts.join(' · ');
}

String lightListSubtitle(Light l) {
  final parts = <String>[
    l.lightType,
    '${l.powerW} W',
    '${l.colorTempMin}–${l.colorTempMax} K',
    if (l.cri != null) 'CRI ${l.cri}',
    if (l.tlci != null) 'TLCI ${l.tlci}',
    if (l.isLukaCompatible) 'LUKA',
  ];
  return parts.join(' · ');
}

List<EquipmentSpecSection> cameraSpecSections(Camera c) {
  final modeSpecs = parseSensorModesJson(c.sensorModesJson);
  return [
    EquipmentSpecSection(
      title: 'Identificación',
      rows: [
        if (c.series != null) EquipmentSpecRow('Serie', c.series!),
        if (c.mountType != null) EquipmentSpecRow('Montura', c.mountType!),
        if (c.colorScience != null) EquipmentSpecRow('Color science', c.colorScience!),
        if (c.vintage) const EquipmentSpecRow('Clasificación', 'Vintage'),
        if (c.isCustom) const EquipmentSpecRow('Origen', 'Equipo custom'),
      ],
    ),
    EquipmentSpecSection(
      title: 'Sensor',
      rows: [
        EquipmentSpecRow(
          'Chip físico',
          '${c.sensorWidthMm.toStringAsFixed(2)} × ${c.sensorHeightMm.toStringAsFixed(2)} mm',
        ),
        if (c.dynamicRangeStops != null)
          EquipmentSpecRow('Rango dinámico', '${c.dynamicRangeStops} stops'),
        if (c.nativeIso != null) EquipmentSpecRow('ISO nativo', '${c.nativeIso}'),
        if (c.logFormats != null) EquipmentSpecRow('Formatos log', c.logFormats!),
      ],
    ),
    if (modeSpecs.isNotEmpty)
      EquipmentSpecSection(
        title: 'Modos de sensor y grabación',
        rows: modeSpecs.map((m) {
          final ctx = SensorModeContext.fromCamera(c, m);
          return EquipmentSpecRow(
            m.name,
            '${m.widthMm.toStringAsFixed(2)}×${m.heightMm.toStringAsFixed(2)} mm · '
            '${ctx.recordingLabel} · ${ctx.cropLabel}',
          );
        }).toList(),
      ),
    EquipmentSpecSection(
      title: 'Operativa',
      rows: [
        if (c.weightKg != null)
          EquipmentSpecRow('Peso', '${c.weightKg!.toStringAsFixed(2)} kg'),
        if (c.powerDrawW != null)
          EquipmentSpecRow('Consumo', '${c.powerDrawW} W'),
        if (c.manufacturerUrl != null)
          EquipmentSpecRow('Fabricante', c.manufacturerUrl!),
      ],
    ),
    if (c.rentalTagsJson != null)
      EquipmentSpecSection(
        title: 'Rental / tags',
        rows: formatRentalTags(c.rentalTagsJson)
            .map((t) => EquipmentSpecRow('Tag', t))
            .toList(),
      ),
  ].where((s) => s.rows.isNotEmpty).toList();
}

List<EquipmentSpecSection> lensSpecSections(Lense l) {
  final extra = parseLensNotes(l.notes);
  return [
    EquipmentSpecSection(
      title: 'Identificación',
      rows: [
        if (l.series != null) EquipmentSpecRow('Serie', l.series!),
        if (l.lensType != null) EquipmentSpecRow('Tipo', l.lensType!),
        if (l.mountType != null) EquipmentSpecRow('Montura', l.mountType!),
        if (l.vintage) const EquipmentSpecRow('Clasificación', 'Vintage'),
        if (l.isCustom) const EquipmentSpecRow('Origen', 'Equipo custom'),
      ],
    ),
    EquipmentSpecSection(
      title: 'Óptica',
      rows: [
        if (l.focalLength > 0)
          EquipmentSpecRow('Distancia focal', '${l.focalLength.toStringAsFixed(0)} mm')
        else
          EquipmentSpecRow(
            'Rango focal',
            '${l.focalMin?.toStringAsFixed(0)}–${l.focalMax?.toStringAsFixed(0)} mm',
          ),
        EquipmentSpecRow('T-stop mínimo', 'T${l.minTStop.toStringAsFixed(1)}'),
        EquipmentSpecRow('Cobertura', l.formatCoverage),
        if (l.imageCircleMm != null)
          EquipmentSpecRow('Círculo de imagen', '${l.imageCircleMm!.toStringAsFixed(1)} mm'),
        if (l.isAnamorphic)
          EquipmentSpecRow('Anamórfico', '${l.squeezeRatio ?? 2.0}x squeeze'),
        if (l.closeFocusM != null)
          EquipmentSpecRow('Enfoque mínimo', '${l.closeFocusM!.toStringAsFixed(2)} m'),
      ],
    ),
    EquipmentSpecSection(
      title: 'Mecánica',
      rows: [
        if (l.frontDiameterMm != null)
          EquipmentSpecRow('Diámetro frontal', '${l.frontDiameterMm!.toStringAsFixed(0)} mm'),
        if (extra?['weightKg'] != null)
          EquipmentSpecRow('Peso', '${extra!['weightKg']} kg'),
        if (extra?['lengthMm'] != null)
          EquipmentSpecRow('Longitud', '${extra!['lengthMm']} mm'),
        if (extra?['year'] != null)
          EquipmentSpecRow('Año', '${extra!['year']}'),
      ],
    ),
    if (l.rentalTagsJson != null)
      EquipmentSpecSection(
        title: 'Rental / tags',
        rows: formatRentalTags(l.rentalTagsJson)
            .map((t) => EquipmentSpecRow('Tag', t))
            .toList(),
      ),
  ].where((s) => s.rows.isNotEmpty).toList();
}

List<EquipmentSpecSection> lightSpecSections(Light l) {
  return [
    EquipmentSpecSection(
      title: 'Identificación',
      rows: [
        if (l.series != null) EquipmentSpecRow('Serie', l.series!),
        EquipmentSpecRow('Tipo', l.lightType),
        if (l.vintage) const EquipmentSpecRow('Clasificación', 'Vintage'),
        if (l.isCustom) const EquipmentSpecRow('Origen', 'Equipo custom'),
      ],
    ),
    EquipmentSpecSection(
      title: 'Fotometría',
      rows: [
        EquipmentSpecRow('Potencia', '${l.powerW} W'),
        EquipmentSpecRow('Temperatura color', '${l.colorTempMin}–${l.colorTempMax} K'),
        if (l.beamAngleDeg != null)
          EquipmentSpecRow('Ángulo haz', '${l.beamAngleDeg!.toStringAsFixed(0)}°'),
        if (l.cri != null) EquipmentSpecRow('CRI', '${l.cri}'),
        if (l.tlci != null) EquipmentSpecRow('TLCI', '${l.tlci}'),
        if (l.dimmingType != null) EquipmentSpecRow('Dimming', l.dimmingType!),
      ],
    ),
    if (l.rentalTagsJson != null)
      EquipmentSpecSection(
        title: 'Rental / tags',
        rows: formatRentalTags(l.rentalTagsJson)
            .map((t) => EquipmentSpecRow('Tag', t))
            .toList(),
      ),
  ].where((s) => s.rows.isNotEmpty).toList();
}
