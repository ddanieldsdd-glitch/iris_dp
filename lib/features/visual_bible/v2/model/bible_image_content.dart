/// Crop / fit persistente para imágenes de bloque.
class BibleImageCrop {
  final double x;
  final double y;
  final double width;
  final double height;

  const BibleImageCrop({
    this.x = 0,
    this.y = 0,
    this.width = 1,
    this.height = 1,
  });

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };

  factory BibleImageCrop.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const BibleImageCrop();
    return BibleImageCrop(
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      width: (json['width'] as num?)?.toDouble() ?? 1,
      height: (json['height'] as num?)?.toDouble() ?? 1,
    );
  }
}

/// Contenido tipado de imagen (universal).
class BibleImageContent {
  /// local | moodboard | irisLibrary | url | project | camera
  final String source;
  final String? imageId;
  final String? path;
  final String? url;
  final BibleImageCrop crop;
  final double scale;
  final double rotation;

  /// cover | contain | fill
  final String fit;
  final double positionX;
  final double positionY;
  final String? caption;
  final String? credit;
  final double overlayOpacity;

  const BibleImageContent({
    this.source = 'local',
    this.imageId,
    this.path,
    this.url,
    this.crop = const BibleImageCrop(),
    this.scale = 1,
    this.rotation = 0,
    this.fit = 'cover',
    this.positionX = 0.5,
    this.positionY = 0.5,
    this.caption,
    this.credit,
    this.overlayOpacity = 0,
  });

  Map<String, dynamic> toJson() => {
    'source': source,
    if (imageId != null) 'imageId': imageId,
    if (path != null) 'path': path,
    if (url != null) 'url': url,
    'crop': crop.toJson(),
    'scale': scale,
    'rotation': rotation,
    'fit': fit,
    'positionX': positionX,
    'positionY': positionY,
    if (caption != null) 'caption': caption,
    if (credit != null) 'credit': credit,
    'overlayOpacity': overlayOpacity,
  };

  factory BibleImageContent.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const BibleImageContent();
    return BibleImageContent(
      source: json['source']?.toString() ?? 'local',
      imageId: json['imageId']?.toString(),
      path: json['path']?.toString(),
      url: json['url']?.toString(),
      crop: BibleImageCrop.fromJson(
        json['crop'] is Map
            ? Map<String, dynamic>.from(json['crop'] as Map)
            : null,
      ),
      scale: (json['scale'] as num?)?.toDouble() ?? 1,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
      fit: json['fit']?.toString() ?? 'cover',
      positionX: (json['positionX'] as num?)?.toDouble() ?? 0.5,
      positionY: (json['positionY'] as num?)?.toDouble() ?? 0.5,
      caption: json['caption']?.toString(),
      credit: json['credit']?.toString(),
      overlayOpacity: (json['overlayOpacity'] as num?)?.toDouble() ?? 0,
    );
  }

  BibleImageContent copyWith({
    String? source,
    String? imageId,
    String? path,
    String? url,
    BibleImageCrop? crop,
    double? scale,
    double? rotation,
    String? fit,
    double? positionX,
    double? positionY,
    String? caption,
    String? credit,
    double? overlayOpacity,
  }) {
    return BibleImageContent(
      source: source ?? this.source,
      imageId: imageId ?? this.imageId,
      path: path ?? this.path,
      url: url ?? this.url,
      crop: crop ?? this.crop,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      fit: fit ?? this.fit,
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
      caption: caption ?? this.caption,
      credit: credit ?? this.credit,
      overlayOpacity: overlayOpacity ?? this.overlayOpacity,
    );
  }
}
