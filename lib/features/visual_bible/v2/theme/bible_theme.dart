/// Design tokens de Biblia (Cinematic / Technical / Minimalist / Custom).
import '../model/bible_json_parse.dart';

class BibleTheme {
  final String id;
  final String name;

  /// cinematic | technical | minimalist | custom
  final String kind;

  final BibleColorTokens colors;
  final BibleSpacingTokens spacing;
  final BibleShapeTokens shape;
  final BibleTypographyTokens typography;
  final BibleImageTokens image;

  const BibleTheme({
    required this.id,
    required this.name,
    required this.kind,
    required this.colors,
    required this.spacing,
    required this.shape,
    required this.typography,
    required this.image,
  });

  static BibleTheme builtin(String id) {
    return switch (id) {
      BibleThemeIds.technical => BibleThemePresets.technical,
      BibleThemeIds.minimalist => BibleThemePresets.minimalist,
      BibleThemeIds.custom => BibleThemePresets.cinematic.copyWith(
        id: BibleThemeIds.custom,
        name: 'Custom',
        kind: 'custom',
      ),
      _ => BibleThemePresets.cinematic,
    };
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind,
    'colors': colors.toJson(),
    'spacing': spacing.toJson(),
    'shape': shape.toJson(),
    'typography': typography.toJson(),
    'image': image.toJson(),
  };

  factory BibleTheme.fromJson(Map<String, dynamic> json) {
    return BibleTheme(
      id: json['id']?.toString() ?? BibleThemeIds.cinematic,
      name: json['name']?.toString() ?? 'Theme',
      kind: json['kind']?.toString() ?? 'cinematic',
      colors: BibleColorTokens.fromJson(
        json['colors'] is Map
            ? Map<String, dynamic>.from(json['colors'] as Map)
            : null,
      ),
      spacing: BibleSpacingTokens.fromJson(
        json['spacing'] is Map
            ? Map<String, dynamic>.from(json['spacing'] as Map)
            : null,
      ),
      shape: BibleShapeTokens.fromJson(
        json['shape'] is Map
            ? Map<String, dynamic>.from(json['shape'] as Map)
            : null,
      ),
      typography: BibleTypographyTokens.fromJson(
        json['typography'] is Map
            ? Map<String, dynamic>.from(json['typography'] as Map)
            : null,
      ),
      image: BibleImageTokens.fromJson(
        json['image'] is Map
            ? Map<String, dynamic>.from(json['image'] as Map)
            : null,
      ),
    );
  }

  BibleTheme copyWith({
    String? id,
    String? name,
    String? kind,
    BibleColorTokens? colors,
    BibleSpacingTokens? spacing,
    BibleShapeTokens? shape,
    BibleTypographyTokens? typography,
    BibleImageTokens? image,
  }) {
    return BibleTheme(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      colors: colors ?? this.colors,
      spacing: spacing ?? this.spacing,
      shape: shape ?? this.shape,
      typography: typography ?? this.typography,
      image: image ?? this.image,
    );
  }
}

abstract final class BibleThemeIds {
  static const cinematic = 'cinematic';
  static const technical = 'technical';
  static const minimalist = 'minimalist';
  static const custom = 'custom';
}

class BibleColorTokens {
  final String background;
  final String surface;
  final String card;
  final String text;
  final String textSecondary;
  final String accent;
  final String border;
  final String imageOverlay;

  const BibleColorTokens({
    required this.background,
    required this.surface,
    required this.card,
    required this.text,
    required this.textSecondary,
    required this.accent,
    required this.border,
    required this.imageOverlay,
  });

  Map<String, dynamic> toJson() => {
    'background': background,
    'surface': surface,
    'card': card,
    'text': text,
    'textSecondary': textSecondary,
    'accent': accent,
    'border': border,
    'imageOverlay': imageOverlay,
  };

  factory BibleColorTokens.fromJson(Map<String, dynamic>? json) {
    final d = BibleThemePresets.cinematic.colors;
    if (json == null) return d;
    return BibleColorTokens(
      background: json['background']?.toString() ?? d.background,
      surface: json['surface']?.toString() ?? d.surface,
      card: json['card']?.toString() ?? d.card,
      text: json['text']?.toString() ?? d.text,
      textSecondary: json['textSecondary']?.toString() ?? d.textSecondary,
      accent: json['accent']?.toString() ?? d.accent,
      border: json['border']?.toString() ?? d.border,
      imageOverlay: json['imageOverlay']?.toString() ?? d.imageOverlay,
    );
  }
}

class BibleSpacingTokens {
  final double xxs;
  final double xs;
  final double s;
  final double m;
  final double l;
  final double xl;
  final double xxl;

  const BibleSpacingTokens({
    required this.xxs,
    required this.xs,
    required this.s,
    required this.m,
    required this.l,
    required this.xl,
    required this.xxl,
  });

  Map<String, dynamic> toJson() => {
    'xxs': xxs,
    'xs': xs,
    's': s,
    'm': m,
    'l': l,
    'xl': xl,
    'xxl': xxl,
  };

  factory BibleSpacingTokens.fromJson(Map<String, dynamic>? json) {
    final d = BibleThemePresets.cinematic.spacing;
    if (json == null) return d;
    double v(String k, double fallback) =>
        bibleJsonDoubleOr(json[k], fallback);
    return BibleSpacingTokens(
      xxs: v('xxs', d.xxs),
      xs: v('xs', d.xs),
      s: v('s', d.s),
      m: v('m', d.m),
      l: v('l', d.l),
      xl: v('xl', d.xl),
      xxl: v('xxl', d.xxl),
    );
  }
}

class BibleShapeTokens {
  final double radius;
  final double borderWidth;
  final double shadowBlur;

  const BibleShapeTokens({
    required this.radius,
    required this.borderWidth,
    required this.shadowBlur,
  });

  Map<String, dynamic> toJson() => {
    'radius': radius,
    'borderWidth': borderWidth,
    'shadowBlur': shadowBlur,
  };

  factory BibleShapeTokens.fromJson(Map<String, dynamic>? json) {
    final d = BibleThemePresets.cinematic.shape;
    if (json == null) return d;
    return BibleShapeTokens(
      radius: bibleJsonDoubleOr(json['radius'], d.radius),
      borderWidth: bibleJsonDoubleOr(json['borderWidth'], d.borderWidth),
      shadowBlur: bibleJsonDoubleOr(json['shadowBlur'], d.shadowBlur),
    );
  }
}

class BibleTypographyTokens {
  final double display;
  final double h1;
  final double h2;
  final double h3;
  final double body;
  final double caption;
  final double label;
  final double technical;

  const BibleTypographyTokens({
    required this.display,
    required this.h1,
    required this.h2,
    required this.h3,
    required this.body,
    required this.caption,
    required this.label,
    required this.technical,
  });

  Map<String, dynamic> toJson() => {
    'display': display,
    'h1': h1,
    'h2': h2,
    'h3': h3,
    'body': body,
    'caption': caption,
    'label': label,
    'technical': technical,
  };

  factory BibleTypographyTokens.fromJson(Map<String, dynamic>? json) {
    final d = BibleThemePresets.cinematic.typography;
    if (json == null) return d;
    double v(String k, double fallback) =>
        bibleJsonDoubleOr(json[k], fallback);
    return BibleTypographyTokens(
      display: v('display', d.display),
      h1: v('h1', d.h1),
      h2: v('h2', d.h2),
      h3: v('h3', d.h3),
      body: v('body', d.body),
      caption: v('caption', d.caption),
      label: v('label', d.label),
      technical: v('technical', d.technical),
    );
  }
}

class BibleImageTokens {
  final String defaultRatio;
  final String defaultFit;
  final double overlayOpacity;

  const BibleImageTokens({
    required this.defaultRatio,
    required this.defaultFit,
    required this.overlayOpacity,
  });

  Map<String, dynamic> toJson() => {
    'defaultRatio': defaultRatio,
    'defaultFit': defaultFit,
    'overlayOpacity': overlayOpacity,
  };

  factory BibleImageTokens.fromJson(Map<String, dynamic>? json) {
    final d = BibleThemePresets.cinematic.image;
    if (json == null) return d;
    return BibleImageTokens(
      defaultRatio: json['defaultRatio']?.toString() ?? d.defaultRatio,
      defaultFit: json['defaultFit']?.toString() ?? d.defaultFit,
      overlayOpacity:
          bibleJsonDoubleOr(json['overlayOpacity'], d.overlayOpacity),
    );
  }
}

/// Presets alineados al mockup (Primary #2997FF, Secondary #0D0D0D).
abstract final class BibleThemePresets {
  static const cinematic = BibleTheme(
    id: BibleThemeIds.cinematic,
    name: 'Cinematic',
    kind: 'cinematic',
    colors: BibleColorTokens(
      background: '#0D0D0D',
      surface: '#1A1A1C',
      card: '#1E1E1E',
      text: '#FFFFFF',
      textSecondary: '#86868B',
      accent: '#2997FF',
      border: '#2C2C2E',
      imageOverlay: '#00000099',
    ),
    spacing: BibleSpacingTokens(
      xxs: 2,
      xs: 4,
      s: 8,
      m: 12,
      l: 20,
      xl: 32,
      xxl: 48,
    ),
    shape: BibleShapeTokens(radius: 12, borderWidth: 1, shadowBlur: 16),
    typography: BibleTypographyTokens(
      display: 36,
      h1: 28,
      h2: 22,
      h3: 18,
      body: 15,
      caption: 12,
      label: 11,
      technical: 12,
    ),
    image: BibleImageTokens(
      defaultRatio: '16:9',
      defaultFit: 'cover',
      overlayOpacity: 0.35,
    ),
  );

  static const technical = BibleTheme(
    id: BibleThemeIds.technical,
    name: 'Technical',
    kind: 'technical',
    colors: BibleColorTokens(
      background: '#0D0D0D',
      surface: '#141416',
      card: '#1A1A1C',
      text: '#F5F5F7',
      textSecondary: '#86868B',
      accent: '#2997FF',
      border: '#3A3A3C',
      imageOverlay: '#000000AA',
    ),
    spacing: BibleSpacingTokens(
      xxs: 2,
      xs: 4,
      s: 6,
      m: 10,
      l: 14,
      xl: 20,
      xxl: 28,
    ),
    shape: BibleShapeTokens(radius: 8, borderWidth: 1, shadowBlur: 8),
    typography: BibleTypographyTokens(
      display: 28,
      h1: 22,
      h2: 18,
      h3: 15,
      body: 13,
      caption: 11,
      label: 10,
      technical: 11,
    ),
    image: BibleImageTokens(
      defaultRatio: '4:3',
      defaultFit: 'contain',
      overlayOpacity: 0.2,
    ),
  );

  static const minimalist = BibleTheme(
    id: BibleThemeIds.minimalist,
    name: 'Minimalist',
    kind: 'minimalist',
    colors: BibleColorTokens(
      background: '#0D0D0D',
      surface: '#121214',
      card: '#161618',
      text: '#FFFFFF',
      textSecondary: '#86868B',
      accent: '#2997FF',
      border: '#222224',
      imageOverlay: '#00000066',
    ),
    spacing: BibleSpacingTokens(
      xxs: 4,
      xs: 8,
      s: 12,
      m: 20,
      l: 32,
      xl: 48,
      xxl: 64,
    ),
    shape: BibleShapeTokens(radius: 4, borderWidth: 0, shadowBlur: 0),
    typography: BibleTypographyTokens(
      display: 40,
      h1: 30,
      h2: 22,
      h3: 16,
      body: 15,
      caption: 12,
      label: 11,
      technical: 12,
    ),
    image: BibleImageTokens(
      defaultRatio: '2.39:1',
      defaultFit: 'cover',
      overlayOpacity: 0.15,
    ),
  );
}
