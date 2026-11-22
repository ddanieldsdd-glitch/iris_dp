import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'activity_providers.dart';

/// «Último cambio: Ana (gaffer) · hace 5 min · planta». Nada si no se sabe.
class LastChangeLine extends ConsumerWidget {
  const LastChangeLine({
    super.key,
    required this.projectId,
    required this.collection,
    required this.uid,
  });

  final int projectId;
  final String collection;
  final String? uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = this.uid;
    if (uid == null) return const SizedBox.shrink();
    final entry = ref
        .watch(lastChangesProvider(projectId))
        .valueOrNull?['$collection/$uid'];
    if (entry == null) return const SizedBox.shrink();
    final palette = context.palette;
    final what = entry.fields.isEmpty ? '' : ' · ${entry.fields.join(', ')}';
    return Row(
      children: [
        Icon(Icons.history, size: 14, color: palette.textTertiary),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            'Último cambio: ${entry.who} · ${whenLabel(entry.at)}$what',
            style: AppTypography.caption(palette),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
