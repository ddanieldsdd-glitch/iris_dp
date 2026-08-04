import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../visual_bible_model.dart';
import '../bible_form_widgets.dart';

class WorkflowSection extends ConsumerStatefulWidget {
  final VisualBibleData data;
  final int bibleId;
  final BibleChanged onChanged;

  const WorkflowSection({
    super.key,
    required this.data,
    required this.bibleId,
    required this.onChanged,
  });

  @override
  ConsumerState<WorkflowSection> createState() => _WorkflowSectionState();
}

class _WorkflowSectionState extends ConsumerState<WorkflowSection> {
  late List<WorkflowStepModel> _steps;

  @override
  void initState() {
    super.initState();
    _steps = WorkflowStepModel.decode(widget.data.workflowPipeline);
  }

  void _persist() {
    widget.data.workflowPipeline = WorkflowStepModel.encode(_steps);
    widget.onChanged(widget.data);
  }

  Future<void> _saveVersion() async {
    final db = ref.read(databaseProvider);
    await db.insertBibleVersion(
      VisualBibleVersionsCompanion.insert(
        bibleId: widget.bibleId,
        label: 'Versión ${DateTime.now().toIso8601String().substring(0, 16)}',
        snapshotJson: jsonEncode(widget.data.toSnapshotJson()),
        changeNote: const Value('Snapshot manual del look'),
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Versión del look guardada')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          'Pipeline técnico de imagen',
          style: AppTypography.titleMedium(palette),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Cámara → tarjetas → dailies → color → entrega. '
          'Quién es responsable de cada paso.',
          style: AppTypography.caption(palette)
              .copyWith(color: palette.textTertiary),
        ),
        const SizedBox(height: AppSpacing.lg),
        ..._steps.asMap().entries.map((entry) {
          final i = entry.key;
          final step = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Icon(
                      _iconForStep(step.step),
                      color: palette.accent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      children: [
                        BibleTextField(
                          label: 'Paso',
                          initialValue: step.step,
                          hint: '',
                          onChanged: (v) {
                            step.step = v;
                            _persist();
                          },
                        ),
                        BibleTextField(
                          label: 'Responsable',
                          hint: 'DIT, AC, colorista…',
                          initialValue: step.responsible,
                          onChanged: (v) {
                            step.responsible = v.trim().isEmpty ? null : v.trim();
                            _persist();
                          },
                        ),
                        BibleTextField(
                          label: 'Notas / LUT de referencia',
                          hint: 'Metadata que viaja con el material',
                          maxLines: 2,
                          initialValue: step.notes,
                          onChanged: (v) {
                            step.notes = v.trim().isEmpty ? null : v.trim();
                            _persist();
                          },
                        ),
                      ],
                    ),
                  ),
                  if (i < _steps.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 20, left: 4),
                      child: Icon(Icons.arrow_downward,
                          color: palette.textTertiary, size: 16),
                    ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _saveVersion,
              icon: const Icon(Icons.history, size: 18),
              label: const Text('Guardar versión del look'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Historial de versiones',
            style: AppTypography.titleMedium(palette)),
        const SizedBox(height: AppSpacing.sm),
        StreamBuilder<List<VisualBibleVersion>>(
          stream: db.watchBibleVersions(widget.bibleId),
          builder: (context, snap) {
            final versions = snap.data ?? [];
            if (versions.isEmpty) {
              return Text(
                'Sin versiones guardadas.',
                style: AppTypography.caption(palette),
              );
            }
            return Column(
              children: versions
                  .map(
                    (v) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.history, size: 18),
                      title: Text(v.label),
                      subtitle: v.changeNote != null ? Text(v.changeNote!) : null,
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: AppSpacing.xl),
        _CommentsPanel(bibleId: widget.bibleId),
      ],
    );
  }

  IconData _iconForStep(String step) {
    final lower = step.toLowerCase();
    if (lower.contains('cámara') || lower.contains('sensor')) {
      return Icons.videocam_outlined;
    }
    if (lower.contains('tarjeta') || lower.contains('backup')) {
      return Icons.sd_storage_outlined;
    }
    if (lower.contains('dailies')) return Icons.play_circle_outline;
    if (lower.contains('color') || lower.contains('grading')) {
      return Icons.palette_outlined;
    }
    return Icons.check_circle_outline;
  }
}

class _CommentsPanel extends ConsumerStatefulWidget {
  final int bibleId;

  const _CommentsPanel({required this.bibleId});

  @override
  ConsumerState<_CommentsPanel> createState() => _CommentsPanelState();
}

class _CommentsPanelState extends ConsumerState<_CommentsPanel> {
  final _commentCtrl = TextEditingController();
  String _role = 'dp';

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Comentarios colaborativos',
            style: AppTypography.titleMedium(palette)),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: BibleTextField(
                label: 'Comentario',
                hint: 'Nota para gaffer, colorista…',
                maxLines: 2,
                onChanged: (_) {},
                controller: _commentCtrl,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: BibleDropdown(
                label: 'Rol',
                options: const ['dp', 'gaffer', 'colorist', 'ac'],
                value: _role,
                onChanged: (v) => setState(() => _role = v ?? 'dp'),
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () async {
              final text = _commentCtrl.text.trim();
              if (text.isEmpty) return;
              await db.insertBibleComment(
                BibleCommentsCompanion.insert(
                  bibleId: widget.bibleId,
                  authorRole: _role,
                  targetType: 'section',
                  comment: text,
                ),
              );
              _commentCtrl.clear();
            },
            child: const Text('Añadir comentario'),
          ),
        ),
        StreamBuilder<List<BibleComment>>(
          stream: db.watchBibleComments(widget.bibleId),
          builder: (context, snap) {
            final comments = snap.data ?? [];
            return Column(
              children: comments
                  .map(
                    (c) => ListTile(
                      dense: true,
                      title: Text(c.comment),
                      subtitle: Text('${c.authorRole} · ${c.targetType}'),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

typedef BibleChanged = void Function(VisualBibleData data);
