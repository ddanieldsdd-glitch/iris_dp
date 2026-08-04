import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../bible_section_fields.dart';
import '../../visual_bible_model.dart';
import '../bible_form_widgets.dart';
import 'section_scaffold.dart';

class ConceptSection extends StatelessWidget {
  final VisualBibleData data;
  final int projectId;
  final String? sectionContentJson;
  final BibleChanged onChanged;

  const ConceptSection({
    super.key,
    required this.data,
    required this.projectId,
    this.sectionContentJson,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final conceptLabel = BibleSectionFieldsConfig.labelFor(
      sectionContentJson,
      BibleSectionId.concept,
      'visualConcept',
      'Concepto de imagen',
    );
    final filmRefLabel = BibleSectionFieldsConfig.labelFor(
      sectionContentJson,
      BibleSectionId.concept,
      'filmReferences',
      'Referencias cinematográficas',
    );
    final actNotesLabel = BibleSectionFieldsConfig.labelFor(
      sectionContentJson,
      BibleSectionId.concept,
      'actNotes',
      'Intención visual por acto',
    );

    return BibleSectionScaffold(
      sectionId: BibleSectionId.concept,
      projectId: projectId,
      data: data,
      onChanged: onChanged,
      sectionContentJson: sectionContentJson,
      narrativeHint:
          '¿Qué debe sentir el ojo del espectador en cada acto? '
          'Cómo la fotografía apoya la narrativa…',
      fieldWidgets: {
        'visualConcept': AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: BibleTextField(
            label: conceptLabel,
            hint: 'Qué tipo de mundo es este, cómo se siente visualmente, '
                'y por qué las decisiones de fotografía sirven a la historia…',
            maxLines: 6,
            initialValue: data.visualConcept,
            onChanged: (v) {
              data.visualConcept = v.trim().isEmpty ? null : v.trim();
              onChanged(data);
            },
          ),
        ),
        'filmReferences': _ReferenceList(
          data: data,
          onChanged: onChanged,
          title: filmRefLabel,
        ),
        'actNotes': _ActNotes(
          data: data,
          onChanged: onChanged,
          title: actNotesLabel,
        ),
      },
    );
  }
}

class _ReferenceList extends StatelessWidget {
  final VisualBibleData data;
  final BibleChanged onChanged;
  final String title;

  const _ReferenceList({
    required this.data,
    required this.onChanged,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  data.narrativeReferences.add({
                    'title': '',
                    'director': '',
                    'dp': '',
                    'year': '',
                    'note': '',
                  });
                  onChanged(data);
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Añadir'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...data.narrativeReferences.asMap().entries.map((entry) {
            final i = entry.key;
            final ref = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: BibleTextField(
                          label: 'Película / obra',
                          hint: 'Blade Runner 2049',
                          initialValue: ref['title'],
                          onChanged: (v) {
                            ref['title'] = v;
                            onChanged(data);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: BibleTextField(
                          label: 'Año',
                          hint: '2017',
                          initialValue: ref['year'],
                          onChanged: (v) {
                            ref['year'] = v;
                            onChanged(data);
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          data.narrativeReferences.removeAt(i);
                          onChanged(data);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: BibleTextField(
                          label: 'Director',
                          hint: 'Denis Villeneuve',
                          initialValue: ref['director'],
                          onChanged: (v) {
                            ref['director'] = v;
                            onChanged(data);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: BibleTextField(
                          label: 'Director de fotografía *',
                          hint: 'Roger Deakins',
                          initialValue: ref['dp'],
                          onChanged: (v) {
                            ref['dp'] = v;
                            onChanged(data);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  BibleTextField(
                    label: 'Qué tomamos de esta referencia',
                    hint: 'Luz lateral suave, paleta desaturada…',
                    maxLines: 2,
                    initialValue: ref['note'],
                    onChanged: (v) {
                      ref['note'] = v;
                      onChanged(data);
                    },
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ActNotes extends StatelessWidget {
  final VisualBibleData data;
  final BibleChanged onChanged;
  final String title;

  const _ActNotes({
    required this.data,
    required this.onChanged,
    required this.title,
  });

  static const _acts = ['Acto I', 'Acto II', 'Acto III'];

  @override
  Widget build(BuildContext context) {
    for (final act in _acts) {
      if (!data.actVisualNotes.any((a) => a['act'] == act)) {
        data.actVisualNotes.add({'act': act, 'intent': ''});
      }
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.md),
          ...data.actVisualNotes.map((act) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: BibleTextField(
                label: act['act'] ?? '',
                hint: '¿Qué debe sentir el espectador en este acto?',
                maxLines: 2,
                initialValue: act['intent'],
                onChanged: (v) {
                  act['intent'] = v;
                  onChanged(data);
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}
