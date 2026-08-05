import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/templates/user_template_models.dart';
import '../../core/templates/user_template_preferences.dart';
import '../../core/templates/user_template_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'shoot_document_composer.dart';
import 'shoot_template_editor_screen.dart';

/// Resultado al elegir plantilla para crear un documento de rodaje.
class ShootDocumentCreationChoice {
  final String? userTemplateId;
  final ShootDocumentTemplate? builtinTemplate;
  final bool createTemplate;

  const ShootDocumentCreationChoice({
    this.userTemplateId,
    this.builtinTemplate,
    this.createTemplate = false,
  });

  bool get isUserTemplate =>
      userTemplateId != null && userTemplateId!.isNotEmpty;
}

/// Resuelve qué plantilla usar al crear un documento (auto / preguntar / nunca).
Future<ShootDocumentCreationChoice?> resolveShootDocumentCreationTemplate({
  required BuildContext context,
  required AppDatabase db,
  required int projectId,
}) async {
  final prefs = await UserTemplatePreferences.load();

  if (prefs.shootDocAutoApply == TemplateAutoApplyMode.always) {
    final templateId = prefs.shootDocTemplateForProject(projectId);
    if (templateId != null && templateId.isNotEmpty) {
      return ShootDocumentCreationChoice(userTemplateId: templateId);
    }
    return const ShootDocumentCreationChoice(
      builtinTemplate: ShootDocumentTemplate.empty,
    );
  }

  if (prefs.shootDocAutoApply == TemplateAutoApplyMode.never) {
    return const ShootDocumentCreationChoice(
      builtinTemplate: ShootDocumentTemplate.empty,
    );
  }

  final userTemplates = await UserTemplateService.listTemplates(
    db,
    UserTemplateType.shootDocument,
  );

  return showModalBottomSheet<ShootDocumentCreationChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.palette.surfaceElevated,
    builder: (ctx) => _ShootTemplatePickerSheet(
      userTemplates: userTemplates,
      prefs: prefs,
      projectId: projectId,
    ),
  );
}

class _ShootTemplatePickerSheet extends StatelessWidget {
  final List<UserTemplate> userTemplates;
  final UserTemplatePreferences prefs;
  final int projectId;

  const _ShootTemplatePickerSheet({
    required this.userTemplates,
    required this.prefs,
    required this.projectId,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Plantilla del documento',
              style: AppTypography.titleMedium(palette),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Elige cómo crear el documento. Puedes guardar tu propia '
              'estructura desde el editor.',
              style: AppTypography.caption(palette),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final template in ShootDocumentTemplate.values)
              ListTile(
                leading: Icon(Icons.description_outlined, color: palette.accent),
                title: Text(template.label, style: AppTypography.bodyMedium(palette)),
                subtitle: Text(template.description, style: AppTypography.caption(palette)),
                onTap: () => Navigator.pop(
                  context,
                  ShootDocumentCreationChoice(builtinTemplate: template),
                ),
              ),
            if (userTemplates.isNotEmpty) ...[
              const Divider(height: 24),
              Text('Mis plantillas', style: AppTypography.label(palette)),
              const SizedBox(height: AppSpacing.sm),
              for (final t in userTemplates)
                ListTile(
                  leading: Icon(Icons.bookmark_outline, color: palette.accent),
                  title: Text(t.name, style: AppTypography.bodyMedium(palette)),
                  subtitle: t.description != null
                      ? Text(t.description!, style: AppTypography.caption(palette))
                      : null,
                  onTap: () => Navigator.pop(
                    context,
                    ShootDocumentCreationChoice(userTemplateId: t.id),
                  ),
                ),
            ],
            ListTile(
              leading: Icon(Icons.add_circle_outline, color: palette.accent),
              title: Text(
                'Crear nueva plantilla visual…',
                style: AppTypography.bodyMedium(palette)
                    .copyWith(color: palette.accent),
              ),
              onTap: () {
                Navigator.pop(context, const ShootDocumentCreationChoice(
                  createTemplate: true,
                ));
              },
            ),
            if (prefs.shootDocAutoApply == TemplateAutoApplyMode.perProject) ...[
              const Divider(height: 16),
              Text(
                'Modo «por proyecto»: puedes fijar una plantilla distinta '
                'para este proyecto en Ajustes.',
                style: AppTypography.caption(palette),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
