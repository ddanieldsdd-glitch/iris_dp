import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import 'shoot_document_composer.dart';
import 'shoot_document_editor_screen.dart';
import 'shoot_document_service.dart';
import 'shoot_document_template_picker.dart';
import '../../core/templates/user_template_service.dart';
import 'shoot_template_editor_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'shoot_day_screen.dart';
import '../settings/settings_launcher.dart';
import '../../core/utils/user_error.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../shared/pdf_export/technical_script_pdf.dart';
import '../../shared/technical_script_export/technical_script_docx.dart';
import '../technical_script/script_export_dialog.dart';
import '../technical_script/technical_script_export.dart';
import '../technical_script/technical_script_settings.dart';

/// Hub de documentos para el rodaje — referencia principal en set.
class ShootDocumentsScreen extends ConsumerStatefulWidget {
  final int projectId;
  final String projectName;
  final String projectStatus;

  const ShootDocumentsScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    this.projectStatus = 'preproduction',
  });

  @override
  ConsumerState<ShootDocumentsScreen> createState() =>
      _ShootDocumentsScreenState();
}

class _ShootDocumentsScreenState extends ConsumerState<ShootDocumentsScreen> {
  String? _dateFilter;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);
    final isShooting = widget.projectStatus == 'shooting';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: palette.surface,
        title: Text(
          'Documentos para el rodaje',
          style: AppTypography.titleMedium(palette),
        ),
        actions: [
          ScreenSettingsButton(
            sectionId: SettingsSectionIds.shootDocuments,
            projectId: widget.projectId,
          ),
        ],
      ),
      body: StreamBuilder<List<ShootDocument>>(
        stream: db.watchShootDocumentsForProject(widget.projectId),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final allDocs = snap.data!;
          final dates =
              allDocs
                  .map((d) => d.shootDate)
                  .whereType<String>()
                  .toSet()
                  .toList()
                ..sort();
          final docs = _dateFilter == null
              ? allDocs
              : allDocs.where((d) => d.shootDate == _dateFilter).toList();

          // Por jornada, en orden de fecha; los que no tienen, al final.
          final groups = <String?, List<ShootDocument>>{};
          for (final date in [...dates, null]) {
            final inDate = docs.where((d) => d.shootDate == date).toList();
            if (inDate.isNotEmpty) groups[date] = inDate;
          }

          return StreamBuilder<List<Scene>>(
            stream: db.watchScenesForProject(widget.projectId),
            builder: (context, sceneSnap) {
              final scenes = {
                for (final s in sceneSnap.data ?? const <Scene>[]) s.id: s,
              };
              return LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth - AppSpacing.lg * 2;
                  // Tarjetas de unos 320 px: una columna en el móvil.
                  final columns = (width / 320).floor().clamp(1, 4);
                  final cardWidth =
                      (width - AppSpacing.md * (columns - 1)) / columns;

                  Widget grid(List<Widget> cards) => Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    children: [
                      for (final card in cards)
                        SizedBox(width: cardWidth, child: card),
                    ],
                  );

                  return ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      Text('Crear', style: AppTypography.label(palette)),
                      const SizedBox(height: AppSpacing.sm),
                      grid([
                        _CreateCard(
                          icon: Icons.event_note,
                          title: 'Guion técnico de rodaje',
                          description:
                              'Una jornada: escenas en el orden en que se '
                              'ruedan, con índice, sol y previsión.',
                          highlighted: true,
                          onTap: () => _createShootDay(context),
                        ),
                        _CreateCard(
                          icon: Icons.menu_book_outlined,
                          title: 'Guion técnico completo',
                          description:
                              'Todo el guion técnico en orden de guion, con '
                              'índice. En PDF o Word.',
                          onTap: () => _exportFullScript(context),
                        ),
                        _CreateCard(
                          icon: Icons.dashboard_customize_outlined,
                          title: 'Documento libre',
                          description:
                              'Desde una plantilla: bloques de guion, planos, '
                              'personajes y referencias.',
                          onTap: () => _createDocument(context),
                        ),
                      ]),
                      if (isShooting) ...[
                        const SizedBox(height: AppSpacing.lg),
                        AppCard(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            children: [
                              Icon(Icons.star, color: palette.accent, size: 20),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  'Marca un documento como «activo hoy» para '
                                  'abrirlo rápido en el set.',
                                  style: AppTypography.bodyMedium(palette),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Documentos',
                              style: AppTypography.titleMedium(palette),
                            ),
                          ),
                          Text(
                            '${allDocs.length}',
                            style: AppTypography.caption(palette),
                          ),
                        ],
                      ),
                      if (dates.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            FilterChip(
                              label: const Text('Todas las jornadas'),
                              selected: _dateFilter == null,
                              onSelected: (_) =>
                                  setState(() => _dateFilter = null),
                            ),
                            for (final date in dates)
                              FilterChip(
                                label: Text(_shortDate(date)),
                                selected: _dateFilter == date,
                                onSelected: (_) =>
                                    setState(() => _dateFilter = date),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      if (allDocs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xl,
                          ),
                          child: Text(
                            'Aún no hay documentos. Empieza por un guion '
                            'técnico de rodaje: eliges las escenas del día, '
                            'las ordenas y lo exportas con su índice.',
                            style: AppTypography.bodyMedium(palette),
                            textAlign: TextAlign.center,
                          ),
                        )
                      else if (docs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xl,
                          ),
                          child: Text(
                            'Ningún documento para esta jornada.',
                            style: AppTypography.bodyMedium(palette),
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        for (final group in groups.entries) ...[
                          Padding(
                            padding: const EdgeInsets.only(
                              top: AppSpacing.sm,
                              bottom: AppSpacing.sm,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  group.key == null
                                      ? Icons.inbox_outlined
                                      : Icons.calendar_today_outlined,
                                  size: 14,
                                  color: palette.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  group.key == null
                                      ? 'Sin fecha'
                                      : formatShootDate(group.key),
                                  style: AppTypography.label(palette),
                                ),
                              ],
                            ),
                          ),
                          grid([
                            for (final doc in group.value)
                              _DocumentCard(
                                doc: doc,
                                scenes: scenes,
                                onTap: () => _openEditor(context, doc),
                                onExport: doc.kind == kShootDayKind
                                    ? (word) async {
                                        final settings = ref.read(
                                          technicalScriptSettingsProvider,
                                        );
                                        final saved =
                                            await savedScriptExportOptions(
                                              settings,
                                            );
                                        if (!context.mounted) return;
                                        await exportShootDayDocument(
                                          context,
                                          db,
                                          settings,
                                          doc.id,
                                          saved.copyWith(word: word),
                                        );
                                      }
                                    : null,
                                onSetPrimary: () => db.setPrimaryShootDocument(
                                  widget.projectId,
                                  doc.id,
                                ),
                                onDelete: () async {
                                  final ok = await _confirmDelete(
                                    context,
                                    doc.name,
                                  );
                                  if (ok == true) {
                                    await db.deleteShootDocument(doc.id);
                                  }
                                },
                              ),
                          ]),
                          const SizedBox(height: AppSpacing.md),
                        ],
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  /// «12/10» de una fecha "2026-10-12".
  static String _shortDate(String iso) {
    final date = DateTime.tryParse(iso);
    return date == null ? iso : '${date.day}/${date.month}';
  }

  /// Exporta el guion técnico entero, en orden de guion.
  Future<void> _exportFullScript(BuildContext context) async {
    final settings = ref.read(technicalScriptSettingsProvider);
    final choice = await showScriptExportDialog(context, screen: settings);
    if (choice == null || !context.mounted) return;
    final db = ref.read(databaseProvider);
    try {
      final built = await buildNarrativeScriptDoc(
        db,
        widget.projectId,
        settings,
        hiddenColumns: choice.hiddenColumns,
      );
      final doc = built == null ? null : choice.applyTo(built);
      if (!context.mounted) return;
      if (doc == null || doc.sections.isEmpty) {
        AppSnackBar.show(context, 'El guion técnico aún no tiene escenas.');
        return;
      }
      final fileName = technicalScriptFileName(widget.projectName);
      final path = choice.word
          ? await TechnicalScriptDocxExporter.exportAndSave(
              doc,
              fileName: fileName,
            )
          : await TechnicalScriptPdfExporter.exportAndSave(
              doc,
              fileName: fileName,
            );
      if (!context.mounted || path == null) return;
      AppSnackBar.show(
        context,
        '${choice.word ? 'Word' : 'PDF'} guardado en $path',
      );
    } catch (e) {
      if (context.mounted) AppSnackBar.showError(context, userFriendlyError(e));
    }
  }

  Future<void> _createDocument(BuildContext context) async {
    final db = ref.read(databaseProvider);
    final choice = await resolveShootDocumentCreationTemplate(
      context: context,
      db: db,
      projectId: widget.projectId,
    );
    if (choice == null || !context.mounted) return;

    if (choice.createTemplate) {
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const ShootTemplateEditorScreen()),
      );
      return;
    }

    final defaultName = choice.isUserTemplate
        ? 'Documento — ${widget.projectName}'
        : choice.builtinTemplate == ShootDocumentTemplate.empty
        ? 'Plani — ${widget.projectName}'
        : '${choice.builtinTemplate!.label} — ${widget.projectName}';

    final nameCtrl = TextEditingController(text: defaultName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final palette = context.palette;
        return AlertDialog(
          backgroundColor: palette.surfaceElevated,
          title: Text(
            'Nombre del documento',
            style: AppTypography.titleLarge(palette),
          ),
          content: TextField(controller: nameCtrl, autofocus: true),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: AppTypography.bodyMedium(palette)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
              child: Text(
                'Crear',
                style: AppTypography.bodyMedium(
                  palette,
                ).copyWith(color: palette.accent),
              ),
            ),
          ],
        );
      },
    );
    if (name == null || name.isEmpty || !context.mounted) return;

    final int docId;
    if (choice.isUserTemplate) {
      docId = await UserTemplateService.createShootDocumentFromUserTemplate(
        db: db,
        projectId: widget.projectId,
        name: name,
        templateId: choice.userTemplateId!,
      );
    } else {
      docId = await ShootDocumentService.createDocument(
        db: db,
        projectId: widget.projectId,
        name: name,
        template: choice.builtinTemplate ?? ShootDocumentTemplate.empty,
      );
    }

    if (!context.mounted) return;
    final doc = await db.getShootDocument(docId);
    if (!context.mounted) return;
    if (doc != null) _openEditor(context, doc);
  }

  /// Crea una jornada nueva y la abre: fecha, lugar, meteorología y los
  /// planos del guion técnico en su orden de rodaje.
  Future<void> _createShootDay(BuildContext context) async {
    final db = ref.read(databaseProvider);
    final existing = await db
        .watchShootDocumentsForProject(widget.projectId)
        .first;
    final days = existing.where((d) => d.kind == kShootDayKind).length;
    final id = await db.insertShootDocument(
      ShootDocumentsCompanion.insert(
        projectId: widget.projectId,
        name: 'Jornada ${days + 1}',
        kind: const Value(kShootDayKind),
      ),
    );
    if (!context.mounted) return;
    final doc = await db.getShootDocument(id);
    if (!context.mounted || doc == null) return;
    _openEditor(context, doc);
  }

  void _openEditor(BuildContext context, ShootDocument doc) {
    if (doc.kind == kShootDayKind) {
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ShootDayScreen(
            projectId: widget.projectId,
            documentId: doc.id,
          ),
        ),
      );
      return;
    }
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ShootDocumentEditorScreen(
          projectId: widget.projectId,
          documentId: doc.id,
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, String name) {
    final palette = context.palette;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surfaceElevated,
        title: Text(
          'Eliminar documento',
          style: AppTypography.titleLarge(palette),
        ),
        content: Text(
          '¿Eliminar «$name»?',
          style: AppTypography.bodyLarge(palette),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: AppTypography.bodyMedium(palette)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Eliminar',
              style: AppTypography.bodyMedium(
                palette,
              ).copyWith(color: palette.error),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta para crear un tipo de documento.
class _CreateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool highlighted;
  final VoidCallback onTap;

  const _CreateCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppCard(
      onTap: onTap,
      focused: highlighted,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: SizedBox(
        height: 96,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: palette.accent, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.titleMedium(palette)),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption(palette),
                  ),
                ],
              ),
            ),
            Icon(Icons.add, size: 18, color: palette.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de un documento: qué es, qué escenas lleva y exportación
/// directa si es un guion técnico de rodaje.
class _DocumentCard extends ConsumerWidget {
  final ShootDocument doc;
  final Map<int, Scene> scenes;
  final VoidCallback onTap;

  /// Exporta a PDF (falso) o Word (verdadero); nulo si no se exporta desde
  /// aquí.
  final ValueChanged<bool>? onExport;
  final VoidCallback onSetPrimary;
  final VoidCallback onDelete;

  const _DocumentCard({
    required this.doc,
    required this.scenes,
    required this.onTap,
    required this.onExport,
    required this.onSetPrimary,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);
    final isDay = doc.kind == kShootDayKind;

    return AppCard(
      onTap: onTap,
      focused: doc.isPrimaryOnSet,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: StreamBuilder<List<ShootDocumentBlock>>(
        stream: db.watchBlocksForShootDocument(doc.id),
        builder: (context, snap) {
          final blocks = snap.data ?? const <ShootDocumentBlock>[];
          final shots = blocks.where((b) => b.shotId != null).length;
          // Escenas en el orden del documento, sin repetir.
          final sceneIds = <int>[];
          for (final b in blocks) {
            final id = b.sceneId;
            if (id != null && !sceneIds.contains(id)) sceneIds.add(id);
          }
          final sceneLabels = [
            for (final id in sceneIds)
              if (scenes[id] != null) scenes[id]!.label,
          ];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isDay ? Icons.event_note : Icons.description_outlined,
                    size: 18,
                    color: palette.accent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isDay ? 'Guion técnico de rodaje' : 'Documento libre',
                      style: AppTypography.caption(palette),
                    ),
                  ),
                  if (doc.isPrimaryOnSet)
                    Tooltip(
                      message: 'Activo hoy en set',
                      child: Icon(Icons.star, size: 18, color: palette.accent),
                    ),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      color: palette.surfaceElevated,
                      onSelected: (v) {
                        if (v == 'primary') onSetPrimary();
                        if (v == 'delete') onDelete();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'primary',
                          child: Text('Marcar activo hoy'),
                        ),
                        PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                doc.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleMedium(palette),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  if (sceneIds.isNotEmpty)
                    '${sceneIds.length} '
                        '${sceneIds.length == 1 ? 'escena' : 'escenas'}',
                  if (shots > 0) '$shots ${shots == 1 ? 'plano' : 'planos'}',
                  if (sceneIds.isEmpty && shots == 0) 'Vacío',
                ].join(' · '),
                style: AppTypography.caption(palette),
              ),
              if (sceneLabels.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'ESC ${sceneLabels.join(', ')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption(
                    palette,
                  ).copyWith(color: palette.textPrimary),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  if (onExport != null) ...[
                    OutlinedButton.icon(
                      onPressed: shots == 0 ? null : () => onExport!(false),
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                      label: const Text('PDF'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      onPressed: shots == 0 ? null : () => onExport!(true),
                      icon: const Icon(Icons.description_outlined, size: 16),
                      label: const Text('Word'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                  const Spacer(),
                  TextButton(onPressed: onTap, child: const Text('Abrir')),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
