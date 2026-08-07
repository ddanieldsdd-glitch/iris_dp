import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import 'user_template_models.dart';
import 'user_template_preferences.dart';

/// CRUD y aplicación de plantillas de usuario.
abstract final class UserTemplateService {
  UserTemplateService._();

  static Stream<List<UserTemplate>> watchTemplates(
    AppDatabase db,
    UserTemplateType type,
  ) =>
      (db.select(db.userTemplates)
            ..where((t) => t.type.equals(type.storageKey))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .watch();

  static Future<List<UserTemplate>> listTemplates(
    AppDatabase db,
    UserTemplateType type,
  ) =>
      (db.select(db.userTemplates)
            ..where((t) => t.type.equals(type.storageKey))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .get();

  static Future<UserTemplate?> getTemplate(AppDatabase db, String id) =>
      (db.select(db.userTemplates)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  static Future<String> saveBibleLayoutTemplate({
    required AppDatabase db,
    required String name,
    required int bibleId,
    String? description,
    String? existingId,
  }) async {
    final groups = await (db.select(db.bibleSectionGroups)
          ..where((g) => g.bibleId.equals(bibleId)))
        .get();
    final sections = await (db.select(db.bibleSectionDefinitions)
          ..where((d) => d.bibleId.equals(bibleId)))
        .get();

    final payload = BibleLayoutTemplatePayload(
      groups: groups
          .map(
            (g) => BibleLayoutGroupPayload(
              id: g.id,
              label: g.label,
              sortOrder: g.sortOrder,
              isBuiltIn: g.isBuiltIn,
            ),
          )
          .toList(),
      sections: sections
          .map(
            (s) => BibleLayoutSectionPayload(
              id: s.id,
              groupId: s.groupId,
              label: s.label,
              iconKey: s.iconKey,
              sortOrder: s.sortOrder,
              isBuiltIn: s.isBuiltIn,
              isHidden: s.isHidden,
              template: s.template,
              contentJson: s.contentJson,
            ),
          )
          .toList(),
    );

    return _upsert(
      db: db,
      type: UserTemplateType.bibleLayout,
      name: name,
      description: description,
      payloadJson: payload.encode(),
      existingId: existingId,
    );
  }

  static Future<String> saveShootDocumentTemplate({
    required AppDatabase db,
    required String name,
    required int documentId,
    String? description,
    String? existingId,
  }) async {
    final doc = await db.getShootDocument(documentId);
    if (doc == null) throw StateError('Documento no encontrado');
    final blocks = await db.getBlocksForShootDocument(documentId);

    final payload = ShootDocumentTemplatePayload(
      layoutPreset: doc.layoutPreset,
      defaultVisibilityJson: doc.defaultVisibilityJson,
      includeCoverInPdf: doc.includeCoverInPdf,
      blocks: blocks
          .map(
            (b) => ShootDocumentBlockBlueprint(
              blockType: b.blockType,
              sortOrder: b.sortOrder,
              customLabel: b.customLabel,
              noteBody: b.noteBody,
              visibilityJson: b.visibilityJson,
              contentOverridesJson: b.contentOverridesJson,
            ),
          )
          .toList(),
    );

    return saveShootDocumentTemplateFromPayload(
      db: db,
      name: name,
      description: description,
      payload: payload,
      existingId: existingId,
    );
  }

  static Future<String> saveShootDocumentTemplateFromPayload({
    required AppDatabase db,
    required String name,
    required ShootDocumentTemplatePayload payload,
    String? description,
    String? existingId,
  }) async {
    return _upsert(
      db: db,
      type: UserTemplateType.shootDocument,
      name: name,
      description: description,
      payloadJson: payload.encode(),
      existingId: existingId,
    );
  }

  static Future<String> _upsert({
    required AppDatabase db,
    required UserTemplateType type,
    required String name,
    required String payloadJson,
    String? description,
    String? existingId,
  }) async {
    final id = existingId ?? const Uuid().v4();
    final now = DateTime.now();
    await db.into(db.userTemplates).insertOnConflictUpdate(
          UserTemplatesCompanion.insert(
            id: id,
            type: type.storageKey,
            name: name,
            description: Value(description),
            payloadJson: payloadJson,
            updatedAt: Value(now),
          ),
        );
    return id;
  }

  /// Upsert genérico (p. ej. BiblePresetBundle encode).
  static Future<String> upsertRaw({
    required AppDatabase db,
    required UserTemplateType type,
    required String name,
    required String payloadJson,
    String? description,
    String? existingId,
  }) =>
      _upsert(
        db: db,
        type: type,
        name: name,
        payloadJson: payloadJson,
        description: description,
        existingId: existingId,
      );

  static Future<void> deleteTemplate(AppDatabase db, String id) async {
    await (db.delete(db.userTemplates)..where((t) => t.id.equals(id))).go();
  }

  static Future<void> setDefaultTemplate(
    AppDatabase db,
    UserTemplateType type,
    String? templateId,
  ) async {
    await db.transaction(() async {
      final all = await (db.select(db.userTemplates)
            ..where((t) => t.type.equals(type.storageKey)))
          .get();
      for (final row in all) {
        await (db.update(db.userTemplates)..where((t) => t.id.equals(row.id)))
            .write(
          UserTemplatesCompanion(
            isDefault: Value(row.id == templateId),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    });

    final prefs = await UserTemplatePreferences.load();
    if (type == UserTemplateType.bibleLayout) {
      prefs.defaultBibleLayoutTemplateId = templateId;
    } else {
      prefs.defaultShootDocTemplateId = templateId;
    }
    await prefs.save();
  }

  static Future<void> applyBibleLayoutTemplate({
    required AppDatabase db,
    required int bibleId,
    required String templateId,
  }) async {
    if (templateId == kBuiltinBibleLayoutTemplateId) {
      await db.resetBibleSectionLayoutToBuiltin(bibleId);
      return;
    }

    final template = await getTemplate(db, templateId);
    if (template == null) return;

    // Bundle v1 anida el layout bajo "layout"; legacy es el payload directo.
    try {
      final decoded = jsonDecode(template.payloadJson);
      if (decoded is Map && decoded['layout'] is Map) {
        await db.applyBibleLayoutTemplate(
          bibleId,
          BibleLayoutTemplatePayload.fromJson(
            Map<String, dynamic>.from(decoded['layout'] as Map),
          ),
        );
        return;
      }
    } catch (_) {}

    final payload = BibleLayoutTemplatePayload.decode(template.payloadJson);
    await db.applyBibleLayoutTemplate(bibleId, payload);
  }

  static Future<int> createShootDocumentFromUserTemplate({
    required AppDatabase db,
    required int projectId,
    required String name,
    required String templateId,
  }) async {
    if (templateId == kBuiltinShootDocTemplateId) {
      return _createEmptyShootDocument(db: db, projectId: projectId, name: name);
    }

    final template = await getTemplate(db, templateId);
    if (template == null) {
      return _createEmptyShootDocument(db: db, projectId: projectId, name: name);
    }

    final payload = ShootDocumentTemplatePayload.decode(template.payloadJson);
    final docId = await db.insertShootDocument(
      ShootDocumentsCompanion.insert(
        projectId: projectId,
        name: name,
        layoutPreset: Value(payload.layoutPreset),
        defaultVisibilityJson: Value(payload.defaultVisibilityJson),
        includeCoverInPdf: Value(payload.includeCoverInPdf),
      ),
    );

    for (final blueprint in payload.blocks) {
      await db.insertShootDocumentBlock(
        ShootDocumentBlocksCompanion.insert(
          documentId: docId,
          sortOrder: Value(blueprint.sortOrder),
          blockType: blueprint.blockType,
          customLabel: Value(blueprint.customLabel),
          noteBody: Value(blueprint.noteBody),
          visibilityJson: Value(blueprint.visibilityJson),
          contentOverridesJson: Value(blueprint.contentOverridesJson),
        ),
      );
    }
    return docId;
  }

  static Future<void> maybeApplyBibleTemplateOnCreate({
    required AppDatabase db,
    required int projectId,
    required int bibleId,
  }) async {
    final prefs = await UserTemplatePreferences.load();
    if (prefs.bibleAutoApply == TemplateAutoApplyMode.never ||
        prefs.bibleAutoApply == TemplateAutoApplyMode.ask) {
      return;
    }

    final templateId = prefs.bibleTemplateForProject(projectId);
    if (templateId == null || templateId.isEmpty) return;

    await applyBibleLayoutTemplate(
      db: db,
      bibleId: bibleId,
      templateId: templateId,
    );
  }

  static Future<int> _createEmptyShootDocument({
    required AppDatabase db,
    required int projectId,
    required String name,
  }) =>
      db.insertShootDocument(
        ShootDocumentsCompanion.insert(
          projectId: projectId,
          name: name,
          layoutPreset: const Value('freeform'),
        ),
      );
}
