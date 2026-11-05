import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/shot_technical_options.dart';
import 'camera_plan_element_model.dart';
import 'plan_equipment.dart';

/// Qué manda cuando la cámara de la planta y el plano del guion técnico no
/// dicen lo mismo al vincularlos (SG.4).
enum CameraShotSource {
  /// La cámara toma la focal y el movimiento del guion técnico.
  script,

  /// El plano toma la focal y el movimiento de la cámara.
  plan,
}

/// La cámara de la planta y su plano comparten focal y movimiento (SG.4).
///
/// La focal se compara por su número («35mm», «35 MM» y «Mm 35» son la
/// misma). El movimiento se guarda con las palabras del guion técnico
/// («MANO», «TRÍPODE»…); la planta las entiende igual que las suyas.
abstract final class CameraShotSync {
  /// Movimientos que se ofrecen en la planta: los del guion técnico.
  static const movements = kShotMovements;

  /// Focal en milímetros de un texto de lente, o `null`.
  static double? focalOf(String? lens) {
    final m = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(lens ?? '');
    return m == null ? null : double.tryParse(m.group(1)!.replaceAll(',', '.'));
  }

  /// La lente escrita como en el guion técnico: «35mm».
  static String? lensLabel(String? lens) {
    final f = focalOf(lens);
    if (f == null) return null;
    return '${f == f.roundToDouble() ? f.toStringAsFixed(0) : f}mm';
  }

  static String? _movement(String? m) {
    final t = m?.trim().toUpperCase();
    return t == null || t.isEmpty ? null : t;
  }

  /// ¿Es cámara en mano?
  static bool isHandheld(String? movement) => switch (_movement(movement)) {
    'MANO' || 'HANDHELD' || 'MANO AL HOMBRO' || 'EN MANO' => true,
    _ => false,
  };

  static bool _sameLens(String? a, String? b) => focalOf(a) == focalOf(b);
  static bool _sameMovement(String? a, String? b) =>
      _movement(a) == _movement(b);

  /// ¿La cámara y el plano dicen cosas distintas (los dos con dato)?
  static bool conflicts(PlanElement camera, Shot shot) {
    final lens =
        focalOf(camera.lens) != null &&
        focalOf(shot.lens) != null &&
        !_sameLens(camera.lens, shot.lens);
    final move =
        _movement(camera.stabilization) != null &&
        _movement(shot.movement) != null &&
        !_sameMovement(camera.stabilization, shot.movement);
    return lens || move;
  }

  /// La cámara toma lo que el plano tenga escrito. Devuelve si cambió.
  static bool cameraFromShot(PlanElement camera, Shot shot) {
    var changed = false;
    final lens = lensLabel(shot.lens);
    if (lens != null && !_sameLens(camera.lens, lens)) {
      PlanEquipment.setFocal(camera, focalOf(lens)!);
      changed = true;
    }
    final move = _movement(shot.movement);
    if (move != null && !_sameMovement(camera.stabilization, move)) {
      camera.stabilization = move;
      changed = true;
    }
    return changed;
  }

  /// Lo que hay que escribir en el plano para que diga lo de la cámara.
  /// Con [onlyEmpty], solo rellena lo que el plano no tenía. `null` si no
  /// hay nada que cambiar.
  static ShotsCompanion? shotFromCamera(
    PlanElement camera,
    Shot shot, {
    bool onlyEmpty = false,
  }) {
    final lens = lensLabel(camera.lens);
    final move = _movement(camera.stabilization);
    final writeLens =
        lens != null &&
        (onlyEmpty ? focalOf(shot.lens) == null : !_sameLens(shot.lens, lens));
    final writeMove =
        move != null &&
        (onlyEmpty
            ? _movement(shot.movement) == null
            : !_sameMovement(shot.movement, move));
    if (!writeLens && !writeMove) return null;
    return ShotsCompanion(
      lens: writeLens ? Value(lens) : const Value.absent(),
      movement: writeMove ? Value(move) : const Value.absent(),
    );
  }

  /// Junta cámara y plano al vincularlos: según [source] manda el guion o
  /// la planta; lo que falte en uno se toma del otro. Escribe el plano si
  /// cambia y devuelve si cambió la cámara.
  static Future<bool> link(
    AppDatabase db,
    PlanElement camera,
    Shot shot, {
    CameraShotSource source = CameraShotSource.script,
  }) async {
    final changed = source == CameraShotSource.script
        ? cameraFromShot(camera, shot)
        : false;
    final write = shotFromCamera(
      camera,
      shot,
      onlyEmpty: source == CameraShotSource.script,
    );
    if (write != null) await db.updateShotFields(shot.id, write);
    return changed;
  }

  /// La cámara cambió de focal o de movimiento ([before] → [after]): ¿hay
  /// que escribirlo en sus planos?
  static bool gearChanged(PlanElement before, PlanElement after) =>
      !_sameLens(before.lens, after.lens) ||
      !_sameMovement(before.stabilization, after.stabilization);
}
