import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/media_storage.dart';
import '../../../../core/widgets/app_card.dart';
import '../../visual_bible_model.dart';
import '../bible_form_widgets.dart';
import '../bible_section_shared_widgets.dart';
import '../camera_test_comparator.dart';

class CameraTestsSection extends ConsumerStatefulWidget {
  final int bibleId;
  final int projectId;

  const CameraTestsSection({
    super.key,
    required this.bibleId,
    required this.projectId,
  });

  @override
  ConsumerState<CameraTestsSection> createState() =>
      _CameraTestsSectionState();
}

class _CameraTestsSectionState extends ConsumerState<CameraTestsSection> {
  int? _compareA;
  int? _compareB;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const BibleSectionHeader(
          number: '13',
          title: 'Pruebas de Cámara',
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Text('Pruebas de cámara',
                style: AppTypography.titleMedium(palette)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _addTest(context),
              icon: Icon(Icons.add, color: palette.accent, size: 18),
              label: Text('Nueva prueba',
                  style: AppTypography.label(palette)
                      .copyWith(color: palette.accent)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Decisiones validadas con pruebas reales — cámara, lente, LUT y luz.',
          style: AppTypography.caption(palette)
              .copyWith(color: palette.textTertiary),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_compareA != null && _compareB != null)
          CameraTestComparator(
            bibleId: widget.bibleId,
            testIdA: _compareA!,
            testIdB: _compareB!,
            onClose: () => setState(() {
              _compareA = null;
              _compareB = null;
            }),
          ),
        StreamBuilder<List<CameraTest>>(
          stream: db.watchCameraTestsForBible(widget.bibleId),
          builder: (context, snap) {
            final tests = snap.data ?? [];
            if (tests.isEmpty) {
              return Text(
                'Añade pruebas de cámara para comparar LUTs, lentes y condiciones de luz.',
                style: AppTypography.bodyMedium(palette)
                    .copyWith(color: palette.textTertiary),
              );
            }

            return Column(
              children: tests.map((row) {
                final test = CameraTestModel.fromRow(row);
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
                              child: Text(test.testName,
                                  style: AppTypography.titleMedium(palette)),
                            ),
                            IconButton(
                              tooltip: 'Comparar A',
                              icon: Icon(Icons.looks_one_outlined,
                                  color: _compareA == test.id
                                      ? palette.accent
                                      : palette.textSecondary),
                              onPressed: () =>
                                  setState(() => _compareA = test.id),
                            ),
                            IconButton(
                              tooltip: 'Comparar B',
                              icon: Icon(Icons.looks_two_outlined,
                                  color: _compareB == test.id
                                      ? palette.accent
                                      : palette.textSecondary),
                              onPressed: () =>
                                  setState(() => _compareB = test.id),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline,
                                  color: palette.error, size: 20),
                              onPressed: () => db.deleteCameraTest(test.id),
                            ),
                          ],
                        ),
                        if (test.lutName != null) Text('LUT: ${test.lutName}'),
                        if (test.lightCondition != null)
                          Text('Luz: ${test.lightCondition}'),
                        if (test.notes != null) Text(test.notes!),
                        if (test.imagePaths.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: SizedBox(
                              height: 100,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: test.imagePaths.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (_, i) {
                                  final file = File(test.imagePaths[i]);
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: file.existsSync()
                                        ? Image.file(file,
                                            width: 140,
                                            height: 100,
                                            fit: BoxFit.cover)
                                        : const SizedBox(width: 140, height: 100),
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Future<void> _addTest(BuildContext context) async {
    final palette = context.palette;
    final nameCtrl = TextEditingController();
    final lutCtrl = TextEditingController();
    final lightCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final images = <String>[];

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
                    Text('Nueva prueba de cámara',
                        style: AppTypography.titleMedium(palette)),
                    const SizedBox(height: AppSpacing.md),
                    BibleTextField(
                      label: 'Nombre',
                      hint: 'LUT A vs LUT B — interior',
                      onChanged: (_) {},
                      controller: nameCtrl,
                    ),
                    BibleTextField(
                      label: 'LUT probado',
                      hint: 'S-Log3 → Rec.709',
                      onChanged: (_) {},
                      controller: lutCtrl,
                    ),
                    BibleTextField(
                      label: 'Condición de luz',
                      hint: 'Interior ventana norte',
                      onChanged: (_) {},
                      controller: lightCtrl,
                    ),
                    BibleTextField(
                      label: 'Notas',
                      hint: 'Observaciones de la prueba',
                      maxLines: 2,
                      onChanged: (_) {},
                      controller: notesCtrl,
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.image,
                          allowMultiple: true,
                        );
                        if (result == null) return;
                        for (final f in result.files) {
                          final path = f.path;
                          if (path == null) continue;
                          final stored = await MediaStorage.copyFileIntoProject(
                            projectId: widget.projectId,
                            sourcePath: path,
                            subfolder: 'visual_bible/camera_tests',
                            fileName:
                                'test_${DateTime.now().millisecondsSinceEpoch}${p.extension(path).isEmpty ? '.jpg' : p.extension(path)}',
                          );
                          if (stored == null) continue;
                          images.add(stored);
                        }
                        setSt(() {});
                      },
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Añadir imágenes'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) return;
                        await ref.read(databaseProvider).insertCameraTest(
                              CameraTestsCompanion.insert(
                                bibleId: widget.bibleId,
                                testName: name,
                                lutName: Value(
                                  lutCtrl.text.trim().isEmpty
                                      ? null
                                      : lutCtrl.text.trim(),
                                ),
                                lightCondition: Value(
                                  lightCtrl.text.trim().isEmpty
                                      ? null
                                      : lightCtrl.text.trim(),
                                ),
                                notes: Value(
                                  notesCtrl.text.trim().isEmpty
                                      ? null
                                      : notesCtrl.text.trim(),
                                ),
                                imagePaths: jsonEncode(images),
                              ),
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Guardar prueba'),
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
