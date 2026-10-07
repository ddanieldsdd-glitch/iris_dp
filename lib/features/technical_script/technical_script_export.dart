import 'dart:convert';

import 'package:flutter/painting.dart' show Color;

import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/pdf_safe_image.dart';
import '../../core/utils/project_color_scheme.dart';
import '../../core/utils/scene_characters.dart';
import '../../core/utils/shot_reference_import.dart';
import '../../shared/technical_script_export/technical_script_doc.dart';
import 'table/script_sheet_theme.dart';
import 'technical_script_settings.dart';

int _rgb(Color color) => color.toARGB32() & 0xFFFFFF;

/// Monta el guion técnico del proyecto en orden narrativo, tal como se ve en
/// la hoja: mismas columnas, colores e imágenes. Lo que no está en el guion
/// literario va al final.
Future<TechnicalScriptDoc?> buildNarrativeScriptDoc(
  AppDatabase db,
  int projectId,
  TechnicalScriptSettings settings,
) async {
  final project = await db.getProject(projectId);
  if (project == null) return null;

  final scenes = await db.watchScenesForProject(projectId).first;
  final shots = await db.getShotsForProject(projectId);
  final sites = await db.watchSitesForProject(projectId).first;
  final sets = await db.watchLocationsForProject(projectId).first;
  final colors = ProjectColorScheme.resolve(
    sites: sites,
    sets: sets,
    scenes: scenes,
  );
  // El documento es siempre en hoja blanca, se vea como se vea la pantalla.
  final sheet = ScriptSheetTheme.resolve(
    settings.copyWith(view: ScriptView.sheet),
    AppPalette.dark,
  );

  final shotsByScene = <int, List<Shot>>{};
  for (final shot in shots) {
    shotsByScene.putIfAbsent(shot.sceneId, () => []).add(shot);
  }

  final sections = <ScriptDocSection>[];
  for (final scene in scenes) {
    final rows = <ScriptDocRow>[];
    for (final shot in shotsByScene[scene.id] ?? const <Shot>[]) {
      final cellFills = <String, int>{};
      final raw = shot.cellStylesJson;
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            for (final entry in decoded.entries) {
              final fill = sheet.rowFill(entry.value as String?);
              // En el documento la celda de apuntes se llama «notes» y la
              // de referencia «ref», igual que en la hoja.
              if (fill != null) cellFills['${entry.key}'] = _rgb(fill);
            }
          }
        } catch (_) {
          // Un color ilegible no impide exportar.
        }
      }
      final rowFill = sheet.rowFill(shot.notesHighlight);
      rows.add(
        ScriptDocRow(
          cells: {
            'esc': '${scene.number}',
            'plano': '${shot.number}',
            'encuadre': shot.framing ?? '',
            'lens': [
              shot.lens,
              shot.angle,
              shot.movement,
            ].where((v) => v != null && v.trim().isNotEmpty).join('\n'),
            'f': shot.fStop ?? '',
            'pers': decodeSceneCharacters(shot.charactersJson).join(', '),
            'dur': shot.durationSeconds == null
                ? ''
                : '${shot.durationSeconds} s',
            'action': shot.action ?? '',
            'notes': shot.notes ?? '',
          },
          fill: rowFill == null ? null : _rgb(rowFill),
          cellFills: cellFills,
          image: await PdfSafeImage.loadFromPathMaxEdge(
            referenceImageOf(shot),
            maxEdge: 1200,
          ),
        ),
      );
    }
    sections.add(
      ScriptDocSection(
        title:
            '${scene.number}. ${scene.locationCanonical}'
            '${scene.offScript ? ' (fuera del guion)' : ''}',
        headerFill: _rgb(sheet.headerFill(colors.sceneColor(scene))),
        rows: rows,
      ),
    );
  }

  return TechnicalScriptDoc(
    title: 'GUION TÉCNICO ${project.name.toUpperCase()}',
    subtitle: project.director == null || project.director!.trim().isEmpty
        ? null
        : 'Dirección: ${project.director}',
    columns: scriptDocColumns(
      hidden: {
        if (!settings.shows(ScriptColumn.fStop)) 'f',
        if (!settings.shows(ScriptColumn.personajes)) 'pers',
        if (!settings.shows(ScriptColumn.duracion)) 'dur',
      },
    ),
    sections: sections,
  );
}

/// Nombre de archivo del guion técnico de un proyecto, sin extensión.
String technicalScriptFileName(String projectName) {
  final clean = projectName.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
  return clean.isEmpty ? 'guion_tecnico' : '${clean}_guion_tecnico';
}
