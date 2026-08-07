import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/templates/user_template_models.dart';
import '../../core/templates/user_template_preferences.dart';
import '../../core/templates/user_template_service.dart';
import '../../core/cloud/cloud_providers.dart';
import '../../core/templates/user_settings_sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_snackbar.dart';

/// Sección de ajustes para plantillas de biblia y documentos de rodaje.
class UserTemplatesSettingsSection extends ConsumerStatefulWidget {
  const UserTemplatesSettingsSection({
    super.key,
    this.onCreateTemplate,
    this.onEditShootTemplate,
  });

  final VoidCallback? onCreateTemplate;
  final Future<bool> Function(String templateId)? onEditShootTemplate;

  @override
  ConsumerState<UserTemplatesSettingsSection> createState() =>
      _UserTemplatesSettingsSectionState();
}

class _UserTemplatesSettingsSectionState
    extends ConsumerState<UserTemplatesSettingsSection> {
  UserTemplatePreferences? _prefs;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await UserTemplatePreferences.load();
    if (mounted) {
      setState(() {
        _prefs = prefs;
        _loading = false;
      });
    }
  }

  Future<void> _savePrefs() async {
    await _prefs?.save();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (_loading || _prefs == null) {
      return const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final prefs = _prefs!;
    final db = ref.watch(databaseProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Plantillas personalizadas', style: AppTypography.titleMedium(palette)),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Guarda estructuras de biblia y documentos de rodaje como plantillas '
          'reutilizables. Elige cuándo aplicarlas automáticamente.',
          style: AppTypography.caption(palette),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Biblia visual', style: AppTypography.label(palette)),
        const SizedBox(height: AppSpacing.xs),
        _TemplatePicker(
          palette: palette,
          type: UserTemplateType.bibleLayout,
          db: db,
          selectedId: prefs.defaultBibleLayoutTemplateId,
          onSelected: (id) async {
            prefs.defaultBibleLayoutTemplateId = id;
            if (id != null && id != kBuiltinBibleLayoutTemplateId) {
              await UserTemplateService.setDefaultTemplate(
                db,
                UserTemplateType.bibleLayout,
                id,
              );
            }
            await _savePrefs();
            setState(() {});
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        _AutoApplyDropdown(
          palette: palette,
          value: prefs.bibleAutoApply,
          onChanged: (mode) async {
            prefs.bibleAutoApply = mode;
            await _savePrefs();
            setState(() {});
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Documentos de rodaje', style: AppTypography.label(palette)),
        const SizedBox(height: AppSpacing.xs),
        _TemplatePicker(
          palette: palette,
          type: UserTemplateType.shootDocument,
          db: db,
          selectedId: prefs.defaultShootDocTemplateId,
          onSelected: (id) async {
            prefs.defaultShootDocTemplateId = id;
            if (id != null && id != kBuiltinShootDocTemplateId) {
              await UserTemplateService.setDefaultTemplate(
                db,
                UserTemplateType.shootDocument,
                id,
              );
            }
            await _savePrefs();
            setState(() {});
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        _AutoApplyDropdown(
          palette: palette,
          value: prefs.shootDocAutoApply,
          onChanged: (mode) async {
            prefs.shootDocAutoApply = mode;
            await _savePrefs();
            setState(() {});
          },
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final client = ref.read(supabaseClientProvider);
                  if (client == null || client.auth.currentUser == null) {
                    if (context.mounted) {
                      AppSnackBar.show(
                        context,
                        'Inicia sesión en la nube para sincronizar plantillas.',
                      );
                    }
                    return;
                  }
                  final result = await UserSettingsSyncService.sync(
                    db: db,
                    client: client,
                  );
                  if (context.mounted) {
                    AppSnackBar.show(
                      context,
                      result.pulled || result.pushed
                          ? 'Plantillas sincronizadas con tu perfil'
                          : 'Ya estaban al día',
                    );
                    setState(() {});
                  }
                },
                icon: const Icon(Icons.cloud_sync_outlined, size: 18),
                label: const Text('Sincronizar con la nube'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: widget.onCreateTemplate,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Crear plantilla de documento de rodaje'),
        ),
        const SizedBox(height: AppSpacing.md),
        StreamBuilder<List<UserTemplate>>(
          stream: UserTemplateService.watchTemplates(
            db,
            UserTemplateType.bibleLayout,
          ),
          builder: (context, bibleSnap) {
            return StreamBuilder<List<UserTemplate>>(
              stream: UserTemplateService.watchTemplates(
                db,
                UserTemplateType.shootDocument,
              ),
              builder: (context, shootSnap) {
                final bibleTemplates = bibleSnap.data ?? [];
                final shootTemplates = shootSnap.data ?? [];
                if (bibleTemplates.isEmpty && shootTemplates.isEmpty) {
                  return Text(
                    'Aún no hay plantillas guardadas. Créalas desde '
                    '«Editar estructura» en la biblia o desde un documento de rodaje.',
                    style: AppTypography.caption(palette),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (bibleTemplates.isNotEmpty) ...[
                      Text('Plantillas de biblia',
                          style: AppTypography.caption(palette)),
                      ...bibleTemplates.map(
                        (t) => _TemplateRow(
                          palette: palette,
                          template: t,
                          onDelete: () async {
                            await UserTemplateService.deleteTemplate(db, t.id);
                            if (prefs.defaultBibleLayoutTemplateId == t.id) {
                              prefs.defaultBibleLayoutTemplateId = null;
                              await _savePrefs();
                            }
                            setState(() {});
                          },
                        ),
                      ),
                    ],
                    if (shootTemplates.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text('Plantillas de documentos',
                          style: AppTypography.caption(palette)),
                      ...shootTemplates.map(
                        (t) => _TemplateRow(
                          palette: palette,
                          template: t,
                          onEdit: widget.onEditShootTemplate == null
                              ? null
                              : () async {
                                  final ok = await widget.onEditShootTemplate!(
                                    t.id,
                                  );
                                  if (ok == true && mounted) setState(() {});
                                },
                          onDelete: () async {
                            await UserTemplateService.deleteTemplate(db, t.id);
                            if (prefs.defaultShootDocTemplateId == t.id) {
                              prefs.defaultShootDocTemplateId = null;
                              await _savePrefs();
                            }
                            setState(() {});
                          },
                        ),
                      ),
                    ],
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _TemplatePicker extends StatelessWidget {
  final AppPalette palette;
  final UserTemplateType type;
  final AppDatabase db;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  const _TemplatePicker({
    required this.palette,
    required this.type,
    required this.db,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserTemplate>>(
      stream: UserTemplateService.watchTemplates(db, type),
      builder: (context, snap) {
        final userTemplates = snap.data ?? [];
        final items = <DropdownMenuItem<String?>>[
          DropdownMenuItem<String?>(
            value: null,
            child: Text(
              type == UserTemplateType.bibleLayout
                  ? 'Plantilla IRIS (base de fotografía)'
                  : 'Sin plantilla predeterminada',
              style: AppTypography.bodyMedium(palette),
            ),
          ),
          ...userTemplates.map(
            (t) => DropdownMenuItem<String?>(
              value: t.id,
              child: Text(t.name, style: AppTypography.bodyMedium(palette)),
            ),
          ),
        ];

        return DropdownButtonFormField<String?>(
          initialValue: selectedId != null &&
                  userTemplates.any((t) => t.id == selectedId)
              ? selectedId
              : null,
          decoration: InputDecoration(
            labelText: 'Plantilla predeterminada',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: items,
          onChanged: onSelected,
        );
      },
    );
  }
}

class _AutoApplyDropdown extends StatelessWidget {
  final AppPalette palette;
  final TemplateAutoApplyMode value;
  final ValueChanged<TemplateAutoApplyMode> onChanged;

  const _AutoApplyDropdown({
    required this.palette,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<TemplateAutoApplyMode>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: 'Aplicación automática',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: TemplateAutoApplyMode.values
          .map(
            (m) => DropdownMenuItem(
              value: m,
              child: Text(m.label, style: AppTypography.bodyMedium(palette)),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _TemplateRow extends StatelessWidget {
  final AppPalette palette;
  final UserTemplate template;
  final VoidCallback? onEdit;
  final VoidCallback onDelete;

  const _TemplateRow({
    required this.palette,
    required this.template,
    this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        template.type == UserTemplateType.bibleLayout.storageKey
            ? Icons.menu_book_outlined
            : Icons.description_outlined,
        size: 18,
        color: palette.accent,
      ),
      title: Text(template.name, style: AppTypography.bodyMedium(palette)),
      subtitle: template.description != null
          ? Text(template.description!, style: AppTypography.caption(palette))
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onEdit != null)
            IconButton(
              icon: Icon(Icons.edit_outlined, color: palette.accent, size: 18),
              onPressed: onEdit,
            ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: palette.error, size: 18),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

/// Diálogo para guardar estructura actual como plantilla.
Future<String?> promptSaveUserTemplate(
  BuildContext context, {
  required String title,
  String initialName = '',
}) async {
  final controller = TextEditingController(text: initialName);
  final descController = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nombre de la plantilla'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descController,
            decoration: const InputDecoration(
              labelText: 'Descripción (opcional)',
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final name = controller.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(ctx, name);
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}
