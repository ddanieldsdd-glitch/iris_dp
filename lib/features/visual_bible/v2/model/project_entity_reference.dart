/// Referencia a una entidad del proyecto (Connected vs Snapshot).
class ProjectEntityReference {
  /// camera | lens | light | location | scene | moodboardImage | shot | workflow
  final String entity;
  final String id;

  /// connected | snapshot
  final String mode;

  /// Copia local si mode == snapshot.
  final Map<String, dynamic>? snapshot;

  const ProjectEntityReference({
    required this.entity,
    required this.id,
    this.mode = 'connected',
    this.snapshot,
  });

  Map<String, dynamic> toJson() => {
    'entity': entity,
    'id': id,
    'mode': mode,
    if (snapshot != null) 'snapshot': snapshot,
  };

  factory ProjectEntityReference.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ProjectEntityReference(entity: '', id: '');
    }
    return ProjectEntityReference(
      entity: json['entity']?.toString() ?? '',
      id: json['id']?.toString() ?? '',
      mode: json['mode']?.toString() ?? 'connected',
      snapshot: json['snapshot'] is Map
          ? Map<String, dynamic>.from(json['snapshot'] as Map)
          : null,
    );
  }
}
