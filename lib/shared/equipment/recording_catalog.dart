import 'dart:convert';

import 'catalog_data_status.dart';

/// Medio de grabación de una cámara (cargador, tarjeta).
class RecordingMedium {
  final String id;
  final String name;
  final double capacityGb;
  final String? adapter;
  final String? interface;
  final String? dock;
  final String? note;
  final CatalogDataStatus status;
  final String? sourceLabel;
  final String? sourceUrl;

  const RecordingMedium({
    required this.id,
    required this.name,
    required this.capacityGb,
    this.adapter,
    this.interface,
    this.dock,
    this.note,
    this.status = CatalogDataStatus.pendiente,
    this.sourceLabel,
    this.sourceUrl,
  });

  factory RecordingMedium.fromJson(Map<String, dynamic> json) =>
      RecordingMedium(
        id: json['id'] as String,
        name: json['name'] as String,
        capacityGb: (json['capacityGb'] as num).toDouble(),
        adapter: json['adapter'] as String?,
        interface: json['interface'] as String?,
        dock: json['dock'] as String?,
        note: json['note'] as String?,
        status: CatalogDataStatus.parse(json['dataStatus'] as String?),
        sourceLabel: json['sourceLabel'] as String?,
        sourceUrl: json['sourceUrl'] as String?,
      );
}

/// Formato de grabación (modo + códec) con su tasa y los minutos que cabe en
/// cada medio, según el fabricante.
class RecordingFormat {
  final String id;
  final String mode;
  final String codec;
  final double rateMbPerSec;
  final double? gbPerHour;

  /// Minutos por medio, a los fps de [CameraRecording.fps]. Si un medio no
  /// aparece, la cámara no admite este formato en él.
  final Map<String, int> minutesByMedia;

  const RecordingFormat({
    required this.id,
    required this.mode,
    required this.codec,
    required this.rateMbPerSec,
    this.gbPerHour,
    this.minutesByMedia = const {},
  });

  String get label => '$mode · $codec';

  factory RecordingFormat.fromJson(Map<String, dynamic> json) =>
      RecordingFormat(
        id: json['id'] as String,
        mode: json['mode'] as String,
        codec: json['codec']?.toString() ?? '',
        rateMbPerSec: (json['rateMbPerSec'] as num).toDouble(),
        gbPerHour: (json['gbPerHour'] as num?)?.toDouble(),
        minutesByMedia: {
          for (final e in (json['minutesByMedia'] as Map? ?? const {}).entries)
            e.key.toString(): (e.value as num).toInt(),
        },
      );
}

/// Medios y formatos de grabación de una cámara del catálogo.
class CameraRecording {
  final String cameraId;
  final double fps;
  final List<RecordingMedium> media;
  final List<RecordingFormat> formats;

  const CameraRecording({
    required this.cameraId,
    required this.fps,
    required this.media,
    required this.formats,
  });

  factory CameraRecording.fromJson(Map<String, dynamic> json) =>
      CameraRecording(
        cameraId: json['cameraId'] as String,
        fps: (json['fps'] as num?)?.toDouble() ?? 24,
        media: [
          for (final m in json['media'] as List? ?? const [])
            RecordingMedium.fromJson(Map<String, dynamic>.from(m as Map)),
        ],
        formats: [
          for (final f in json['formats'] as List? ?? const [])
            RecordingFormat.fromJson(Map<String, dynamic>.from(f as Map)),
        ],
      );

  /// Medios que admiten [format].
  List<RecordingMedium> mediaFor(RecordingFormat format) => [
    for (final medium in media)
      if (format.minutesByMedia.containsKey(medium.id)) medium,
  ];
}

List<CameraRecording> parseRecordingCatalog(String jsonStr) {
  final decoded = jsonDecode(jsonStr);
  final cameras = decoded is Map ? decoded['cameras'] : null;
  return [
    if (cameras is List)
      for (final c in cameras)
        CameraRecording.fromJson(Map<String, dynamic>.from(c as Map)),
  ];
}

/// Plan de grabación y volcado de una jornada.
class RecordingPlan {
  /// Minutos que cabe el formato en un cargador; null si no se admite.
  final int? minutesPerMag;
  final double gbPerDay;
  final double totalTb;
  final int? magsPerDay;
  final double offloadMbPerSec;
  final double offloadHoursPerDay;
  final double storageTb;

  const RecordingPlan({
    required this.minutesPerMag,
    required this.gbPerDay,
    required this.totalTb,
    required this.magsPerDay,
    required this.offloadMbPerSec,
    required this.offloadHoursPerDay,
    required this.storageTb,
  });

  /// [dockMbPerSec] y [destinationMbPerSec] limitan el volcado: manda la más
  /// lenta. Con [verify], se suma una pasada de lectura completa.
  factory RecordingPlan.compute({
    required RecordingFormat format,
    required RecordingMedium medium,
    required double minutesPerDay,
    required int days,
    double dockMbPerSec = 2500,
    double destinationMbPerSec = 400,
    int copies = 2,
    bool verify = true,
  }) {
    final minutesPerMag = format.minutesByMedia[medium.id];
    final mbPerDay = format.rateMbPerSec * minutesPerDay * 60;
    final gbPerDay = mbPerDay / 1000;
    final speed = dockMbPerSec < destinationMbPerSec
        ? dockMbPerSec
        : destinationMbPerSec;
    return RecordingPlan(
      minutesPerMag: minutesPerMag,
      gbPerDay: gbPerDay,
      totalTb: gbPerDay * days / 1000,
      magsPerDay: minutesPerMag == null || minutesPerMag == 0
          ? null
          : (minutesPerDay / minutesPerMag).ceil(),
      offloadMbPerSec: speed,
      offloadHoursPerDay: speed <= 0
          ? 0
          : mbPerDay / speed * (verify ? 2 : 1) / 3600,
      storageTb: gbPerDay * days * copies / 1000,
    );
  }
}
