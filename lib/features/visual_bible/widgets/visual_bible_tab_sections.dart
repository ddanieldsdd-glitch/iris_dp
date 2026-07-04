import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../visual_bible_model.dart';
import 'bible_form_widgets.dart';

typedef BibleChanged = void Function(VisualBibleData data);

class ConceptSection extends StatelessWidget {
  final VisualBibleData data;
  final BibleChanged onChanged;

  const ConceptSection({super.key, required this.data, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: BibleTextField(
            label: 'Concepto visual global',
            hint: 'Qué tipo de mundo es este, cómo se siente, y por qué las '
                'decisiones visuales sirven a la historia…',
            maxLines: 6,
            initialValue: data.visualConcept,
            onChanged: (v) {
              data.visualConcept = v.trim().isEmpty ? null : v.trim();
              onChanged(data);
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: BibleTextField(
            label: 'Referencias narrativas y emocionales',
            hint: 'Películas, directores, fotógrafos, pintores… (una por línea)',
            maxLines: 5,
            initialValue: data.narrativeReferences.map((r) => r['title'] ?? '').join('\n'),
            onChanged: (v) {
              data.narrativeReferences = v
                  .split('\n')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .map((s) => {'title': s})
                  .toList();
              onChanged(data);
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'El lookbook comunica; la biblia visual opera. '
          'Este concepto ancla todas las decisiones técnicas.',
          style: AppTypography.caption(palette).copyWith(color: palette.textTertiary),
        ),
      ],
    );
  }
}

class ColorSection extends ConsumerWidget {
  final int bibleId;
  final VoidCallback onChanged;

  const ColorSection({super.key, required this.bibleId, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return StreamBuilder<List<VisualBibleColorBlock>>(
      stream: db.watchColorBlocksForBible(bibleId),
      builder: (context, snap) {
        final blocks = snap.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Row(
              children: [
                Text('Paletas por bloque narrativo', style: AppTypography.titleMedium(palette)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _addBlock(context, ref),
                  icon: Icon(Icons.add, color: palette.accent, size: 18),
                  label: Text('Añadir bloque', style: AppTypography.label(palette).copyWith(color: palette.accent)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (blocks.isEmpty)
              Text(
                'Crea bloques como «Acto I», «Flashbacks» o «Clímax» con 2–4 colores dominantes.',
                style: AppTypography.bodyMedium(palette).copyWith(color: palette.textTertiary),
              ),
            ...blocks.map((row) {
              final block = ColorBlockModel.fromRow(row);
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(block.blockName, style: AppTypography.titleMedium(palette)),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: palette.error, size: 20),
                            onPressed: () => db.deleteColorBlock(block.id),
                          ),
                        ],
                      ),
                      if (block.emotionalIntent?.isNotEmpty == true)
                        Text(block.emotionalIntent!, style: AppTypography.bodyMedium(palette)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: block.swatches
                            .map(
                              (c) => Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: c,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: palette.divider),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      if (block.colorTempKelvin != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${block.colorTempKelvin}K',
                            style: AppTypography.caption(palette),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Future<void> _addBlock(BuildContext context, WidgetRef ref) async {
    final palette = context.palette;
    final nameCtrl = TextEditingController();
    final intentCtrl = TextEditingController();
    final tempCtrl = TextEditingController();
    final colors = <Color>[const Color(0xFF1A1A2E)];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surfaceElevated,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                top: AppSpacing.lg,
                bottom: MediaQuery.paddingOf(ctx).bottom + AppSpacing.lg,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Nuevo bloque de color', style: AppTypography.titleMedium(palette)),
                    const SizedBox(height: AppSpacing.md),
                    BibleTextField(label: 'Nombre', hint: 'Acto I', onChanged: (_) {}, controller: nameCtrl),
                    const SizedBox(height: AppSpacing.sm),
                    BibleTextField(
                      label: 'Intención emocional',
                      hint: 'Tensión contenida, frío distante…',
                      maxLines: 2,
                      onChanged: (_) {},
                      controller: intentCtrl,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    BibleTextField(
                      label: 'Temperatura (K)',
                      hint: '3200',
                      onChanged: (_) {},
                      controller: tempCtrl,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 8,
                      children: [
                        ...colors.map(
                          (c) => GestureDetector(
                            onTap: () async {
                              await showDialog<void>(
                                context: ctx,
                                builder: (_) => AlertDialog(
                                  title: const Text('Color dominante'),
                                  content: BlockPicker(
                                    pickerColor: c,
                                    onColorChanged: (nc) {
                                      final i = colors.indexOf(c);
                                      if (i >= 0) colors[i] = nc;
                                    },
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
                                  ],
                                ),
                              );
                              setSt(() {});
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: c,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setSt(() => colors.add(const Color(0xFF808080)));
                          },
                          icon: Icon(Icons.add, color: palette.accent),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) return;
                        final hexes = colors
                            .map((c) => '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}')
                            .toList();
                        await ref.read(databaseProvider).insertColorBlock(
                              VisualBibleColorBlocksCompanion.insert(
                                bibleId: bibleId,
                                blockName: name,
                                emotionalIntent: Value(intentCtrl.text.trim().isEmpty ? null : intentCtrl.text.trim()),
                                dominantColors: jsonEncode(hexes),
                                colorTempKelvin: Value(int.tryParse(tempCtrl.text.trim())),
                              ),
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                        onChanged();
                      },
                      child: const Text('Crear bloque'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class LightingSection extends StatelessWidget {
  final VisualBibleData data;
  final BibleChanged onChanged;

  const LightingSection({super.key, required this.data, required this.onChanged});

  static const _lightQualities = ['Dura', 'Semidura', 'Suave', 'Muy suave', 'Naturalista'];
  static const _contrastStyles = [
    'Alto contraste (5:1+)',
    'Medio-alto (3:1)',
    'Medio (2:1)',
    'Bajo (1.5:1)',
    'Flat (1:1)',
  ];
  static const _lightSources = [
    'Natural dominante',
    'Prácticas dominantes',
    'Artificial controlada',
    'Mixta',
  ];
  static const _highlights = ['Protegidas', 'Roll-off suave', 'Quemadas intencionadas'];
  static const _shadows = ['Abiertas (detalle en negros)', 'Aplastadas (blacks cerrados)', 'Mixtas'];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        BibleTextField(
          label: 'Filosofía de luz',
          hint: 'Calidad, dirección y origen de la luz en este proyecto…',
          maxLines: 5,
          initialValue: data.lightingPhilosophy,
          onChanged: (v) {
            data.lightingPhilosophy = v.trim().isEmpty ? null : v.trim();
            onChanged(data);
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: BibleDropdown(
                label: 'Calidad de luz',
                options: _lightQualities,
                value: data.lightQuality,
                onChanged: (v) {
                  data.lightQuality = v;
                  onChanged(data);
                },
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: BibleDropdown(
                label: 'Estilo de contraste',
                options: _contrastStyles,
                value: data.contrastStyle,
                onChanged: (v) {
                  data.contrastStyle = v;
                  onChanged(data);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: BibleDropdown(
                label: 'Origen de la luz',
                options: _lightSources,
                value: data.lightSource,
                onChanged: (v) {
                  data.lightSource = v;
                  onChanged(data);
                },
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: BibleTextField(
                label: 'Ratio K:F (día)',
                hint: '3:1',
                initialValue: data.keyFillRatioDay,
                onChanged: (v) {
                  data.keyFillRatioDay = v.trim().isEmpty ? null : v.trim();
                  onChanged(data);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: BibleTextField(
                label: 'Ratio K:F (noche)',
                hint: '5:1',
                initialValue: data.keyFillRatioNight,
                onChanged: (v) {
                  data.keyFillRatioNight = v.trim().isEmpty ? null : v.trim();
                  onChanged(data);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: BibleDropdown(
                label: 'Altas luces',
                options: _highlights,
                value: data.highlightBehavior,
                onChanged: (v) {
                  data.highlightBehavior = v;
                  onChanged(data);
                },
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: BibleDropdown(
                label: 'Sombras',
                options: _shadows,
                value: data.shadowBehavior,
                onChanged: (v) {
                  data.shadowBehavior = v;
                  onChanged(data);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Las imágenes con categoría «Luz» del moodboard ilustran esta sección.',
          style: AppTypography.caption(palette).copyWith(color: palette.textTertiary),
        ),
      ],
    );
  }
}

class CameraSection extends StatelessWidget {
  final VisualBibleData data;
  final BibleChanged onChanged;

  const CameraSection({super.key, required this.data, required this.onChanged});

  static const _movements = ['Estático', 'Observacional', 'Participativo', 'Mixto'];
  static const _preferred = ['Dolly', 'Steadicam', 'Mano', 'Grúa', 'Zoom', 'Estático'];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        BibleTextField(
          label: 'Filosofía de cámara',
          hint: '¿La cámara observa o participa? ¿Planos largos o montaje?',
          maxLines: 5,
          initialValue: data.cameraPhilosophy,
          onChanged: (v) {
            data.cameraPhilosophy = v.trim().isEmpty ? null : v.trim();
            onChanged(data);
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        BibleDropdown(
          label: 'Estilo de movimiento',
          options: _movements,
          value: data.movementStyle,
          onChanged: (v) {
            data.movementStyle = v;
            onChanged(data);
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        BibleMultiChipRow(
          label: 'Movimientos preferentes',
          options: _preferred,
          selected: data.preferredMovements,
          onChanged: (v) {
            data.preferredMovements = v;
            onChanged(data);
          },
        ),
      ],
    );
  }
}

class OpticsSection extends ConsumerWidget {
  final VisualBibleData data;
  final BibleChanged onChanged;

  const OpticsSection({super.key, required this.data, required this.onChanged});

  static const _opticTypes = ['Esférica', 'Anamórfica', 'Vintage', 'Moderna'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        BibleTextField(
          label: 'Filosofía de óptica',
          hint: 'Cómo el carácter de la lente sirve a la historia…',
          maxLines: 4,
          initialValue: data.lensPhilosophy,
          onChanged: (v) {
            data.lensPhilosophy = v.trim().isEmpty ? null : v.trim();
            onChanged(data);
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        BibleDropdown(
          label: 'Tipo de óptica',
          options: _opticTypes,
          value: data.opticType,
          onChanged: (v) {
            data.opticType = v;
            onChanged(data);
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        BibleTextField(
          label: 'Focales preferentes (mm, separadas por coma)',
          hint: '35, 50, 85',
          initialValue: data.primaryFocalLengths.join(', '),
          onChanged: (v) {
            data.primaryFocalLengths = v
                .split(',')
                .map((s) => int.tryParse(s.trim()) ?? 0)
                .where((n) => n > 0)
                .toList();
            onChanged(data);
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        StreamBuilder<List<Lense>>(
          stream: db.watchAllLenses(),
          builder: (context, snap) {
            final lenses = snap.data ?? [];
            if (lenses.isEmpty) return const SizedBox.shrink();
            String lensLabel(Lense l) => '${l.brand} ${l.model}';
            return BibleDropdown(
              label: 'Óptica principal del proyecto',
              options: lenses.map(lensLabel).toList(),
              value: data.primaryLensId != null
                  ? lenses
                      .where((l) => l.id == data.primaryLensId)
                      .map(lensLabel)
                      .firstOrNull
                  : null,
              onChanged: (v) {
                final lens = lenses.where((l) => lensLabel(l) == v).firstOrNull;
                data.primaryLensId = lens?.id;
                onChanged(data);
              },
            );
          },
        ),
      ],
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}

class FormatSection extends StatelessWidget {
  final VisualBibleData data;
  final BibleChanged onChanged;

  const FormatSection({super.key, required this.data, required this.onChanged});

  static const _ratios = ['2.39:1', '1.85:1', '1.78:1', '1.66:1', '4:3'];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        BibleDropdown(
          label: 'Aspect ratio',
          options: _ratios,
          value: data.aspectRatio,
          onChanged: (v) {
            data.aspectRatio = v;
            onChanged(data);
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        BibleTextField(
          label: 'Justificación narrativa',
          hint: 'Por qué este ratio sirve a esta historia…',
          maxLines: 4,
          initialValue: data.aspectRatioJustification,
          onChanged: (v) {
            data.aspectRatioJustification = v.trim().isEmpty ? null : v.trim();
            onChanged(data);
          },
        ),
      ],
    );
  }
}

class TextureSection extends StatelessWidget {
  final VisualBibleData data;
  final BibleChanged onChanged;

  const TextureSection({super.key, required this.data, required this.onChanged});

  static const _textures = ['Grano orgánico', 'Limpieza digital', 'Degradado', 'Mixto'];
  static const _grains = ['Ninguno', 'Sutil', 'Medio', 'Pronunciado'];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        BibleDropdown(
          label: 'Textura de imagen',
          options: _textures,
          value: data.imageTexture,
          onChanged: (v) {
            data.imageTexture = v;
            onChanged(data);
          },
        ),
        const SizedBox(height: AppSpacing.md),
        BibleDropdown(
          label: 'Grano',
          options: _grains,
          value: data.grainLevel,
          onChanged: (v) {
            data.grainLevel = v;
            onChanged(data);
          },
        ),
      ],
    );
  }
}

class LutSection extends StatelessWidget {
  final VisualBibleData data;
  final BibleChanged onChanged;

  const LutSection({super.key, required this.data, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        BibleTextField(
          label: 'LUT de trabajo (rodaje / log)',
          hint: 'Nombre del LUT técnico',
          initialValue: data.workingLutName,
          onChanged: (v) {
            data.workingLutName = v.trim().isEmpty ? null : v.trim();
            onChanged(data);
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        BibleTextField(
          label: 'LUT creativo',
          hint: 'Nombre del LUT de intención final',
          initialValue: data.creativeLutName,
          onChanged: (v) {
            data.creativeLutName = v.trim().isEmpty ? null : v.trim();
            onChanged(data);
          },
        ),
        const SizedBox(height: AppSpacing.md),
        BibleTextField(
          label: 'Descripción del LUT creativo',
          hint: 'Qué hace al look — no solo el nombre del archivo',
          maxLines: 4,
          initialValue: data.creativeLutDescription,
          onChanged: (v) {
            data.creativeLutDescription = v.trim().isEmpty ? null : v.trim();
            onChanged(data);
          },
        ),
      ],
    );
  }
}

class ByLocationSection extends ConsumerWidget {
  final int projectId;
  final int bibleId;

  const ByLocationSection({
    super.key,
    required this.projectId,
    required this.bibleId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return StreamBuilder<List<LocationBasePlan>>(
      stream: db.watchLocationsForProject(projectId),
      builder: (context, locSnap) {
        final locations = locSnap.data ?? [];
        if (locations.isEmpty) {
          return Center(
            child: Text(
              'Las localizaciones se generan al importar el guion.',
              style: AppTypography.bodyMedium(palette).copyWith(color: palette.textTertiary),
            ),
          );
        }

        return StreamBuilder<List<VisualBibleLocationRef>>(
          stream: db.watchLocationRefsForBible(bibleId),
          builder: (context, refSnap) {
            final refs = {
              for (final r in refSnap.data ?? []) r.locationName: r,
            };

            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: locations.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.lg),
              itemBuilder: (context, i) {
                final loc = locations[i];
                final color = Color(int.parse(loc.color.replaceFirst('#', '0xFF')));
                final ref = refs[loc.locationName];
                var lighting = ref?.lightingNote ?? '';
                var colorNote = ref?.colorNote ?? '';

                return AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 12),
                          Text(loc.locationName, style: AppTypography.titleMedium(palette)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      BibleTextField(
                        label: 'Nota de iluminación',
                        hint: 'Luz natural filtrada, temp ~2700K…',
                        maxLines: 3,
                        initialValue: lighting,
                        onChanged: (v) => lighting = v,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      BibleTextField(
                        label: 'Paleta de esta localización',
                        hint: 'Ocres y terracotas, sin azules…',
                        maxLines: 2,
                        initialValue: colorNote,
                        onChanged: (v) => colorNote = v,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () async {
                            await db.upsertLocationRef(
                              VisualBibleLocationRefsCompanion(
                                id: ref != null ? Value(ref.id) : const Value.absent(),
                                bibleId: Value(bibleId),
                                locationName: Value(loc.locationName),
                                lightingNote: Value(lighting.trim().isEmpty ? null : lighting.trim()),
                                colorNote: Value(colorNote.trim().isEmpty ? null : colorNote.trim()),
                              ),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Localización guardada')),
                              );
                            }
                          },
                          child: const Text('Guardar'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
