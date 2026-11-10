import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/rental_queries.dart';
import '../../../core/notifications/rental_reminders_host.dart';
import '../../../core/settings/app_prefs.dart';
import '../../../core/sync/device_label.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import 'rental_format.dart';
import 'rental_import_review_screen.dart';

/// A partir de este ancho, lista y detalle van lado a lado.
const double _splitMinWidth = 720;

/// Las reservas de material del proyecto, agrupadas por casa.
class RentalsTab extends ConsumerStatefulWidget {
  final int projectId;

  const RentalsTab({super.key, required this.projectId});

  @override
  ConsumerState<RentalsTab> createState() => _RentalsTabState();
}

class _RentalsTabState extends ConsumerState<RentalsTab> {
  late final AppDatabase _db = ref.read(databaseProvider);
  late final _houses = _db.watchRentalHouses(widget.projectId);
  late final _reservations = _db.watchRentalReservations(widget.projectId);
  String? _selectedUid;

  Future<void> _import() async {
    final uid = await pickAndImportRentalList(context, ref, widget.projectId);
    if (uid != null && mounted) setState(() => _selectedUid = uid);
  }

  Future<void> _drop(List<String> paths) async {
    if (paths.isEmpty) return;
    final file = File(paths.first);
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    final uid = await importRentalListBytes(
      context,
      ref,
      widget.projectId,
      file.uri.pathSegments.last,
      bytes,
    );
    if (uid != null && mounted) setState(() => _selectedUid = uid);
  }

  @override
  Widget build(BuildContext context) {
    final content = StreamBuilder<List<RentalHouse>>(
      stream: _houses,
      builder: (context, houseSnap) => StreamBuilder<List<RentalReservation>>(
        stream: _reservations,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final reservations = snap.data!;
          final houses = houseSnap.data ?? const <RentalHouse>[];
          if (reservations.isEmpty) return _empty(context);
          return LayoutBuilder(
            builder: (context, constraints) {
              final split = constraints.maxWidth >= _splitMinWidth;
              final selected =
                  reservations
                      .where((r) => r.uid == _selectedUid)
                      .firstOrNull ??
                  (split ? reservations.first : null);
              final list = _list(
                context,
                houses,
                reservations,
                selected,
                split,
              );
              if (!split) return list;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 340, child: list),
                  VerticalDivider(width: 1, color: context.palette.divider),
                  Expanded(
                    child: selected == null
                        ? const SizedBox.shrink()
                        : RentalReservationDetail(
                            key: ValueKey(selected.uid),
                            reservation: selected,
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
    if (Platform.isMacOS || Platform.isWindows) {
      return DropTarget(
        onDragDone: (d) => _drop([for (final f in d.files) f.path]),
        child: content,
      );
    }
    return content;
  }

  Widget _empty(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Importa las listas de material para tener a mano qué se recoge, '
              'dónde y cuándo.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium(palette),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: _import,
              icon: const Icon(Icons.upload_file, size: 18),
              label: const Text('Importar lista'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(
    BuildContext context,
    List<RentalHouse> houses,
    List<RentalReservation> reservations,
    RentalReservation? selected,
    bool split,
  ) {
    final palette = context.palette;
    final gutter = split ? AppSpacing.md : AppLayout.gutter(context);
    final groups = <String?, List<RentalReservation>>{};
    for (final r in reservations) {
      groups.putIfAbsent(r.houseUid, () => []).add(r);
    }
    final houseByUid = {for (final h in houses) h.uid: h};
    return ListView(
      padding: EdgeInsets.fromLTRB(gutter, AppSpacing.md, gutter, 40),
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _import,
              icon: const Icon(Icons.upload_file, size: 18),
              label: const Text('Importar lista'),
            ),
            IconButton(
              tooltip: 'Recordatorios en este aparato',
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const _ReminderSettingsDialog(),
              ),
              icon: const Icon(Icons.notifications_outlined, size: 20),
            ),
          ],
        ),
        for (final e in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: 4),
            child: Text(
              houseByUid[e.key]?.name ?? 'Sin casa',
              style: AppTypography.titleMedium(palette),
            ),
          ),
          if (houseByUid[e.key]?.contact case final contact?)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(contact, style: AppTypography.caption(palette)),
            ),
          for (final r in e.value)
            _ReservationCard(
              reservation: r,
              selected: split && selected?.uid == r.uid,
              onTap: () {
                if (split) {
                  setState(() => _selectedUid = r.uid);
                } else {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(
                          backgroundColor: palette.surface,
                          title: Text(
                            r.title,
                            style: AppTypography.titleMedium(palette),
                          ),
                        ),
                        body: RentalReservationDetail(
                          reservationUid: r.uid,
                          projectId: r.projectId,
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
        ],
      ],
    );
  }
}

class _ReminderSettingsDialog extends StatelessWidget {
  const _ReminderSettingsDialog();

  @override
  Widget build(BuildContext context) {
    final prefs = AppPrefs.instance;
    const scope = SettingsScope.global();
    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) => AlertDialog(
        title: const Text('Recordatorios de material'),
        content: SizedBox(
          width: AppLayout.dialogWidth(context, 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Avisar en este aparato'),
                value: prefs.get(RentalReminderPrefs.enabled),
                onChanged: (v) =>
                    prefs.setIn(RentalReminderPrefs.enabled, scope, v),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('La víspera, a las'),
                trailing: DropdownButton<int>(
                  value: prefs.get(RentalReminderPrefs.eveHour),
                  items: [
                    for (final h in const [18, 19, 20, 21, 22])
                      DropdownMenuItem(value: h, child: Text('$h:00')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      prefs.setIn(RentalReminderPrefs.eveHour, scope, v);
                    }
                  },
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('El mismo día, antes'),
                trailing: DropdownButton<int>(
                  value: prefs.get(RentalReminderPrefs.minutesBefore),
                  items: [
                    for (final m in const [30, 60, 90, 120, 180])
                      DropdownMenuItem(value: m, child: Text('$m min')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      prefs.setIn(RentalReminderPrefs.minutesBefore, scope, v);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

enum RentalStage {
  pending('Por recoger'),
  pickedUp('Recogido'),
  returned('Devuelto');

  final String label;
  const RentalStage(this.label);

  static RentalStage of(RentalReservation r) => r.returnedAt != null
      ? RentalStage.returned
      : r.pickedUpAt != null
      ? RentalStage.pickedUp
      : RentalStage.pending;
}

class _ReservationCard extends StatelessWidget {
  final RentalReservation reservation;
  final bool selected;
  final VoidCallback onTap;

  const _ReservationCard({
    required this.reservation,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final caption = AppTypography.caption(palette);
    final r = reservation;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      color: selected
          ? palette.accent.withValues(alpha: 0.14)
          : palette.surfaceElevated,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.title, style: AppTypography.titleMedium(palette)),
              const SizedBox(height: 4),
              Text(
                [
                  RentalStage.of(r).label,
                  if (r.number != null) r.number!,
                ].join(' · '),
                style: AppTypography.label(palette),
              ),
              const SizedBox(height: 4),
              Text(
                'Recoger: ${formatRentalMoment(r.pickupAt)}',
                style: caption,
              ),
              Text(
                'Devolver: ${formatRentalMoment(r.returnAt)}',
                style: caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// El detalle de una reserva: el material y los botones Recogido y Devuelto.
class RentalReservationDetail extends ConsumerWidget {
  final RentalReservation? reservation;
  final String? reservationUid;
  final int? projectId;

  const RentalReservationDetail({
    super.key,
    this.reservation,
    this.reservationUid,
    this.projectId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final fixed = reservation;
    if (fixed != null) return _RentalDetailBody(db: db, reservation: fixed);
    return StreamBuilder<List<RentalReservation>>(
      stream: db.watchRentalReservations(projectId!),
      builder: (context, snap) {
        final r = snap.data?.where((x) => x.uid == reservationUid).firstOrNull;
        if (r == null) return const SizedBox.shrink();
        return _RentalDetailBody(db: db, reservation: r);
      },
    );
  }
}

class _RentalDetailBody extends StatelessWidget {
  final AppDatabase db;
  final RentalReservation reservation;

  const _RentalDetailBody({required this.db, required this.reservation});

  String _now() => DateTime.now().toUtc().toIso8601String();

  Future<void> _togglePickedUp() => db.setReservationPickedUp(
    reservation,
    at: reservation.pickedUpAt == null ? _now() : null,
    device: reservation.pickedUpAt == null ? deviceLabel() : null,
  );

  Future<void> _toggleReturned() => db.setReservationReturned(
    reservation,
    at: reservation.returnedAt == null ? _now() : null,
    device: reservation.returnedAt == null ? deviceLabel() : null,
  );

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitar esta lista'),
        content: Text(
          'Se quitará «${reservation.title}» en todos los aparatos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (ok == true) await db.softDeleteRentalReservation(reservation, _now());
  }

  static String _stamp(String? iso, String? device) {
    final at = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (at == null) return '';
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    return ' · ${at.day}/${at.month} $hh:$mm${device == null ? '' : ' · $device'}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final r = reservation;
    final gutter = AppLayout.gutter(context, regular: AppSpacing.lg);
    final returning = r.pickedUpAt != null;
    return StreamBuilder<List<RentalItem>>(
      stream: db.watchRentalItems(r.projectId, r.uid),
      builder: (context, snap) {
        final items = snap.data ?? const <RentalItem>[];
        final checkable = [
          for (final i in items)
            if (i.kind == 'item' && i.removedFromSourceAt == null) i,
        ];
        final checked = checkable
            .where(
              (i) => returning
                  ? i.returnCheckedAt != null
                  : i.pickupCheckedAt != null,
            )
            .length;
        final children = <RentalItem, List<RentalItem>>{};
        final byUid = {for (final i in items) i.uid: i};
        final top = <RentalItem>[];
        for (final i in items) {
          final parent = i.parentUid == null ? null : byUid[i.parentUid];
          if (parent == null) {
            top.add(i);
          } else {
            children.putIfAbsent(parent, () => []).add(i);
          }
        }
        String? section;
        final rows = <Widget>[];
        for (final item in top) {
          if (item.section != section) {
            section = item.section;
            if (section != null) {
              rows.add(
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md, bottom: 4),
                  child: Text(section, style: AppTypography.label(palette)),
                ),
              );
            }
          }
          rows.add(
            _RentalItemTile(
              db: db,
              item: item,
              children: children[item] ?? const [],
              returning: returning,
            ),
          );
        }
        return ListView(
          padding: EdgeInsets.fromLTRB(gutter, AppSpacing.md, gutter, 40),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    r.title,
                    style: AppTypography.titleLarge(palette),
                  ),
                ),
                IconButton(
                  tooltip: 'Quitar lista',
                  onPressed: () => _delete(context),
                  icon: const Icon(Icons.delete_outline, size: 20),
                ),
              ],
            ),
            Text(
              [
                if (r.number != null) 'Reserva ${r.number}',
                if (r.sourceStatus != null) r.sourceStatus!,
                if (r.responsible != null) r.responsible!,
              ].join(' · '),
              style: AppTypography.caption(palette),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Recoger: ${formatRentalMoment(r.pickupAt)}'
              '${_stamp(r.pickedUpAt, r.pickedUpDevice)}',
              style: AppTypography.bodyMedium(palette),
            ),
            Text(
              'Devolver: ${formatRentalMoment(r.returnAt)}'
              '${_stamp(r.returnedAt, r.returnedDevice)}',
              style: AppTypography.bodyMedium(palette),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilterChip(
                  avatar: const Icon(Icons.inventory_2_outlined, size: 16),
                  label: const Text('Recogido'),
                  selected: r.pickedUpAt != null,
                  onSelected: (_) => _togglePickedUp(),
                ),
                FilterChip(
                  avatar: const Icon(
                    Icons.assignment_return_outlined,
                    size: 16,
                  ),
                  label: const Text('Devuelto'),
                  selected: r.returnedAt != null,
                  onSelected: r.pickedUpAt == null
                      ? null
                      : (_) => _toggleReturned(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '$checked de ${checkable.length} '
              '${returning ? 'comprobados al devolver' : 'comprobados al recoger'}',
              style: AppTypography.label(palette),
            ),
            ...rows,
          ],
        );
      },
    );
  }
}

class _RentalItemTile extends StatelessWidget {
  final AppDatabase db;
  final RentalItem item;
  final List<RentalItem> children;
  final bool returning;

  const _RentalItemTile({
    required this.db,
    required this.item,
    required this.children,
    required this.returning,
  });

  bool _isChecked(RentalItem i) =>
      (returning ? i.returnCheckedAt : i.pickupCheckedAt) != null;

  Widget _row(BuildContext context, RentalItem i, {required bool child}) {
    final palette = context.palette;
    final style = child
        ? AppTypography.caption(palette).copyWith(color: palette.textPrimary)
        : AppTypography.bodyMedium(
            palette,
          ).copyWith(color: palette.textPrimary);
    final label = [
      if (i.quantity != null)
        '${formatRentalQuantity(i.quantity)} × ${i.name}'
      else
        i.name,
      if (i.serial != null) 'nº ${i.serial}',
      if (i.note != null) i.note!,
      if (i.removedFromSourceAt != null) 'ya no viene en la lista',
    ].join(' · ');
    if (i.kind == 'note') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(label, style: AppTypography.caption(palette)),
      );
    }
    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.only(left: child ? AppSpacing.md : 0),
      controlAffinity: ListTileControlAffinity.leading,
      value: _isChecked(i),
      onChanged: (v) => db.setRentalItemChecked(
        i,
        returning: returning,
        at: v == true ? DateTime.now().toUtc().toIso8601String() : null,
      ),
      title: Text(label, style: style),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return _row(context, item, child: false);
    final palette = context.palette;
    String? group;
    final rows = <Widget>[];
    for (final c in children) {
      if (c.groupLabel != group) {
        group = c.groupLabel;
        if (group != null) {
          rows.add(
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.md,
                top: AppSpacing.xs,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(group, style: AppTypography.label(palette)),
              ),
            ),
          );
        }
      }
      rows.add(_row(context, c, child: true));
    }
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      leading: Checkbox(
        value: _isChecked(item),
        onChanged: (v) => db.setRentalItemChecked(
          item,
          returning: returning,
          at: v == true ? DateTime.now().toUtc().toIso8601String() : null,
        ),
      ),
      title: Text(
        '${formatRentalQuantity(item.quantity)} × ${item.name}',
        style: AppTypography.bodyMedium(
          palette,
        ).copyWith(color: palette.textPrimary),
      ),
      children: rows,
    );
  }
}
