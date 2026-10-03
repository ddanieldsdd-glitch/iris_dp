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

/// Tipos de referencia visual de Concepto: qué aspecto de la imagen interesa.
const kConceptReferenceKinds = [
  'Luz',
  'Color',
  'Composición',
  'Textura',
  'Atmósfera',
  'Movimiento',
];

/// Tipos de referencia técnica: qué se quiere reproducir.
const kTechnicalReferenceKinds = [
  'Cámara',
  'Óptica',
  'Iluminación',
  'Movimiento',
  'Color',
  'Efecto',
];

/// Referencia razonada de la biblia (Dirección, Concepto).
///
/// No es solo una imagen: explica por qué se cita la obra y para qué se
/// quiere en la película. Se guarda en el blob de la sección.
class BibleReference {
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

  const BibleReference({
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

  factory BibleReference.fromJson(Map<dynamic, dynamic> json) {
    String text(String key) => json[key]?.toString().trim() ?? '';
    String first(List<String> keys) =>
        keys.map(text).firstWhere((v) => v.isNotEmpty, orElse: () => '');
    // Fichas antiguas de Concepto: film, dp, director, tone, intent.
    final credit = [text('dp'), text('director')].where((e) => e.isNotEmpty);
    final rawImage = json['imageId'];
    return BibleReference(
      work: text('refLabel').isNotEmpty
          ? text('refLabel')
          : [text('film'), ...credit].where((e) => e.isNotEmpty).join(' · '),
      title: first(['title', 'film']),
      kind: text('kind'),
      // Las fichas antiguas solo tenían «Notas» (`body`).
      why: first(['why', 'body', 'tone']),
      purpose: first(['purpose', 'intent']),
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

  static List<BibleReference> listFrom(Object? raw) => [
        if (raw is List)
          for (final entry in raw)
            if (entry is Map) BibleReference.fromJson(entry),
      ];

  /// Imagen de cada ficha: la vinculada, o la de su posición en las antiguas.
  static List<int?> resolveImages(
    List<BibleReference> references,
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
