import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import 'shoot_document_composer.dart';
import 'shoot_document_editor_screen.dart';
import 'shoot_document_service.dart';
import 'shoot_document_template_picker.dart';
import '../../core/templates/user_template_service.dart';
import 'shoot_template_editor_screen.dart';

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
          IconButton(
            tooltip: 'Crear documento',
            icon: Icon(Icons.add, color: palette.accent),
            onPressed: () => _createDocument(context),
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
          final dates = allDocs
              .map((d) => d.shootDate)
              .whereType<String>()
              .toSet()
              .toList()
            ..sort();
          final docs = _dateFilter == null
              ? allDocs
              : allDocs.where((d) => d.shootDate == _dateFilter).toList();

          if (allDocs.isEmpty) {
            return _EmptyState(
              palette: palette,
              isShooting: isShooting,
              onCreate: () => _createDocument(context),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              if (isShooting)
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Icon(Icons.star, color: palette.accent, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Tu documento de referencia en set. Marca uno como '
                          '«activo hoy» para abrirlo rápido.',
                          style: AppTypography.bodyMedium(palette),
                        ),
                      ),
                    ],
                  ),
                ),
              if (isShooting) const SizedBox(height: AppSpacing.md),
              if (dates.isNotEmpty) ...[
                Text('Vista por jornada', style: AppTypography.label(palette)),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    FilterChip(
                      label: const Text('Todos'),
                      selected: _dateFilter == null,
                      onSelected: (_) => setState(() => _dateFilter = null),
                    ),
                    for (final date in dates)
                      FilterChip(
                        label: Text(date),
                        selected: _dateFilter == date,
                        onSelected: (_) => setState(() => _dateFilter = date),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (docs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Text(
                    'Ningún documento para esta jornada.',
                    style: AppTypography.bodyMedium(palette),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ...docs.map(
                  (doc) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _DocumentTile(
                      doc: doc,
                      palette: palette,
                      onTap: () => _openEditor(context, doc),
                      onSetPrimary: () async {
                        await db.setPrimaryShootDocument(
                          widget.projectId,
                          doc.id,
                        );
                      },
                      onDelete: () async {
                        final ok = await _confirmDelete(context, doc.name);
                        if (ok == true) {
                          await db.deleteShootDocument(doc.id);
                        }
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
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
        MaterialPageRoute(
          builder: (_) => const ShootTemplateEditorScreen(),
        ),
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
          title: Text('Nombre del documento', style: AppTypography.titleLarge(palette)),
          content: TextField(
            controller: nameCtrl,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: AppTypography.bodyMedium(palette)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
              child: Text('Crear', style: AppTypography.bodyMedium(palette)
                  .copyWith(color: palette.accent)),
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
    if (doc != null) _openEditor(context, doc);
  }

  void _openEditor(BuildContext context, ShootDocument doc) {
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
        title: Text('Eliminar documento', style: AppTypography.titleLarge(palette)),
        content: Text('¿Eliminar «$name»?', style: AppTypography.bodyLarge(palette)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: AppTypography.bodyMedium(palette)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Eliminar', style: AppTypography.bodyMedium(palette)
                .copyWith(color: palette.error)),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppPalette palette;
  final bool isShooting;
  final VoidCallback onCreate;

  const _EmptyState({
    required this.palette,
    required this.isShooting,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, size: 56, color: palette.textTertiary),
          const SizedBox(height: AppSpacing.lg),
          Text(
            isShooting
                ? 'Crea tu documento de rodaje'
                : 'Documentos para el rodaje',
            style: AppTypography.titleLarge(palette),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Compón libremente guion, planos, personajes, duración y refs '
            'visuales (Artemis, ShotDeck). Este será tu documento de '
            'referencia en set.',
            style: AppTypography.bodyMedium(palette),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(label: 'Crear documento', icon: Icons.add, onTap: onCreate),
        ],
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  final ShootDocument doc;
  final AppPalette palette;
  final VoidCallback onTap;
  final VoidCallback onSetPrimary;
  final VoidCallback onDelete;

  const _DocumentTile({
    required this.doc,
    required this.palette,
    required this.onTap,
    required this.onSetPrimary,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      focused: doc.isPrimaryOnSet,
      child: Row(
        children: [
          Icon(
            doc.isPrimaryOnSet ? Icons.star : Icons.description_outlined,
            color: doc.isPrimaryOnSet ? palette.accent : palette.textSecondary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc.name, style: AppTypography.titleMedium(palette)),
                if (doc.shootDate != null)
                  Text(
                    'Jornada: ${doc.shootDate}',
                    style: AppTypography.caption(palette),
                  ),
                if (doc.isPrimaryOnSet)
                  Text(
                    'Activo hoy en set',
                    style: AppTypography.caption(palette)
                        .copyWith(color: palette.accent),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'primary') onSetPrimary();
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'primary',
                child: Text('Marcar activo hoy'),
              ),
              const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreateDocumentSheet extends StatelessWidget {
  final String projectName;

  const _CreateDocumentSheet({required this.projectName});

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
              'Plantilla de arranque (opcional)',
              style: AppTypography.titleMedium(palette),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Tras crear el documento puedes reordenar, borrar y mezclar '
              'bloques libremente.',
              style: AppTypography.bodyMedium(palette),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final t in ShootDocumentTemplate.values)
              ListTile(
                title: Text(t.label, style: AppTypography.bodyMedium(palette)),
                subtitle: Text(t.description,
                    style: AppTypography.caption(palette)),
                onTap: () => Navigator.pop(context, t),
              ),
          ],
        ),
      ),
    );
  }
}
