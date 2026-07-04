/// Formato consistente de metadatos de escena en toda la app.
String locationFromCanonical(String canonical) {
  final match =
      RegExp(r'^[A-Z/]+\.\s*(.+?)\s*-\s*.+$').firstMatch(canonical.trim());
  return match?.group(1)?.trim() ?? canonical.trim();
}

String formatSceneMetaLine({
  required String intExt,
  required String dayNight,
  required String location,
}) =>
    '$intExt · $dayNight · $location';

String formatSceneDefaultName({
  required String intExt,
  required String dayNight,
  required String location,
}) =>
    '$intExt $dayNight $location';

String formatSceneTitle({
  required int number,
  required String intExt,
  required String dayNight,
  required String location,
}) =>
    '$number. ${formatSceneMetaLine(intExt: intExt, dayNight: dayNight, location: location)}';
