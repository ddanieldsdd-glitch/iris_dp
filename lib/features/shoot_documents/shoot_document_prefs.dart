import '../../core/settings/app_prefs.dart';
import 'shoot_document_block_types.dart';

/// Ajustes de los documentos de rodaje: con qué nace un documento nuevo.
abstract final class ShootDocumentPrefs {
  static const layoutPreset = PrefKey<String>(
    'shootDocs.layoutPreset',
    ShootLayoutPreset.freeform,
  );
  static const coverInPdf = PrefKey<bool>('shootDocs.coverInPdf', true);
  static const showThumbnail = PrefKey<bool>('shootDocs.showThumbnail', true);
  static const showCharacters = PrefKey<bool>('shootDocs.showCharacters', true);
  static const showDuration = PrefKey<bool>('shootDocs.showDuration', true);
  static const showCamera = PrefKey<bool>('shootDocs.showCamera', true);
  static const showAction = PrefKey<bool>('shootDocs.showAction', true);
  static const showScript = PrefKey<bool>('shootDocs.showScript', true);

  static const all = <PrefKey>[
    layoutPreset,
    coverInPdf,
    showThumbnail,
    showCharacters,
    showDuration,
    showCamera,
    showAction,
    showScript,
  ];

  static ShootBlockVisibility visibility(int projectId) {
    final p = AppPrefs.instance;
    bool v(PrefKey<bool> k) => p.get(k, projectId: projectId);
    return ShootBlockVisibility(
      showThumbnail: v(showThumbnail),
      showCharacters: v(showCharacters),
      showDuration: v(showDuration),
      showCamera: v(showCamera),
      showAction: v(showAction),
      showScript: v(showScript),
    );
  }
}
