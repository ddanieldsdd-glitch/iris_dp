import '../../core/database/app_database.dart';

/// Localización elegida y el set dentro de ella. Sin set propio, [set] es el
/// set base de la localización (la localización entera).
class LocationChoice {
  final LocationSite site;
  final LocationBasePlan set;

  const LocationChoice({required this.site, required this.set});

  /// El set es la localización entera, no una zona de ella.
  bool get isWholeSite =>
      set.locationName.trim().toLowerCase() == site.name.trim().toLowerCase();

  /// Cómo se nombra el lugar en la escena.
  String get placeName => isWholeSite ? site.name : set.locationName;

  String get label =>
      isWholeSite ? site.name : '${site.name} › ${set.locationName}';
}
