import '../../core/settings/app_prefs.dart';

/// Ajustes del storyboard: cómo se abre.
abstract final class StoryboardPrefs {
  /// `linear`, `grid` o `list`.
  static const layout = PrefKey<String>('storyboard.layout', 'linear');

  /// `all`, `withImage` o `missing`.
  static const filter = PrefKey<String>('storyboard.filter', 'all');

  static const all = <PrefKey>[layout, filter];
}
