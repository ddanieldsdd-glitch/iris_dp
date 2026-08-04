import 'storage_codec_catalog.dart';
import 'storage_resolution_catalog.dart';

/// Fila de data rate (paridad PHFX: por frame, segundo, minuto, hora, proyecto).
class DataRateRow {
  final String label;
  final int bytesPerFrame;
  final int bytesPerSecond;
  final int bytesPerMinute;
  final int bytesPerHour;
  final int? bytesForProject;

  const DataRateRow({
    required this.label,
    required this.bytesPerFrame,
    required this.bytesPerSecond,
    required this.bytesPerMinute,
    required this.bytesPerHour,
    this.bytesForProject,
  });
}

/// Sección agrupada de resultados (DPX, RAW, ProRes…).
class DataRateSection {
  final String title;
  final List<DataRateRow> rows;

  const DataRateSection({required this.title, required this.rows});
}

/// Resultado completo del cálculo.
class StorageCalculationResult {
  final StorageResolution sourceResolution;
  final StorageResolution? deliveryResolution;
  final double frameRate;
  final Duration? totalDuration;
  final int? totalFrames;
  final int? dayMultiplier;
  final List<DataRateSection> sections;

  const StorageCalculationResult({
    required this.sourceResolution,
    this.deliveryResolution,
    required this.frameRate,
    this.totalDuration,
    this.totalFrames,
    this.dayMultiplier,
    required this.sections,
  });
}

/// Motor de cálculo de almacenamiento (modelo PHFX framesToDataRate).
class StorageCalculator {
  StorageCalculator._();

  static const _ref1080pPixels = 1920 * 1080;
  static const _phfxCalibration = 0.989;

  static StorageCalculationResult compute({
    required StorageResolution source,
    required double frameRate,
    int hours = 0,
    int minutes = 0,
    int seconds = 0,
    int dayMultiplier = 1,
    RecordingCodecFamily recordingCodec = RecordingCodecFamily.none,
    String? recordingVariantId,
    DeliveryFormat delivery = DeliveryFormat.sameAsSource,
    bool includeIntermediateCodecs = true,
    bool includeDpx = true,
  }) {
    final effective = effectiveDeliveryResolution(source, delivery);
    final hasDuration = hours > 0 || minutes > 0 || seconds > 0;
    Duration? totalDuration;
    int? totalFrames;
    if (hasDuration) {
      totalDuration = Duration(
        hours: hours,
        minutes: minutes,
        seconds: seconds,
      );
      totalFrames =
          (totalDuration.inMicroseconds / (1000000 / frameRate)).round();
    }

    final sections = <DataRateSection>[];

    if (recordingCodec != RecordingCodecFamily.none &&
        recordingVariantId != null) {
      final row = _recordingCodecRow(
        source: source,
        frameRate: frameRate,
        family: recordingCodec,
        variantId: recordingVariantId,
        totalDuration: totalDuration,
        dayMultiplier: dayMultiplier,
      );
      if (row != null) {
        sections.add(DataRateSection(
          title:
              '${kRecordingCodecFamilies[recordingCodec]} — ${source.dimensionsLabel}',
          rows: [row],
        ));
      }
    }

    if (includeDpx) {
      sections.add(DataRateSection(
        title: 'DPX sin comprimir — ${source.dimensionsLabel}',
        rows: [
          for (final depth in kDpxBitDepths)
            _rowFromBytesPerFrame(
              label: 'DPX $depth-bit',
              bytesPerFrame: _dpxBytesPerFrame(source.width, source.height, depth),
              frameRate: frameRate,
              totalDuration: totalDuration,
              dayMultiplier: dayMultiplier,
            ),
        ],
      ));
    }

    if (includeIntermediateCodecs) {
      final deliveryRes = delivery.id == 'SAS' ? source : effective;
      sections.add(DataRateSection(
        title: delivery.id == 'SAS'
            ? 'Códecs intermedios — ${deliveryRes.dimensionsLabel}'
            : 'Entrega ${delivery.label} — ${deliveryRes.dimensionsLabel}',
        rows: [
          for (final codec in kIntermediateCodecs)
            _rowFromBytesPerFrame(
              label: codec.label,
              bytesPerFrame: _scaledIntermediateBytes(
                codec.bytesPerFrameAt1080p,
                deliveryRes.width,
                deliveryRes.height,
              ),
              frameRate: frameRate,
              totalDuration: totalDuration,
              dayMultiplier: dayMultiplier,
            ),
        ],
      ));
    }

    return StorageCalculationResult(
      sourceResolution: source,
      deliveryResolution: delivery.id == 'SAS' ? null : effective,
      frameRate: frameRate,
      totalDuration: totalDuration,
      totalFrames: totalFrames,
      dayMultiplier: hasDuration ? dayMultiplier : null,
      sections: sections,
    );
  }

  static DataRateRow? _recordingCodecRow({
    required StorageResolution source,
    required double frameRate,
    required RecordingCodecFamily family,
    required String variantId,
    Duration? totalDuration,
    required int dayMultiplier,
  }) {
    final bytesPerFrame = _recordingBytesPerFrame(
      width: source.width,
      height: source.height,
      family: family,
      variantId: variantId,
      frameRate: frameRate,
    );
    if (bytesPerFrame == null) return null;

    final label = switch (family) {
      RecordingCodecFamily.redcodeDsmc3 =>
        'REDCODE RAW DSMC3 $variantId',
      RecordingCodecFamily.redcodeRaw => 'REDCODE RAW $variantId',
      RecordingCodecFamily.arriRaw => variantId,
      RecordingCodecFamily.xOcn => 'X-OCN $variantId',
      RecordingCodecFamily.cinemaRaw => 'Cinema RAW $variantId',
      RecordingCodecFamily.proResRaw => 'ProRes RAW $variantId',
      RecordingCodecFamily.bRaw => 'BRAW $variantId',
      RecordingCodecFamily.xavc => variantId,
      RecordingCodecFamily.none => variantId,
    };

    return _rowFromBytesPerFrame(
      label: label,
      bytesPerFrame: bytesPerFrame,
      frameRate: frameRate,
      totalDuration: totalDuration,
      dayMultiplier: dayMultiplier,
    );
  }

  static int? _recordingBytesPerFrame({
    required int width,
    required int height,
    required RecordingCodecFamily family,
    required String variantId,
    required double frameRate,
  }) {
    final pixels = width * height;
    final bayer13 = (pixels * 13 / 8 * _phfxCalibration).round();
    final arriRaw = (pixels * 13 / 8 * 0.979).round();

    return switch (family) {
      RecordingCodecFamily.redcodeRaw => () {
          final ratio = int.tryParse(variantId.split(':').first);
          if (ratio == null || ratio <= 0) return null;
          return (bayer13 / ratio).round();
        }(),
      RecordingCodecFamily.bRaw => () {
          final ratio = int.tryParse(variantId.split(':').first);
          if (ratio == null || ratio <= 0) return null;
          return (bayer13 / ratio).round();
        }(),
      RecordingCodecFamily.redcodeDsmc3 =>
        _redcodeDsmc3Bytes(bayer13, variantId, width, height),
      RecordingCodecFamily.arriRaw => switch (variantId) {
          'ARRIRAW' || 'ARRIRAW_LogC4' => arriRaw,
          'ARRICORE' => (arriRaw * 0.72).round(),
          _ => arriRaw,
        },
      RecordingCodecFamily.xOcn => switch (variantId) {
          'XT' => (arriRaw / 2.70).round(),
          'ST' => (arriRaw / 3.94).round(),
          'LT' => (arriRaw / 6.27).round(),
          _ => null,
        },
      RecordingCodecFamily.cinemaRaw => (bayer13 / 3.5).round(),
      RecordingCodecFamily.proResRaw =>
        _proResRawBytes(width, height, variantId),
      RecordingCodecFamily.xavc => _xavcBytesPerFrame(variantId, frameRate),
      RecordingCodecFamily.none => null,
    };
  }

  static int? _redcodeDsmc3Bytes(
    int bayer13,
    String variant,
    int width,
    int height,
  ) {
    final ref5 = (bayer13 / 5).round();
    return switch (variant) {
      'HQ' => (ref5 * 1.634).round(),
      'MQ' => (ref5 * 1.144).round(),
      'LQ' => (ref5 * 0.85).round(),
      'ELQ' => (ref5 * 0.65).round(),
      _ => null,
    };
  }

  static int? _proResRawBytes(int width, int height, String variant) {
    final ref = variant == 'HQ 12-bit'
        ? kIntermediateCodecs[1].bytesPerFrameAt1080p
        : (kIntermediateCodecs[1].bytesPerFrameAt1080p * 0.85).round();
    return _scaledIntermediateBytes(ref, width, height);
  }

  static int? _xavcBytesPerFrame(String variant, double frameRate) {
    const at24 = {
      '4K Class 480 10-bit': 2076180,
      '4K Class 410 10-bit': 1751121,
      '4K Class 300 10-bit': 1331691,
      '2K Class 160 10-bit': 2768240,
    };
    final ref = at24[variant];
    if (ref == null) return null;
    return (ref * 24 / frameRate).round();
  }

  static int _dpxBytesPerFrame(int width, int height, int bitDepth) =>
      (width * height * bitDepth * 3 / 8).round();

  static int _scaledIntermediateBytes(int ref1080p, int width, int height) =>
      (ref1080p * width * height / _ref1080pPixels).round();

  static DataRateRow _rowFromBytesPerFrame({
    required String label,
    required int bytesPerFrame,
    required double frameRate,
    Duration? totalDuration,
    required int dayMultiplier,
  }) {
    final bytesPerSecond = (bytesPerFrame * frameRate).round();
    final bytesPerMinute = bytesPerSecond * 60;
    final bytesPerHour = bytesPerMinute * 60;
    int? projectBytes;
    if (totalDuration != null) {
      projectBytes =
          (bytesPerSecond * totalDuration.inSeconds * dayMultiplier).round();
    }
    return DataRateRow(
      label: label,
      bytesPerFrame: bytesPerFrame,
      bytesPerSecond: bytesPerSecond,
      bytesPerMinute: bytesPerMinute,
      bytesPerHour: bytesPerHour,
      bytesForProject: projectBytes,
    );
  }
}

/// Formatea bytes en estilo PHFX (KB, MB, GB, TB).
String formatStorageSize(int bytes) {
  if (bytes <= 0) return '0 B';
  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;
  const tb = gb * 1024;

  if (bytes >= tb) {
    return '${(bytes / tb).toStringAsFixed(2)} TB';
  }
  if (bytes >= gb) {
    return '${(bytes / gb).toStringAsFixed(2)} GB';
  }
  if (bytes >= mb) {
    return '${(bytes / mb).toStringAsFixed(2)} MB';
  }
  if (bytes >= kb) {
    return '${(bytes / kb).toStringAsFixed(2)} KB';
  }
  return '$bytes B';
}

/// Formatea duración HH:MM:SS.
String formatDurationLabel(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return '${h.toString().padLeft(2, '0')}:'
      '${m.toString().padLeft(2, '0')}:'
      '${s.toString().padLeft(2, '0')}';
}
