import 'bible_json_parse.dart';

/// Estilo visual por bloque (override sobre theme de página).
class BibleBlockStyle {
  final double? padding;
  final double? radius;
  final double? borderWidth;
  final String? borderColor;
  final String? backgroundColor;
  final String? textColor;
  final double? opacity;
  final bool? showCard;

  const BibleBlockStyle({
    this.padding,
    this.radius,
    this.borderWidth,
    this.borderColor,
    this.backgroundColor,
    this.textColor,
    this.opacity,
    this.showCard,
  });

  Map<String, dynamic> toJson() => {
    if (padding != null) 'padding': padding,
    if (radius != null) 'radius': radius,
    if (borderWidth != null) 'borderWidth': borderWidth,
    if (borderColor != null) 'borderColor': borderColor,
    if (backgroundColor != null) 'backgroundColor': backgroundColor,
    if (textColor != null) 'textColor': textColor,
    if (opacity != null) 'opacity': opacity,
    if (showCard != null) 'showCard': showCard,
  };

  factory BibleBlockStyle.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const BibleBlockStyle();
    return BibleBlockStyle(
      padding: bibleJsonDouble(json['padding']),
      radius: bibleJsonDouble(json['radius']),
      borderWidth: bibleJsonDouble(json['borderWidth']),
      borderColor: json['borderColor']?.toString(),
      backgroundColor: json['backgroundColor']?.toString(),
      textColor: json['textColor']?.toString(),
      opacity: bibleJsonDouble(json['opacity']),
      showCard: json['showCard'] as bool?,
    );
  }

  BibleBlockStyle copyWith({
    double? padding,
    double? radius,
    double? borderWidth,
    String? borderColor,
    String? backgroundColor,
    String? textColor,
    double? opacity,
    bool? showCard,
  }) {
    return BibleBlockStyle(
      padding: padding ?? this.padding,
      radius: radius ?? this.radius,
      borderWidth: borderWidth ?? this.borderWidth,
      borderColor: borderColor ?? this.borderColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      opacity: opacity ?? this.opacity,
      showCard: showCard ?? this.showCard,
    );
  }
}
