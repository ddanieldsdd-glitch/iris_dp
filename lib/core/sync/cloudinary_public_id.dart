import '../cloud/cloudinary_config.dart';
import 'media_entity_types.dart';

/// Construye `public_id` ordenado para Cloudinary.
abstract final class CloudinaryPublicId {
  static String build({
    required String workspaceId,
    required String projectCloudId,
    required String category,
    required String contextPath,
    required int sortOrder,
  }) {
    final base =
        '${CloudinaryConfig.rootFolder}/$workspaceId/$projectCloudId/$category/$contextPath/${sortOrderPad(sortOrder)}';
    return base;
  }

  static String moodboard({
    required String workspaceId,
    required String projectCloudId,
    required int groupSortOrder,
    required String groupName,
    required int imageSortOrder,
  }) {
    final groupSlug =
        'g${groupSortOrder.toString().padLeft(3, '0')}_${mediaSlug(groupName)}';
    return build(
      workspaceId: workspaceId,
      projectCloudId: projectCloudId,
      category: MediaEntityType.moodboard,
      contextPath: groupSlug,
      sortOrder: imageSortOrder,
    );
  }

  static String shotReference({
    required String workspaceId,
    required String projectCloudId,
    required int sceneNumber,
    required int shotNumber,
    required int refSortOrder,
  }) {
    final ctx = 'scene${sceneNumber}_shot$shotNumber/refs';
    return build(
      workspaceId: workspaceId,
      projectCloudId: projectCloudId,
      category: MediaEntityType.shotReference,
      contextPath: ctx,
      sortOrder: refSortOrder,
    );
  }

  static String siteImage({
    required String workspaceId,
    required String projectCloudId,
    required int siteSortOrder,
    required String siteName,
    required int imageSortOrder,
  }) {
    final ctx =
        's${siteSortOrder.toString().padLeft(3, '0')}_${mediaSlug(siteName)}';
    return build(
      workspaceId: workspaceId,
      projectCloudId: projectCloudId,
      category: MediaEntityType.site,
      contextPath: ctx,
      sortOrder: imageSortOrder,
    );
  }

  static String locationImage({
    required String workspaceId,
    required String projectCloudId,
    required int setSortOrder,
    required String setName,
    required int imageSortOrder,
  }) {
    final ctx =
        'set${setSortOrder.toString().padLeft(3, '0')}_${mediaSlug(setName)}';
    return build(
      workspaceId: workspaceId,
      projectCloudId: projectCloudId,
      category: MediaEntityType.location,
      contextPath: ctx,
      sortOrder: imageSortOrder,
    );
  }

  static String shootDocumentBlock({
    required String workspaceId,
    required String projectCloudId,
    required int docSortOrder,
    required int blockSortOrder,
  }) {
    final ctx = 'doc${docSortOrder.toString().padLeft(3, '0')}/blocks';
    return build(
      workspaceId: workspaceId,
      projectCloudId: projectCloudId,
      category: MediaEntityType.shootDocument,
      contextPath: ctx,
      sortOrder: blockSortOrder,
    );
  }

  static String projectCover({
    required String workspaceId,
    required String projectCloudId,
  }) {
    return build(
      workspaceId: workspaceId,
      projectCloudId: projectCloudId,
      category: MediaEntityType.projectCover,
      contextPath: 'cover',
      sortOrder: 0,
    );
  }
}
