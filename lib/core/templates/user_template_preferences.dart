import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'user_template_models.dart';

/// Preferencias de plantillas del usuario (perfil local).
class UserTemplatePreferences {
  static const _prefix = 'iris_user_templates_';

  String? defaultBibleLayoutTemplateId;
  String? defaultShootDocTemplateId;
  TemplateAutoApplyMode bibleAutoApply;
  TemplateAutoApplyMode shootDocAutoApply;
  final Map<int, String> projectBibleTemplateIds;
  final Map<int, String> projectShootDocTemplateIds;

  UserTemplatePreferences({
    this.defaultBibleLayoutTemplateId,
    this.defaultShootDocTemplateId,
    this.bibleAutoApply = TemplateAutoApplyMode.ask,
    this.shootDocAutoApply = TemplateAutoApplyMode.ask,
    Map<int, String>? projectBibleTemplateIds,
    Map<int, String>? projectShootDocTemplateIds,
  })  : projectBibleTemplateIds = projectBibleTemplateIds ?? {},
        projectShootDocTemplateIds = projectShootDocTemplateIds ?? {};

  static Future<UserTemplatePreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    final bibleDefault = prefs.getString('${_prefix}default_bible');
    final shootDefault = prefs.getString('${_prefix}default_shoot_doc');
    return UserTemplatePreferences(
      defaultBibleLayoutTemplateId:
          bibleDefault != null && bibleDefault.isNotEmpty ? bibleDefault : null,
      defaultShootDocTemplateId:
          shootDefault != null && shootDefault.isNotEmpty ? shootDefault : null,
      bibleAutoApply: TemplateAutoApplyModeX.fromStorageKey(
        prefs.getString('${_prefix}bible_auto_apply'),
      ),
      shootDocAutoApply: TemplateAutoApplyModeX.fromStorageKey(
        prefs.getString('${_prefix}shoot_auto_apply'),
      ),
      projectBibleTemplateIds: _decodeProjectMap(
        prefs.getString('${_prefix}project_bible'),
      ),
      projectShootDocTemplateIds: _decodeProjectMap(
        prefs.getString('${_prefix}project_shoot_doc'),
      ),
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    if (defaultBibleLayoutTemplateId != null) {
      await prefs.setString(
        '${_prefix}default_bible',
        defaultBibleLayoutTemplateId!,
      );
    } else {
      await prefs.remove('${_prefix}default_bible');
    }
    if (defaultShootDocTemplateId != null) {
      await prefs.setString(
        '${_prefix}default_shoot_doc',
        defaultShootDocTemplateId!,
      );
    } else {
      await prefs.remove('${_prefix}default_shoot_doc');
    }
    await prefs.setString(
      '${_prefix}bible_auto_apply',
      bibleAutoApply.storageKey,
    );
    await prefs.setString(
      '${_prefix}shoot_auto_apply',
      shootDocAutoApply.storageKey,
    );
    await prefs.setString(
      '${_prefix}project_bible',
      jsonEncode(projectBibleTemplateIds.map(
        (k, v) => MapEntry(k.toString(), v),
      )),
    );
    await prefs.setString(
      '${_prefix}project_shoot_doc',
      jsonEncode(projectShootDocTemplateIds.map(
        (k, v) => MapEntry(k.toString(), v),
      )),
    );
  }

  String? bibleTemplateForProject(int projectId) {
    if (bibleAutoApply == TemplateAutoApplyMode.perProject) {
      return projectBibleTemplateIds[projectId] ??
          defaultBibleLayoutTemplateId;
    }
    return defaultBibleLayoutTemplateId;
  }

  String? shootDocTemplateForProject(int projectId) {
    if (shootDocAutoApply == TemplateAutoApplyMode.perProject) {
      return projectShootDocTemplateIds[projectId] ??
          defaultShootDocTemplateId;
    }
    return defaultShootDocTemplateId;
  }

  static Map<int, String> _decodeProjectMap(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map(
        (k, v) => MapEntry(int.parse(k.toString()), v.toString()),
      );
    } catch (_) {
      return {};
    }
  }
}
