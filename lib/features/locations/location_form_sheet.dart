import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/scene_color.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/scene_color_picker.dart';

class SetFormOutcome {
  final bool saved;

  const SetFormOutcome({required this.saved});
}

class LocationFormSheet extends ConsumerStatefulWidget {
  final int projectId;
  final LocationBasePlan? location;
  final int siteId;
  final int nextSortOrder;

  const LocationFormSheet({
    super.key,
    required this.projectId,
    this.location,
    required this.siteId,
    this.nextSortOrder = 0,
  });

  @override
  ConsumerState<LocationFormSheet> createState() => _LocationFormSheetState();
}

class _LocationFormSheetState extends ConsumerState<LocationFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _notesCtrl;
  late String _color;
  bool _saving = false;
  String? _parentSiteName;

  bool get _isEditing => widget.location != null;

  @override
  void initState() {
    super.initState();
    final loc = widget.location;
    _nameCtrl = TextEditingController(text: loc?.locationName ?? '');
    _descriptionCtrl = TextEditingController(text: loc?.description ?? '');
    _notesCtrl = TextEditingController(text: loc?.notes ?? '');
    _color = loc?.color ?? kSceneColorNeutral;
    _loadDefaultColor();
    _loadParentSiteName();
  }

  Future<void> _loadDefaultColor() async {
    if (_isEditing) return;
    final db = ref.read(databaseProvider);
    final site = await db.getSiteById(widget.siteId);
    if (site == null || !mounted) return;

    final sites = await db.watchSitesForProject(widget.projectId).first;
    final sets = await db.watchSetsForSite(widget.siteId).first;
    final siteIndex = sites.indexWhere((s) => s.id == site.id);

    setState(() {
      _color = defaultSetHexForSite(
        siteIndex: siteIndex >= 0 ? siteIndex : sites.length,
        setIndex: sets.length,
        totalSets: sets.length + 1,
      );
    });
  }

  Future<void> _loadParentSiteName() async {
    final site = await ref.read(databaseProvider).getSiteById(widget.siteId);
    if (mounted && site != null) {
      setState(() => _parentSiteName = site.name);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final description = _descriptionCtrl.text.trim();
    final notes = _notesCtrl.text.trim();

    if (_isEditing) {
      final loc = widget.location!;
      await db.updateLocation(loc.copyWith(
        locationName: name,
        description: Value(description.isEmpty ? null : description),
        notes: Value(notes.isEmpty ? null : notes),
        color: _color,
      ));
      await db.linkScenesToLocations(widget.projectId);
      await db.applyLocationColorToLinkedScenes(loc.id);
    } else {
      await db.insertLocation(LocationBasePlansCompanion.insert(
        projectId: widget.projectId,
        siteId: Value(widget.siteId),
        locationName: name,
        description: Value(description.isEmpty ? null : description),
        notes: Value(notes.isEmpty ? null : notes),
        color: Value(_color),
        sortOrder: Value(widget.nextSortOrder),
      ));
      await db.linkScenesToLocations(widget.projectId);
      final locs = await db.watchLocationsForProject(widget.projectId).first;
      for (final l in locs) {
        if (l.siteId == widget.siteId &&
            l.locationName.trim().toLowerCase() == name.trim().toLowerCase()) {
          await db.applyLocationColorToLinkedScenes(l.id);
          break;
        }
      }
    }

    if (mounted) {
      Navigator.pop(context, const SetFormOutcome(saved: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? 'Editar set de rodaje' : 'Nuevo set de rodaje',
              style: AppTypography.titleLarge(palette),
            ),
            if (_parentSiteName != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Localización: $_parentSiteName',
                style: AppTypography.caption(palette)
                    .copyWith(color: palette.accent),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            _field('Nombre del set', _nameCtrl, palette,
                hint: 'Ej. RÍO, ENTRADA DEL BOSQUE'),
            const SizedBox(height: AppSpacing.md),
            _field(
              'Descripción',
              _descriptionCtrl,
              palette,
              hint: 'Condiciones del set, accesos, tono visual…',
              minLines: 2,
            ),
            const SizedBox(height: AppSpacing.md),
            _field('Notas internas', _notesCtrl, palette, minLines: 2),
            const SizedBox(height: AppSpacing.md),
            SceneColorPicker(
              palette: palette,
              selectedHex: _color,
              onChanged: (hex) => setState(() => _color = hex),
              hint:
                  'Color del set en guion literario y guion técnico. '
                  'La galería, luz y plano 2D son de este set.',
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: _isEditing ? 'Guardar' : 'Crear set',
              icon: Icons.check,
              loading: _saving,
              onTap: _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl,
    AppPalette palette, {
    String? hint,
    int minLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.label(palette)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          minLines: minLines,
          maxLines: minLines > 1 ? null : 1,
          style: AppTypography.bodyLarge(palette),
          decoration: InputDecoration(hintText: hint ?? label),
        ),
      ],
    );
  }
}

Future<SetFormOutcome?> showLocationFormSheet(
  BuildContext context, {
  required int projectId,
  required int siteId,
  LocationBasePlan? location,
  int nextSortOrder = 0,
}) {
  return showModalBottomSheet<SetFormOutcome>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.palette.surfaceElevated,
    builder: (_) => LocationFormSheet(
      projectId: projectId,
      siteId: siteId,
      location: location,
      nextSortOrder: nextSortOrder,
    ),
  );
}
