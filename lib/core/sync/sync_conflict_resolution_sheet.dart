import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import 'sync_plan.dart';

/// Pantalla modal para revisar y confirmar cambios de sincronización.
class SyncConflictResolutionSheet extends StatefulWidget {
  final SyncPlan plan;
  final Future<void> Function(SyncPlan plan) onApply;

  const SyncConflictResolutionSheet({
    super.key,
    required this.plan,
    required this.onApply,
  });

  static Future<bool?> show(
    BuildContext context, {
    required SyncPlan plan,
    required Future<void> Function(SyncPlan plan) onApply,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => SyncConflictResolutionSheet(
        plan: plan,
        onApply: onApply,
      ),
    );
  }

  @override
  State<SyncConflictResolutionSheet> createState() =>
      _SyncConflictResolutionSheetState();
}

class _SyncConflictResolutionSheetState
    extends State<SyncConflictResolutionSheet> {
  late List<SyncPlanItem> _items;
  var _applying = false;

  @override
  void initState() {
    super.initState();
    _items = widget.plan.items.map((i) => i.copyWith()).toList();
  }

  void _setAll(SyncResolutionChoice choice) {
    setState(() {
      _items = _items.map((i) => i.copyWith(choice: choice)).toList();
    });
  }

  Future<void> _apply() async {
    setState(() => _applying = true);
    try {
      await widget.onApply(SyncPlan(items: _items));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al sincronizar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final conflicts = _items
        .where((i) =>
            i.action == SyncPlanAction.conflict ||
            i.action == SyncPlanAction.contentConflict)
        .length;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: BoxDecoration(
          color: palette.surfaceElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.sync_problem, color: palette.warning),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Revisar sincronización',
                          style: AppTypography.titleLarge(palette),
                        ),
                      ),
                      IconButton(
                        onPressed:
                            _applying ? null : () => Navigator.pop(context, false),
                        icon: Icon(Icons.close, color: palette.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Hay diferencias entre este dispositivo y la nube. '
                    'Revisa cada cambio antes de aplicar nada.',
                    style: AppTypography.bodyMedium(palette),
                  ),
                  if (conflicts > 0) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '$conflicts conflicto${conflicts == 1 ? '' : 's'} '
                      'requiere${conflicts == 1 ? '' : 'n'} tu decisión.',
                      style: AppTypography.caption(palette)
                          .copyWith(color: palette.warning),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      OutlinedButton(
                        onPressed: _applying
                            ? null
                            : () => _setAll(SyncResolutionChoice.useLocal),
                        child: const Text('Todo local'),
                      ),
                      OutlinedButton(
                        onPressed: _applying
                            ? null
                            : () => _setAll(SyncResolutionChoice.useCloud),
                        child: const Text('Todo nube'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: _items.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  return _SyncPlanItemCard(
                    item: _items[index],
                    palette: palette,
                    onChoiceChanged: (choice) {
                      setState(() {
                        _items[index] = _items[index].copyWith(choice: choice);
                      });
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Cancelar',
                      variant: AppButtonVariant.secondary,
                      onTap: _applying
                          ? null
                          : () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 2,
                    child: AppButton(
                      label: _applying ? 'Aplicando…' : 'Aplicar cambios',
                      icon: Icons.check,
                      loading: _applying,
                      onTap: _applying ? null : _apply,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncPlanItemCard extends StatelessWidget {
  final SyncPlanItem item;
  final AppPalette palette;
  final ValueChanged<SyncResolutionChoice> onChoiceChanged;

  const _SyncPlanItemCard({
    required this.item,
    required this.palette,
    required this.onChoiceChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isConflict = item.action == SyncPlanAction.conflict ||
        item.action == SyncPlanAction.contentConflict;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      focused: isConflict,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_iconForAction(item.action), size: 18, color: palette.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(item.title, style: AppTypography.titleMedium(palette)),
              ),
              if (isConflict)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: palette.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Conflicto',
                    style: AppTypography.caption(palette)
                        .copyWith(color: palette.warning),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(item.description, style: AppTypography.caption(palette)),
          if (item.localContentSummary != null ||
              item.cloudContentSummary != null) ...[
            const SizedBox(height: AppSpacing.sm),
            if (item.localContentSummary != null)
              Text(
                'Local: ${item.localContentSummary!.label}',
                style: AppTypography.caption(palette),
              ),
            if (item.cloudContentSummary != null)
              Text(
                'Nube: ${item.cloudContentSummary!.label}',
                style: AppTypography.caption(palette),
              ),
          ],
          if (item.diffs.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ...item.diffs.map(
              (d) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 88,
                      child: Text(d.label, style: AppTypography.label(palette)),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _DiffLine(
                            label: 'Local',
                            value: d.localValue ?? '—',
                            palette: palette,
                            highlight:
                                item.choice == SyncResolutionChoice.useLocal,
                          ),
                          _DiffLine(
                            label: 'Nube',
                            value: d.cloudValue ?? '—',
                            palette: palette,
                            highlight:
                                item.choice == SyncResolutionChoice.useCloud,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<SyncResolutionChoice>(
            segments: const [
              ButtonSegment(
                value: SyncResolutionChoice.useLocal,
                label: Text('Local'),
                icon: Icon(Icons.phone_iphone, size: 16),
              ),
              ButtonSegment(
                value: SyncResolutionChoice.useCloud,
                label: Text('Nube'),
                icon: Icon(Icons.cloud_outlined, size: 16),
              ),
              ButtonSegment(
                value: SyncResolutionChoice.skip,
                label: Text('Omitir'),
                icon: Icon(Icons.block, size: 16),
              ),
            ],
            selected: {item.choice},
            onSelectionChanged: (s) => onChoiceChanged(s.first),
          ),
        ],
      ),
    );
  }

  IconData _iconForAction(SyncPlanAction action) => switch (action) {
        SyncPlanAction.pushNewLocal => Icons.upload_outlined,
        SyncPlanAction.importFromCloud => Icons.download_outlined,
        SyncPlanAction.updateLocalFromCloud => Icons.cloud_download_outlined,
        SyncPlanAction.updateCloudFromLocal => Icons.cloud_upload_outlined,
        SyncPlanAction.deleteLocal => Icons.delete_outline,
        SyncPlanAction.deleteCloud => Icons.cloud_off_outlined,
        SyncPlanAction.conflict => Icons.sync_problem,
        SyncPlanAction.pushContentLocal => Icons.movie_creation_outlined,
        SyncPlanAction.pullContentCloud => Icons.movie_filter_outlined,
        SyncPlanAction.contentConflict => Icons.sync_problem,
      };
}

class _DiffLine extends StatelessWidget {
  final String label;
  final String value;
  final AppPalette palette;
  final bool highlight;

  const _DiffLine({
    required this.label,
    required this.value,
    required this.palette,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: RichText(
        text: TextSpan(
          style: AppTypography.caption(palette).copyWith(
            color: highlight ? palette.accent : palette.textSecondary,
            fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
          ),
          children: [
            TextSpan(text: '$label: '),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

/// Banner en pantalla de proyectos cuando hay sync pendiente de revisar.
class PendingSyncBanner extends ConsumerWidget {
  final SyncPlan plan;
  final VoidCallback onReview;

  const PendingSyncBanner({
    super.key,
    required this.plan,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    return AppCard(
      onTap: onReview,
      padding: const EdgeInsets.all(AppSpacing.md),
      focused: true,
      child: Row(
        children: [
          Icon(Icons.sync_problem, color: palette.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cambios pendientes de sincronizar',
                  style: AppTypography.label(palette),
                ),
                Text(
                  '${plan.items.length} diferencia${plan.items.length == 1 ? '' : 's'} '
                  'entre este dispositivo y la nube. Toca para revisar.',
                  style: AppTypography.caption(palette),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: palette.textSecondary),
        ],
      ),
    );
  }
}
