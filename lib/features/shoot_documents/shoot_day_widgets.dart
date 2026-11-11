import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/media_storage.dart';
import '../../core/utils/photo_source_picker.dart';
import '../../core/utils/user_error.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../shared/rich_text/script_markup.dart';
import '../camera_plan/shot_cover.dart';
import 'shoot_day_timeline.dart';

/// Elige una hora y la devuelve como «HH:mm».
Future<String?> pickClockTime(
  BuildContext context, {
  required String? current,
  required String fallback,
  required String help,
}) async {
  final parts = (current ?? fallback).split(':');
  final picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(
      hour: int.tryParse(parts.first) ?? 8,
      minute: int.tryParse(parts.last) ?? 0,
    ),
    helpText: help,
  );
  if (picked == null) return null;
  return '${picked.hour.toString().padLeft(2, '0')}:'
      '${picked.minute.toString().padLeft(2, '0')}';
}

IconData shootStripIcon(ShootStripKind kind) => switch (kind) {
  ShootStripKind.call => Icons.campaign_outlined,
  ShootStripKind.prelight => Icons.wb_incandescent_outlined,
  ShootStripKind.setup => Icons.construction_outlined,
  ShootStripKind.wrap => Icons.inventory_outlined,
  ShootStripKind.meal => Icons.restaurant_outlined,
  ShootStripKind.rest => Icons.coffee_outlined,
  ShootStripKind.move => Icons.local_shipping_outlined,
  ShootStripKind.note => Icons.sticky_note_2_outlined,
};

Color shootStripColor(ShootStripKind kind, AppPalette palette) =>
    switch (kind) {
      ShootStripKind.call => palette.accent,
      ShootStripKind.prelight => const Color(0xFFB794F6),
      ShootStripKind.setup => const Color(0xFFF06EA9),
      ShootStripKind.wrap => const Color(0xFF8A97AD),
      ShootStripKind.meal => const Color(0xFFF2B84B),
      ShootStripKind.rest => const Color(0xFF6FCF97),
      ShootStripKind.move => const Color(0xFFE58A6B),
      ShootStripKind.note => palette.textSecondary,
    };

/// La imagen del plano, o un hueco si no tiene.
class ShootShotThumb extends StatelessWidget {
  final Shot shot;
  final double width;
  final double height;

  const ShootShotThumb({
    super.key,
    required this.shot,
    this.width = 64,
    this.height = 36,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: width,
        height: height,
        child:
            shotCoverThumbnail(shot, cacheWidth: (width * 3).round()) ??
            ColoredBox(
              color: palette.surfaceOverlay,
              child: Icon(
                Icons.image_outlined,
                size: 16,
                color: palette.textTertiary,
              ),
            ),
      ),
    );
  }
}

/// «3 · Plano general»: número y tipología del plano.
String shootShotTitle(Shot shot) {
  final framing = scriptMarkupToPlain(shot.framing).trim();
  return framing.isEmpty ? 'Plano ${shot.number}' : '${shot.number} · $framing';
}

/// Un plano en una lista: imagen, número y tipología.
class ShootShotRow extends StatelessWidget {
  final Shot shot;
  final double thumbWidth;
  final List<Widget> trailing;

  /// Hora y apunte del plan de rodaje.
  final ShotTime time;

  const ShootShotRow({
    super.key,
    required this.shot,
    this.thumbWidth = 64,
    this.trailing = const [],
    this.time = const ShotTime(),
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        ShootShotThumb(
          shot: shot,
          width: thumbWidth,
          height: thumbWidth * 9 / 16,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                shootShotTitle(shot),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption(
                  palette,
                ).copyWith(color: palette.textPrimary),
              ),
              if (!time.isEmpty) ShotTimeText(time: time, maxLines: 2),
            ],
          ),
        ),
        ...trailing,
      ],
    );
  }
}

/// Un plano como tarjeta pequeña dentro de su escena.
class ShootShotTile extends StatelessWidget {
  final Shot shot;
  final double width;
  final ShotTime time;

  const ShootShotTile({
    super.key,
    required this.shot,
    this.width = 112,
    this.time = const ShotTime(),
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShootShotThumb(shot: shot, width: width, height: width * 9 / 16),
          const SizedBox(height: 4),
          Text(
            shootShotTitle(shot),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption(
              palette,
            ).copyWith(color: palette.textPrimary, fontSize: 11),
          ),
          if (!time.isEmpty) ShotTimeText(time: time, maxLines: 3),
        ],
      ),
    );
  }
}

/// «10:15 – 10:50 · PMC de Ali…»: la hora del plano en el plan de rodaje.
class ShotTimeText extends StatelessWidget {
  final ShotTime time;
  final int? maxLines;

  const ShotTimeText({super.key, required this.time, this.maxLines});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final range = shootTimeRange(time.from, time.to);
    final note = time.note.trim();
    return Text.rich(
      TextSpan(
        children: [
          if (range.isNotEmpty)
            TextSpan(
              text: range,
              style: TextStyle(
                color: palette.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (range.isNotEmpty && note.isNotEmpty) const TextSpan(text: ' · '),
          if (note.isNotEmpty) TextSpan(text: note),
        ],
      ),
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: AppTypography.caption(palette).copyWith(fontSize: 11),
    );
  }
}

/// Una franja del orden: montaje, comida, cambio de localización…
class ShootStripCard extends StatelessWidget {
  final ShootDocumentBlock block;
  final String? siteName;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const ShootStripCard({
    super.key,
    required this.block,
    this.siteName,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(10, 8, 8, 8),
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final strip = ShootStrip.of(block);
    final color = shootStripColor(strip.kind, palette);
    final time = shootTimeRange(strip.from, strip.to);
    final note = block.noteBody?.trim() ?? '';
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(shootStripIcon(strip.kind), size: 16, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    if (time.isNotEmpty) time,
                    ShootStrip.titleOf(block),
                  ].join(' · '),
                  style: AppTypography.bodyMedium(
                    palette,
                  ).copyWith(color: palette.textPrimary),
                ),
                if (siteName != null)
                  Text(siteName!, style: AppTypography.caption(palette)),
                if (note.isNotEmpty)
                  Text(note, style: AppTypography.caption(palette)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Resultado de la hoja de franja: lo escrito, o que se quiere eliminar.
class ShootStripEdit {
  final ShootStripDraft? draft;

  const ShootStripEdit(this.draft);

  bool get deleted => draft == null;
}

/// Crea o edita una franja.
Future<ShootStripEdit?> showShootStripSheet(
  BuildContext context, {
  ShootDocumentBlock? block,
  List<LocationSite> sites = const [],
}) {
  final palette = context.palette;
  return showModalBottomSheet<ShootStripEdit>(
    context: context,
    isScrollControlled: true,
    backgroundColor: palette.surfaceElevated,
    builder: (_) => _StripSheet(block: block, sites: sites),
  );
}

class _StripSheet extends StatefulWidget {
  final ShootDocumentBlock? block;
  final List<LocationSite> sites;

  const _StripSheet({required this.block, required this.sites});

  @override
  State<_StripSheet> createState() => _StripSheetState();
}

class _StripSheetState extends State<_StripSheet> {
  late ShootStrip _strip = widget.block == null
      ? const ShootStrip(kind: ShootStripKind.setup)
      : ShootStrip.of(widget.block!);
  late final _label = TextEditingController(
    text: widget.block?.customLabel ?? '',
  );
  late final _note = TextEditingController(text: widget.block?.noteBody ?? '');

  @override
  void dispose() {
    _label.dispose();
    _note.dispose();
    super.dispose();
  }

  void _set({
    ShootStripKind? kind,
    Value<String?> from = const Value.absent(),
    Value<String?> to = const Value.absent(),
    Value<String?> siteUid = const Value.absent(),
  }) => setState(() {
    _strip = ShootStrip(
      kind: kind ?? _strip.kind,
      from: from.present ? from.value : _strip.from,
      to: to.present ? to.value : _strip.to,
      siteUid: siteUid.present ? siteUid.value : _strip.siteUid,
    );
  });

  Future<void> _pick({required bool from}) async {
    final value = await pickClockTime(
      context,
      current: from ? _strip.from : _strip.to,
      fallback: from ? '08:00' : (_strip.from ?? '09:00'),
      help: from ? 'Empieza' : 'Termina',
    );
    if (value == null) return;
    _set(from: from ? Value(value) : const Value.absent());
    if (!from) _set(to: Value(value));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final label = AppTypography.label(palette);
    final sitesWithUid = [
      for (final s in widget.sites)
        if (s.uid != null) s,
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.block == null ? 'Nueva franja' : 'Editar franja',
                style: AppTypography.titleMedium(palette),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final kind in ShootStripKind.values)
                    ChoiceChip(
                      avatar: Icon(shootStripIcon(kind), size: 16),
                      label: Text(kind.label),
                      selected: _strip.kind == kind,
                      onSelected: (_) => _set(kind: kind),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Horario', style: label),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pick(from: true),
                      child: Text(_strip.from ?? 'Empieza'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pick(from: false),
                      child: Text(_strip.to ?? 'Termina'),
                    ),
                  ),
                  if (_strip.from != null || _strip.to != null)
                    IconButton(
                      tooltip: 'Quitar el horario',
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () =>
                          _set(from: const Value(null), to: const Value(null)),
                    ),
                ],
              ),
              if (_strip.kind == ShootStripKind.move &&
                  sitesWithUid.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text('Hacia', style: label),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: sitesWithUid.any((s) => s.uid == _strip.siteUid)
                      ? _strip.siteUid
                      : null,
                  isExpanded: true,
                  dropdownColor: palette.surfaceElevated,
                  decoration: const InputDecoration(isDense: true),
                  hint: const Text('Elegir localización'),
                  items: [
                    for (final s in sitesWithUid)
                      DropdownMenuItem(value: s.uid, child: Text(s.name)),
                  ],
                  onChanged: (uid) => _set(siteUid: Value(uid)),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _label,
                decoration: InputDecoration(
                  labelText: 'Nombre (opcional)',
                  hintText: _strip.kind.label,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _note,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Aclaración para el equipo',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  if (widget.block != null)
                    TextButton(
                      onPressed: () =>
                          Navigator.pop(context, const ShootStripEdit(null)),
                      child: Text(
                        'Eliminar',
                        style: TextStyle(color: palette.error),
                      ),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      ShootStripEdit(
                        ShootStripDraft(
                          strip: _strip,
                          label: _label.text,
                          note: _note.text,
                        ),
                      ),
                    ),
                    child: const Text('Guardar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hora y aclaración de una escena. Devuelve lo escrito.
Future<SceneSchedule?> showSceneScheduleSheet(
  BuildContext context, {
  required String title,
  required SceneSchedule initial,
}) {
  final palette = context.palette;
  return showModalBottomSheet<SceneSchedule>(
    context: context,
    isScrollControlled: true,
    backgroundColor: palette.surfaceElevated,
    builder: (_) => _SceneScheduleSheet(title: title, initial: initial),
  );
}

class _SceneScheduleSheet extends StatefulWidget {
  final String title;
  final SceneSchedule initial;

  const _SceneScheduleSheet({required this.title, required this.initial});

  @override
  State<_SceneScheduleSheet> createState() => _SceneScheduleSheetState();
}

class _SceneScheduleSheetState extends State<_SceneScheduleSheet> {
  late String? _from = widget.initial.from;
  late String? _to = widget.initial.to;
  late final _note = TextEditingController(text: widget.initial.note);

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool from}) async {
    final value = await pickClockTime(
      context,
      current: from ? _from : _to,
      fallback: from ? '08:00' : (_from ?? '09:00'),
      help: from ? 'Empieza' : 'Termina',
    );
    if (value == null) return;
    setState(() => from ? _from = value : _to = value);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.title, style: AppTypography.titleMedium(palette)),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pick(from: true),
                      child: Text(_from ?? 'Empieza'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pick(from: false),
                      child: Text(_to ?? 'Termina'),
                    ),
                  ),
                  if (_from != null || _to != null)
                    IconButton(
                      tooltip: 'Quitar el horario',
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => setState(() {
                        _from = null;
                        _to = null;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _note,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Aclaración para el equipo',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    SceneSchedule(from: _from, to: _to, note: _note.text),
                  ),
                  child: const Text('Guardar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Las fotos de una localización, las mismas que en su ficha. Añadir aquí
/// también las añade allí.
class ShootSitePhotos extends ConsumerWidget {
  final int projectId;
  final LocationSite site;

  const ShootSitePhotos({
    super.key,
    required this.projectId,
    required this.site,
  });

  Future<void> _add(BuildContext context, AppDatabase db) async {
    final paths = await PhotoSourcePicker.pickImages(
      context,
      title: 'Fotos · ${site.name}',
    );
    if (paths.isEmpty) return;
    var sort = (await db.watchImagesForSite(site.id).first).length;
    try {
      for (final path in paths) {
        final stored = await MediaStorage.copySiteImage(
          projectId: projectId,
          siteId: site.id,
          sourcePath: path,
        );
        await db.insertSiteImage(
          SiteImagesCompanion.insert(
            siteId: site.id,
            imagePath: stored,
            sortOrder: Value(sort++),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) AppSnackBar.show(context, userFriendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);
    return StreamBuilder<List<SiteImage>>(
      stream: db.watchImagesForSite(site.id),
      builder: (context, snap) {
        final images = [
          for (final i in snap.data ?? const <SiteImage>[])
            if (File(i.imagePath).existsSync()) i,
        ];
        return SizedBox(
          height: 72,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final image in images)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(
                      File(image.imagePath),
                      width: 108,
                      height: 72,
                      fit: BoxFit.cover,
                      cacheWidth: 324,
                      errorBuilder: (_, _, _) =>
                          const SizedBox(width: 108, height: 72),
                    ),
                  ),
                ),
              OutlinedButton(
                onPressed: () => _add(context, db),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      size: 16,
                      color: palette.accent,
                    ),
                    const SizedBox(width: 6),
                    const Text('Fotos'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
