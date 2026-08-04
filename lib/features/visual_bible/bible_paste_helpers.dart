import '../../core/database/app_database.dart';
import '../../core/utils/clipboard_image_reader.dart';
import '../../core/utils/media_storage.dart';
import 'moodboard_helpers.dart';
import 'visual_bible_model.dart';

/// Utilidades para pegar imágenes en destinos concretos de la biblia.
abstract final class BiblePasteHelpers {
  static Future<ClipboardImageReadStatus> pasteFromClipboard({
    required Future<void> Function(ClipboardImagePayload payload) onPayload,
  }) async {
    final result = await ClipboardImageReader.read();
    if (result.status != ClipboardImageReadStatus.success ||
        result.payload == null) {
      return result.status;
    }
    await onPayload(result.payload!);
    return ClipboardImageReadStatus.success;
  }

  static Future<String?> savePayloadToProject({
    required int projectId,
    required String subfolder,
    required ClipboardImagePayload payload,
    String prefix = 'paste',
  }) async {
    return MediaStorage.writeProjectFileBytes(
      projectId: projectId,
      subfolder: subfolder,
      bytes: payload.bytes,
      fileName: '${prefix}_${DateTime.now().millisecondsSinceEpoch}${payload.extension}',
    );
  }

  static Future<ClipboardImageReadStatus> pasteToMoodboardSection({
    required AppDatabase db,
    required int projectId,
    int? bibleId,
    required String sectionId,
    String? locationName,
    int? locationBasePlanId,
  }) {
    return pasteFromClipboard(
      onPayload: (payload) => MoodboardHelpers.addImageFromBytesAssigned(
        db: db,
        projectId: projectId,
        bibleId: bibleId,
        bytes: payload.bytes,
        extension: payload.extension,
        assignedSections: [
          sectionId,
          if (locationName != null) BibleSectionId.location,
        ],
        linkedLocationName: locationName,
        linkedLocationBasePlanId: locationBasePlanId,
      ),
    );
  }
}
