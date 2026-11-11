import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/database/rental_queries.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../shared/pdf_export/shoot_day_order_pdf.dart';
import '../export_center/export_runner.dart';
import 'shoot_calendar.dart';
import 'shoot_calendar_ics.dart';

String _safe(String text) =>
    text.replaceAll(RegExp(r'[^\w\s-]', unicode: true), '').trim();

Rect? _originOf(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
}

Future<void> _save(BuildContext context, ExportFile file, String done) async {
  final origin = _originOf(context);
  try {
    final path = await ExportRunner.save([file], shareOrigin: origin);
    if (path != null && context.mounted) AppSnackBar.show(context, done);
  } catch (e) {
    if (context.mounted) {
      AppSnackBar.show(context, 'No se pudo exportar: $e', isError: true);
    }
  }
}

/// Orden del día en PDF de [dayIds], o de todas las jornadas.
Future<void> exportShootDayOrder(
  BuildContext context,
  AppDatabase db, {
  required int projectId,
  Set<int> dayIds = const {},
  String? dayName,
}) async {
  final project = await db.getProject(projectId);
  if (project == null || !context.mounted) return;
  final name = [
    'Orden del día',
    dayName ?? '',
    _safe(project.name),
  ].where((s) => s.isNotEmpty).join(' - ');
  await _save(
    context,
    ExportFile(
      name,
      'pdf',
      () => ShootDayOrderPdf.build(db, project, dayIds: dayIds),
    ),
    'Orden del día guardado.',
  );
}

/// Todo el calendario de rodaje en `.ics`.
Future<void> exportShootCalendarIcs(
  BuildContext context,
  AppDatabase db, {
  required int projectId,
}) async {
  final project = await db.getProject(projectId);
  if (project == null || !context.mounted) return;
  Future<Uint8List> build() async {
    final houses = await db.watchRentalHouses(projectId).first;
    final entries = buildShootCalendar(
      documents: await db.getShootDocumentsForProject(projectId),
      blocks: await db.getShootDayBlocks(projectId),
      reservations: await db.watchRentalReservations(projectId).first,
      houses: {for (final h in houses) h.uid: h},
      sites: {
        for (final s in await db.watchSitesForProject(projectId).first) s.id: s,
      },
      scenes: {
        for (final s in await db.watchScenesForProject(projectId).first)
          s.id: s,
      },
      shots: {for (final s in await db.getShotsForProject(projectId)) s.id: s},
    );
    return Uint8List.fromList(
      utf8.encode(
        buildShootCalendarIcs(projectName: project.name, entries: entries),
      ),
    );
  }

  await _save(
    context,
    ExportFile('Calendario de rodaje - ${_safe(project.name)}', 'ics', build),
    'Calendario guardado: ábrelo con Calendario, Google u Outlook.',
  );
}
