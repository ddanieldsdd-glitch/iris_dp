import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../visual_bible_model.dart';

/// Comparador lado a lado de dos pruebas de cámara.
class CameraTestComparator extends ConsumerWidget {
  final int bibleId;
  final int testIdA;
  final int testIdB;
  final VoidCallback onClose;

  const CameraTestComparator({
    super.key,
    required this.bibleId,
    required this.testIdA,
    required this.testIdB,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return StreamBuilder<List<CameraTest>>(
      stream: db.watchCameraTestsForBible(bibleId),
      builder: (context, snap) {
        final tests = snap.data ?? [];
        final a = tests.where((t) => t.id == testIdA).firstOrNull;
        final b = tests.where((t) => t.id == testIdB).firstOrNull;
        if (a == null || b == null) return const SizedBox.shrink();

        final modelA = CameraTestModel.fromRow(a);
        final modelB = CameraTestModel.fromRow(b);

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Comparador',
                        style: AppTypography.titleMedium(palette)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: onClose,
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _TestPanel(model: modelA, label: 'A')),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: _TestPanel(model: modelB, label: 'B')),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TestPanel extends StatelessWidget {
  final CameraTestModel model;
  final String label;

  const _TestPanel({required this.model, required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final path = model.imagePaths.isNotEmpty ? model.imagePaths.first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label — ${model.testName}',
            style: AppTypography.label(palette)),
        if (model.lutName != null) Text('LUT: ${model.lutName}'),
        if (model.lightCondition != null) Text('Luz: ${model.lightCondition}'),
        const SizedBox(height: 8),
        if (path != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: File(path).existsSync()
                ? Image.file(File(path), height: 160, fit: BoxFit.cover)
                : Container(
                    height: 160,
                    color: palette.surfaceOverlay,
                  ),
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
