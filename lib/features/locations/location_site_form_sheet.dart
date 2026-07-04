import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';

class LocationSiteFormOutcome {
  final bool saved;
  final int? siteId;

  const LocationSiteFormOutcome({required this.saved, this.siteId});
}

class LocationSiteFormSheet extends ConsumerStatefulWidget {
  final int projectId;
  final LocationSite? site;
  final int nextSortOrder;

  const LocationSiteFormSheet({
    super.key,
    required this.projectId,
    this.site,
    this.nextSortOrder = 0,
  });

  @override
  ConsumerState<LocationSiteFormSheet> createState() =>
      _LocationSiteFormSheetState();
}

class _LocationSiteFormSheetState extends ConsumerState<LocationSiteFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _notesCtrl;
  bool _saving = false;

  bool get _isEditing => widget.site != null;

  @override
  void initState() {
    super.initState();
    final site = widget.site;
    _nameCtrl = TextEditingController(text: site?.name ?? '');
    _descriptionCtrl = TextEditingController(text: site?.description ?? '');
    _notesCtrl = TextEditingController(text: site?.notes ?? '');
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
      final site = widget.site!;
      await db.updateSite(site.copyWith(
        name: name,
        description: Value(description.isEmpty ? null : description),
        notes: Value(notes.isEmpty ? null : notes),
      ));
      if (mounted) {
        Navigator.pop(
          context,
          LocationSiteFormOutcome(saved: true, siteId: site.id),
        );
      }
    } else {
      final id = await db.insertSite(LocationSitesCompanion.insert(
        projectId: widget.projectId,
        name: name,
        description: Value(description.isEmpty ? null : description),
        notes: Value(notes.isEmpty ? null : notes),
        sortOrder: Value(widget.nextSortOrder),
      ));
      final site = (await db.getSiteById(id))!;
      await db.ensureDefaultSetForSite(
        projectId: widget.projectId,
        site: site,
      );
      if (mounted) {
        Navigator.pop(
          context,
          LocationSiteFormOutcome(saved: true, siteId: id),
        );
      }
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
              _isEditing ? 'Editar localización' : 'Nueva localización',
              style: AppTypography.titleLarge(palette),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Contenedor amplio que agrupa sets de rodaje '
              '(ej. un hospital con urgencias, plantas, azotea). '
              'Se crea un set base con el mismo nombre.',
              style: AppTypography.caption(palette),
            ),
            const SizedBox(height: AppSpacing.lg),
            _field('Nombre', _nameCtrl, palette, hint: 'Ej. HOSPITAL CENTRAL'),
            const SizedBox(height: AppSpacing.md),
            _field(
              'Descripción',
              _descriptionCtrl,
              palette,
              hint: 'Notas generales del lugar, accesos, logística…',
              minLines: 2,
            ),
            const SizedBox(height: AppSpacing.md),
            _field('Notas internas', _notesCtrl, palette, minLines: 2),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: _isEditing ? 'Guardar' : 'Crear localización',
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

Future<LocationSiteFormOutcome?> showLocationSiteFormSheet(
  BuildContext context, {
  required int projectId,
  LocationSite? site,
  int nextSortOrder = 0,
}) {
  return showModalBottomSheet<LocationSiteFormOutcome>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.palette.surfaceElevated,
    builder: (_) => LocationSiteFormSheet(
      projectId: projectId,
      site: site,
      nextSortOrder: nextSortOrder,
    ),
  );
}
