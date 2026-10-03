/// Tipos de referencia de dirección: qué aporta la obra citada.
const kDirectionReferenceKinds = [
  'Emoción',
  'Historia',
  'Tema',
  'Puesta en escena',
  'Personaje',
  'Ritmo',
  'Visual',
];

/// Referencia cinematográfica de Dirección.
///
/// No es solo una imagen: explica por qué el director cita la obra y para
/// qué la quiere en la película. Se guarda en `directionData.refsMetadata`.
class DirectionReference {
  /// Obra y autor («Fincher / Se7en»).
  final String work;

  /// La idea que se toma de la obra.
  final String title;

  /// Uno de [kDirectionReferenceKinds], o vacío.
  final String kind;

  /// Por qué esta referencia: qué tiene la obra.
  final String why;

  /// Para qué en nuestra película: qué se quiere contar con ella.
  final String purpose;

  /// Escena o momento concreto de la obra.
  final String scene;

  /// Imagen del moodboard vinculada, si la hay.
  final int? imageId;

  /// Fichas antiguas emparejaban imagen y ficha por posición.
  final bool legacyPairing;

  final String lens;
  final String techLabel;
  final String techValue;

  const DirectionReference({
    this.work = '',
    this.title = '',
    this.kind = '',
    this.why = '',
    this.purpose = '',
    this.scene = '',
    this.imageId,
    this.legacyPairing = false,
    this.lens = '',
    this.techLabel = '',
    this.techValue = '',
  });

  bool get isEmpty =>
      work.isEmpty && title.isEmpty && why.isEmpty && purpose.isEmpty;

  factory DirectionReference.fromJson(Map<dynamic, dynamic> json) {
    String text(String key) => json[key]?.toString().trim() ?? '';
    final rawImage = json['imageId'];
    return DirectionReference(
      work: text('refLabel'),
      title: text('title'),
      kind: text('kind'),
      // Las fichas antiguas solo tenían «Notas» (`body`).
      why: text('why').isNotEmpty ? text('why') : text('body'),
      purpose: text('purpose'),
      scene: text('scene'),
      imageId: rawImage is num ? rawImage.toInt() : null,
      legacyPairing: !json.containsKey('imageId'),
      lens: text('lens'),
      techLabel: text('tech2Label'),
      techValue: text('tech2Value'),
    );
  }

  Map<String, dynamic> toJson() => {
        'refLabel': work,
        'title': title,
        'kind': kind,
        'why': why,
        'purpose': purpose,
        'scene': scene,
        'imageId': imageId,
        if (lens.isNotEmpty) 'lens': lens,
        if (techLabel.isNotEmpty) 'tech2Label': techLabel,
        if (techValue.isNotEmpty) 'tech2Value': techValue,
      };

  static List<DirectionReference> listFrom(Object? raw) => [
        if (raw is List)
          for (final entry in raw)
            if (entry is Map) DirectionReference.fromJson(entry),
      ];

  /// Imagen de cada ficha: la vinculada, o la de su posición en las antiguas.
  static List<int?> resolveImages(
    List<DirectionReference> references,
    List<int> imageIds,
  ) =>
      [
        for (var i = 0; i < references.length; i++)
          references[i].legacyPairing
              ? (i < imageIds.length ? imageIds[i] : null)
              : (imageIds.contains(references[i].imageId)
                  ? references[i].imageId
                  : null),
      ];
}
