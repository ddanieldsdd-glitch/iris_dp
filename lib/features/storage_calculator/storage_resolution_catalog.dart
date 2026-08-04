/// Resolución de píxeles para cálculo de almacenamiento.
class StorageResolution {
  final int width;
  final int height;
  final String label;
  final String? group;

  const StorageResolution({
    required this.width,
    required this.height,
    required this.label,
    this.group,
  });

  int get pixels => width * height;

  double get megapixels => pixels / 1e6;

  double get aspectRatio => width / height;

  String get aspectLabel {
    final r = aspectRatio;
    if ((r - 16 / 9).abs() < 0.02) return '1.78:1 (16:9)';
    if ((r - 17 / 9).abs() < 0.02) return '1.9:1';
    if ((r - 2.39).abs() < 0.02) return '2.39:1';
    if ((r - 2.0).abs() < 0.02) return '2:1';
    return '${r.toStringAsFixed(2)}:1';
  }

  String get dimensionsLabel => '${width}x$height';

  static StorageResolution? parseDimensions(String value) {
    final parts = value.toLowerCase().split('x');
    if (parts.length != 2) return null;
    final w = int.tryParse(parts[0].trim());
    final h = int.tryParse(parts[1].trim());
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    return StorageResolution(width: w, height: h, label: '${w}x$h');
  }
}

/// Formato contenedor para códecs de entrega (ProRes, DNxHR, DPX).
class DeliveryFormat {
  final String id;
  final String label;
  final int maxWidth;
  final int maxHeight;

  const DeliveryFormat({
    required this.id,
    required this.label,
    required this.maxWidth,
    required this.maxHeight,
  });

  static const sameAsSource = DeliveryFormat(
    id: 'SAS',
    label: 'Igual que origen',
    maxWidth: 0,
    maxHeight: 0,
  );
}

/// Catálogo de resoluciones comunes (paridad PHFX framesToDataRate).
const kCommonResolutions = <StorageResolution>[
  StorageResolution(width: 2048, height: 1080, label: '2K DCI Full', group: '2K & 1080p'),
  StorageResolution(width: 2048, height: 1024, label: '2K 2:1', group: '2K & 1080p'),
  StorageResolution(width: 2048, height: 858, label: '2K DCI Scope', group: '2K & 1080p'),
  StorageResolution(width: 1998, height: 1080, label: '2K DCI Flat', group: '2K & 1080p'),
  StorageResolution(width: 1920, height: 1080, label: 'HD 1080p', group: '2K & 1080p'),
  StorageResolution(width: 4096, height: 2160, label: '4K DCI Full', group: '4K & 2160p'),
  StorageResolution(width: 4096, height: 2048, label: '4K 2:1', group: '4K & 2160p'),
  StorageResolution(width: 4096, height: 1716, label: '4K DCI Scope', group: '4K & 2160p'),
  StorageResolution(width: 3996, height: 2160, label: '4K DCI Flat', group: '4K & 2160p'),
  StorageResolution(width: 3840, height: 2160, label: 'UHD 2160p', group: '4K & 2160p'),
  StorageResolution(width: 8192, height: 4320, label: '8K DCI Full', group: '8K & 4320p'),
  StorageResolution(width: 8192, height: 4096, label: '8K 2:1', group: '8K & 4320p'),
  StorageResolution(width: 8192, height: 3432, label: '8K DCI Scope', group: '8K & 4320p'),
  StorageResolution(width: 7992, height: 4320, label: '8K DCI Flat', group: '8K & 4320p'),
  StorageResolution(width: 7680, height: 4320, label: 'UHD 4320p', group: '8K & 4320p'),
  StorageResolution(width: 10240, height: 5400, label: '10K DCI Full', group: '10K & 5400p'),
  StorageResolution(width: 10240, height: 5120, label: '10K 2:1', group: '10K & 5400p'),
  StorageResolution(width: 12288, height: 6480, label: '12K DCI Full', group: '12K & 6480p'),
  StorageResolution(width: 16384, height: 8640, label: '16K DCI Full', group: '16K & 8640p'),
];

const kDeliveryFormats = <DeliveryFormat>[
  DeliveryFormat.sameAsSource,
  DeliveryFormat(id: 'UHD8K', label: 'UHD 8K 4320p', maxWidth: 7680, maxHeight: 4320),
  DeliveryFormat(id: 'UHD4K', label: 'UHD 4K 2160p', maxWidth: 3840, maxHeight: 2160),
  DeliveryFormat(id: 'HD1080p', label: 'HD 1080p', maxWidth: 1920, maxHeight: 1080),
  DeliveryFormat(id: 'HD720P', label: 'HD 720p', maxWidth: 1280, maxHeight: 720),
  DeliveryFormat(id: 'DCI8K', label: 'DCI Full 8K', maxWidth: 8192, maxHeight: 4320),
  DeliveryFormat(id: 'DCI4K', label: 'DCI Full 4K', maxWidth: 4096, maxHeight: 2160),
  DeliveryFormat(id: 'DCI2K', label: 'DCI Full 2K', maxWidth: 2048, maxHeight: 1080),
  DeliveryFormat(id: 'DCISCOPE8K', label: 'DCI Scope 8K', maxWidth: 8192, maxHeight: 3432),
  DeliveryFormat(id: 'DCISCOPE4K', label: 'DCI Scope 4K', maxWidth: 4096, maxHeight: 1716),
  DeliveryFormat(id: 'DCISCOPE2K', label: 'DCI Scope 2K', maxWidth: 2048, maxHeight: 858),
  DeliveryFormat(id: 'DCIFLAT8K', label: 'DCI Flat 8K', maxWidth: 7992, maxHeight: 4320),
  DeliveryFormat(id: 'DCIFLAT4K', label: 'DCI Flat 4K', maxWidth: 3996, maxHeight: 2160),
  DeliveryFormat(id: 'DCIFLAT2K', label: 'DCI Flat 2K', maxWidth: 1998, maxHeight: 1080),
  DeliveryFormat(id: 'TWOONE8K', label: '2:1 8K', maxWidth: 8192, maxHeight: 4096),
  DeliveryFormat(id: 'TWOONE4K', label: '2:1 4K', maxWidth: 4096, maxHeight: 2048),
  DeliveryFormat(id: 'TWOONE2K', label: '2:1 2K', maxWidth: 2048, maxHeight: 1024),
];

const kStandardFrameRates = <double>[
  23.976,
  24,
  25,
  29.97,
  30,
  47.95,
  48,
  50,
  59.94,
  60,
  119.88,
  120,
];

/// Escala resolución origen al contenedor de entrega (solo downscale, sin upscale).
StorageResolution effectiveDeliveryResolution(
  StorageResolution source,
  DeliveryFormat delivery,
) {
  if (delivery.id == 'SAS') return source;
  if (source.width <= delivery.maxWidth && source.height <= delivery.maxHeight) {
    return source;
  }
  final scale = delivery.maxWidth / source.width;
  final newW = delivery.maxWidth;
  final newH = (source.height * scale).round();
  if (newH <= delivery.maxHeight) {
    return StorageResolution(
      width: newW,
      height: newH,
      label: '${newW}x$newH',
    );
  }
  final scaleH = delivery.maxHeight / source.height;
  return StorageResolution(
    width: (source.width * scaleH).round(),
    height: delivery.maxHeight,
    label: '${(source.width * scaleH).round()}x${delivery.maxHeight}',
  );
}
