import '../../bible_block_catalog.dart';
import 'bible_block_layout.dart';
import 'bible_block_style.dart';
import 'project_entity_reference.dart';

/// Instancia configurable de un widget de Biblia (extiende [BibleBlockKind]).
class BibleBlock {
  final String id;
  final BibleBlockKind type;
  final BibleBlockLayout layout;
  final BibleBlockStyle style;

  /// Payload tipado por kind (texto, image, chips, specs…).
  final Map<String, dynamic> content;

  final ProjectEntityReference? binding;

  const BibleBlock({
    required this.id,
    required this.type,
    this.layout = const BibleBlockLayout(),
    this.style = const BibleBlockStyle(),
    this.content = const {},
    this.binding,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'layout': layout.toJson(),
    'style': style.toJson(),
    'content': content,
    if (binding != null) 'binding': binding!.toJson(),
  };

  factory BibleBlock.fromJson(Map<String, dynamic> json) {
    final typeName = json['type']?.toString() ?? 'text';
    final type = BibleBlockKind.values.firstWhere(
      (k) => k.name == typeName,
      orElse: () => BibleBlockKind.text,
    );
    return BibleBlock(
      id: json['id']?.toString() ?? '',
      type: type,
      layout: BibleBlockLayout.fromJson(
        json['layout'] is Map
            ? Map<String, dynamic>.from(json['layout'] as Map)
            : null,
      ),
      style: BibleBlockStyle.fromJson(
        json['style'] is Map
            ? Map<String, dynamic>.from(json['style'] as Map)
            : null,
      ),
      content: json['content'] is Map
          ? Map<String, dynamic>.from(json['content'] as Map)
          : const {},
      binding: json['binding'] is Map
          ? ProjectEntityReference.fromJson(
              Map<String, dynamic>.from(json['binding'] as Map),
            )
          : null,
    );
  }

  BibleBlock copyWith({
    String? id,
    BibleBlockKind? type,
    BibleBlockLayout? layout,
    BibleBlockStyle? style,
    Map<String, dynamic>? content,
    ProjectEntityReference? binding,
  }) {
    return BibleBlock(
      id: id ?? this.id,
      type: type ?? this.type,
      layout: layout ?? this.layout,
      style: style ?? this.style,
      content: content ?? this.content,
      binding: binding ?? this.binding,
    );
  }
}
