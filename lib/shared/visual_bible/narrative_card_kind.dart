/// Kinds for [VisualBibleNarrativeCards.kind].
abstract final class NarrativeCardKind {
  static const overview = 'overview';
  static const style = 'style';
  static const filmRef = 'film_ref';
  static const locationLight = 'location_light';

  static const lightingKinds = [
    overview,
    style,
    filmRef,
    locationLight,
  ];

  static String label(String kind) => switch (kind) {
        overview => 'Visión general',
        style => 'Contenedor de luz',
        filmRef => 'Referencia fílmica',
        locationLight => 'Localización (luz)',
        _ => kind,
      };
}
