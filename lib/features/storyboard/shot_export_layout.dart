import 'dart:convert';
import 'dart:io';

import '../../core/database/app_database.dart';

/// Qué papel tiene una imagen en la hoja.
enum ShotImageRole { frame, support, excluded }

extension ShotImageRoleX on ShotImageRole {
  String get label => switch (this) {
    ShotImageRole.frame => 'Encuadre',
    ShotImageRole.support => 'Refuerzo',
    ShotImageRole.excluded => 'Fuera',
  };
}

/// Cómo se cuenta el plano con sus encuadres.
enum ShotLayoutKind {
  /// Un encuadre (y, si acaso, refuerzos).
  single,

  /// Un movimiento (paneo, travelling…): el encuadre antes y el de después.
  move,

  /// Plano secuencia: varias partes en orden.
  sequence,
}

extension ShotLayoutKindX on ShotLayoutKind {
  String get label => switch (this) {
    ShotLayoutKind.single => 'Un encuadre',
    ShotLayoutKind.move => 'Movimiento: antes y después',
    ShotLayoutKind.sequence => 'Secuencia: varias partes',
  };
}

/// Una imagen del plano que puede salir en la hoja: la del storyboard o una
/// de sus referencias (por su uid, el mismo en todos los equipos).
class ShotLayoutImage {
  /// `storyboard` o `ref:<uid>`.
  final String id;
  final String path;

  /// «Storyboard», «Referencia 2».
  final String name;

  const ShotLayoutImage({
    required this.id,
    required this.path,
    required this.name,
  });

  static const storyboardId = 'storyboard';
  static String referenceId(ShotReference ref) => 'ref:${ref.uid ?? ref.id}';
}

/// Lo que se elige antes de exportar y se guarda en el plano.
class ShotExportLayout {
  final ShotLayoutKind kind;

  /// Encuadres, en orden y del mismo tamaño.
  final List<String> frames;

  /// Refuerzos: más pequeños, en segundo plano.
  final List<String> support;

  /// Las que se dejaron fuera a propósito.
  final List<String> excluded;

  const ShotExportLayout({
    this.kind = ShotLayoutKind.single,
    this.frames = const [],
    this.support = const [],
    this.excluded = const [],
  });

  ShotExportLayout copyWith({
    ShotLayoutKind? kind,
    List<String>? frames,
    List<String>? support,
    List<String>? excluded,
  }) => ShotExportLayout(
    kind: kind ?? this.kind,
    frames: frames ?? this.frames,
    support: support ?? this.support,
    excluded: excluded ?? this.excluded,
  );

  /// Pone [id] de encuadre (al final), de refuerzo o fuera.
  ShotExportLayout place(String id, ShotImageRole role) {
    final f = [...frames]..remove(id);
    final s = [...support]..remove(id);
    final x = [...excluded]..remove(id);
    switch (role) {
      case ShotImageRole.frame:
        f.add(id);
      case ShotImageRole.support:
        s.add(id);
      case ShotImageRole.excluded:
        x.add(id);
    }
    return copyWith(frames: f, support: s, excluded: x);
  }

  ShotImageRole roleOf(String id) => frames.contains(id)
      ? ShotImageRole.frame
      : excluded.contains(id)
      ? ShotImageRole.excluded
      : ShotImageRole.support;

  /// Mueve el encuadre [id] un puesto ([delta] −1 o +1).
  ShotExportLayout moveFrame(String id, int delta) {
    final f = [...frames];
    final i = f.indexOf(id);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= f.length) return this;
    f
      ..removeAt(i)
      ..insert(j, id);
    return copyWith(frames: f);
  }

  /// Rótulo del encuadre [index] de [count].
  String frameLabel(int index, int count) => switch (kind) {
    ShotLayoutKind.single => count == 1 ? '' : 'Encuadre ${index + 1}',
    ShotLayoutKind.move =>
      index == 0
          ? 'Antes del movimiento'
          : index == count - 1
          ? 'Después del movimiento'
          : 'Durante el movimiento',
    ShotLayoutKind.sequence => 'Parte ${index + 1}',
  };

  String encode() => jsonEncode({
    'kind': kind.name,
    'frames': frames,
    'support': support,
    'excluded': excluded,
  });

  static ShotExportLayout? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      List<String> ids(Object? v) => [
        for (final e in v is List ? v : const [])
          if (e is String) e,
      ];
      return ShotExportLayout(
        kind:
            ShotLayoutKind.values
                .where((k) => k.name == json['kind'])
                .firstOrNull ??
            ShotLayoutKind.single,
        frames: ids(json['frames']),
        support: ids(json['support']),
        excluded: ids(json['excluded']),
      );
    } catch (_) {
      return null;
    }
  }

  /// Lo que propone la app si no se ha elegido: el tipo según el
  /// movimiento del guion técnico; el storyboard (o la principal) de
  /// encuadre y lo demás de refuerzo. En un movimiento o una secuencia, las
  /// dos primeras imágenes son encuadres.
  static ShotExportLayout suggested(Shot shot, List<ShotLayoutImage> images) {
    final kind = kindFromMovement(shot.movement);
    final ids = [for (final i in images) i.id];
    final main = ids.contains(ShotLayoutImage.storyboardId)
        ? ShotLayoutImage.storyboardId
        : _mainReferenceId(shot, images) ?? ids.firstOrNull;
    final ordered = [?main, ...ids.where((id) => id != main)];
    final frameCount = kind == ShotLayoutKind.single ? 1 : 2;
    return ShotExportLayout(
      kind: kind,
      frames: ordered.take(frameCount).toList(),
      support: ordered.skip(frameCount).toList(),
    );
  }

  static String? _mainReferenceId(Shot shot, List<ShotLayoutImage> images) {
    final main = shot.referenceImagePath;
    if (main == null) return null;
    return images.where((i) => i.path == main).firstOrNull?.id;
  }

  /// Paneo, travelling, grúa… → movimiento; plano secuencia → secuencia.
  static ShotLayoutKind kindFromMovement(String? movement) {
    final text = (movement ?? '').toLowerCase();
    if (text.contains('secuencia') || text.contains('steadicam')) {
      return ShotLayoutKind.sequence;
    }
    const moves = [
      'pan',
      'tilt',
      'travel',
      'dolly',
      'grúa',
      'grua',
      'track',
      'zoom',
      'barrido',
      'movimiento',
      'seguimiento',
      'push',
      'pull',
      'arc',
    ];
    return moves.any(text.contains)
        ? ShotLayoutKind.move
        : ShotLayoutKind.single;
  }

  /// Quita lo que ya no existe y deja fuera lo que no se eligió (una
  /// imagen nueva no sale sola: entra como refuerzo si el plano ya tenía
  /// una elección guardada, para no perderla).
  ShotExportLayout reconciled(List<ShotLayoutImage> images) {
    final have = {for (final i in images) i.id};
    final framesNow = frames.where(have.contains).toList();
    final supportNow = support
        .where((id) => have.contains(id) && !framesNow.contains(id))
        .toList();
    final placed = {...framesNow, ...supportNow, ...excluded};
    return ShotExportLayout(
      kind: kind,
      frames: framesNow,
      support: [
        ...supportNow,
        for (final id in have)
          if (!placed.contains(id)) id,
      ],
      excluded: excluded.where(have.contains).toList(),
    );
  }
}

/// Las imágenes del plano que pueden salir: el storyboard y sus
/// referencias, las que existen en este equipo.
List<ShotLayoutImage> shotLayoutImages(Shot shot, List<ShotReference> refs) {
  bool exists(String? path) => path != null && File(path).existsSync();
  final out = <ShotLayoutImage>[];
  final story = shot.storyboardImagePath;
  if (exists(story)) {
    out.add(
      ShotLayoutImage(
        id: ShotLayoutImage.storyboardId,
        path: story!,
        name: 'Storyboard',
      ),
    );
  }
  var n = 0;
  for (final ref in refs) {
    if (!exists(ref.imagePath) || ref.imagePath == story) continue;
    n++;
    out.add(
      ShotLayoutImage(
        id: ShotLayoutImage.referenceId(ref),
        path: ref.imagePath,
        name: 'Referencia $n',
      ),
    );
  }
  return out;
}
