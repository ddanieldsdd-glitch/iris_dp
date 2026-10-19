import '../../../core/utils/image_fingerprint.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:xml/xml.dart';

import '../../../core/utils/shot_technical_options.dart';

/// Imagen incrustada en una casilla del documento. La [hash] reconoce la misma
/// imagen repetida (la planta de una escena suele ir en todos sus planos).
class ImportedImage {
  final Uint8List bytes;
  final String fileName;
  final String hash;

  /// Huella visual ([visualFingerprint]): reconoce la misma imagen aunque el
  /// Word la traiga recomprimida o a otro tamaño.
  final String? visual;

  const ImportedImage({
    required this.bytes,
    required this.fileName,
    required this.hash,
    this.visual,
  });
}

class ImportedShot {
  final int number;
  final String? framing;
  final String? lens;
  final String? angle;
  final String? movement;
  final String? fStop;
  final List<String> characters;
  final String? action;
  final String? notes;
  final List<ImportedImage> references;
  final List<ImportedImage> plans;

  const ImportedShot({
    required this.number,
    this.framing,
    this.lens,
    this.angle,
    this.movement,
    this.fStop,
    this.characters = const [],
    this.action,
    this.notes,
    this.references = const [],
    this.plans = const [],
  });
}

class ImportedScene {
  final int number;

  /// Letra tras el número: «13A» → `A`. Nula si no tiene.
  final String? suffix;
  final String intExt;
  final String location;
  final String dayNight;
  final List<ImportedShot> shots;

  const ImportedScene({
    required this.number,
    this.suffix,
    required this.intExt,
    required this.location,
    required this.dayNight,
    required this.shots,
  });

  String get label => '$number${suffix ?? ''}';

  /// Personajes de todos los planos, sin repetir, en orden de aparición.
  List<String> get characters => [
    for (final name in {for (final shot in shots) ...shot.characters}) name,
  ];
}

class ImportedTechnicalScript {
  final String? title;
  final List<ImportedScene> scenes;

  const ImportedTechnicalScript({this.title, required this.scenes});

  int get shotCount => scenes.fold(0, (sum, s) => sum + s.shots.length);
}

/// Lee un guion técnico en Word: una tabla por escena (ESC · PLANO · Encuadre ·
/// LENTE/ANG/MOV · F · PERS. · ACCIÓN · REFERENCIA · PLANTA · APUNTES), con la
/// cabecera de la escena («13A. INT. KEBAB - NOCHE») en el párrafo de encima.
/// Las columnas se reconocen por su título, no por su posición.
abstract final class DocxTechnicalScriptReader {
  static ImportedTechnicalScript read(Uint8List bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const FormatException('El archivo no es un documento de Word.');
    }
    final documentXml = _text(archive, 'word/document.xml');
    if (documentXml == null) {
      throw const FormatException('Archivo Word inválido: falta document.xml');
    }
    final rels = _relationships(_text(archive, 'word/_rels/document.xml.rels'));
    final images = <String, ImportedImage?>{};
    ImportedImage? image(String relId) => images.putIfAbsent(relId, () {
      final target = rels[relId];
      if (target == null) return null;
      final path = target.startsWith('/')
          ? target.substring(1)
          : 'word/${target.replaceFirst(RegExp(r'^\./'), '')}';
      final file = archive.findFile(path);
      if (file == null) return null;
      final data = Uint8List.fromList(file.content as List<int>);
      return ImportedImage(
        bytes: data,
        fileName: path.split('/').last,
        hash: sha1.convert(data).toString(),
        visual: visualFingerprint(data),
      );
    });

    final body = XmlDocument.parse(
      documentXml,
    ).findAllElements('w:body').firstOrNull;
    if (body == null) {
      throw const FormatException('Archivo Word inválido: sin cuerpo');
    }

    String? title;
    String? pendingHeading;
    final scenes = <ImportedScene>[];
    var sawTable = false;

    void visit(XmlElement element) {
      switch (element.name.qualified) {
        case 'w:p':
          final text = _paragraphText(element).trim();
          if (text.isEmpty) return;
          if (parseSceneHeading(text) != null) {
            pendingHeading = text;
          } else if (scenes.isEmpty && pendingHeading == null) {
            title ??= text;
          }
        case 'w:tbl':
          final scene = _readTable(element, pendingHeading, image);
          if (scene != null) {
            sawTable = true;
            scenes.add(scene);
          }
          pendingHeading = null;
        default:
          element.childElements.forEach(visit);
      }
    }

    body.childElements.forEach(visit);

    if (!sawTable) {
      throw const FormatException(
        'No parece un guion técnico: no hay tablas con columnas PLANO y '
        'ENCUADRE o ACCIÓN.',
      );
    }
    return ImportedTechnicalScript(title: title, scenes: scenes);
  }

  static ImportedScene? _readTable(
    XmlElement table,
    String? heading,
    ImportedImage? Function(String relId) image,
  ) {
    final rows = table.findElements('w:tr').toList();
    if (rows.isEmpty) return null;
    final header = [for (final c in _cells(rows.first)) _columnOf(c)];
    final shotCol = header.indexOf(_Column.shot);
    if (shotCol < 0 ||
        !(header.contains(_Column.framing) ||
            header.contains(_Column.action))) {
      return null;
    }

    final parsedHeading = heading == null ? null : parseSceneHeading(heading);
    String? sceneCell;
    final shots = <ImportedShot>[];
    for (final row in rows.skip(1)) {
      final cells = _cells(row);
      String? text(_Column column) {
        final i = header.indexOf(column);
        if (i < 0 || i >= cells.length) return null;
        final value = _cellText(cells[i]);
        return value.isEmpty ? null : value;
      }

      List<ImportedImage> images(_Column column) {
        final i = header.indexOf(column);
        if (i < 0 || i >= cells.length) return const [];
        final seen = <String>{};
        return [
          for (final relId in _imageRelIds(cells[i]))
            if (image(relId) case final img? when seen.add(img.hash)) img,
        ];
      }

      final number = _leadingInt(text(_Column.shot));
      final references = images(_Column.reference);
      final plans = images(_Column.plan);
      if (number == null) {
        // Fila vacía o de notas: solo cuenta si trae algo.
        if (text(_Column.framing) == null &&
            text(_Column.action) == null &&
            references.isEmpty) {
          continue;
        }
      }
      sceneCell ??= text(_Column.scene);
      final lensLine = parseLensLine(text(_Column.lens));
      shots.add(
        ImportedShot(
          number: number ?? shots.length + 1,
          framing: text(_Column.framing),
          lens: lensLine.lens,
          angle: lensLine.angle,
          movement: lensLine.movement,
          fStop: text(_Column.fStop),
          characters: splitCharacters(text(_Column.characters)),
          action: text(_Column.action),
          notes: text(_Column.notes),
          references: references,
          plans: plans,
        ),
      );
    }

    final fromCell = _parseSceneLabel(sceneCell);
    final number = parsedHeading?.number ?? fromCell?.$1;
    if (number == null) return null;
    return ImportedScene(
      number: number,
      suffix: parsedHeading?.suffix ?? fromCell?.$2,
      intExt: parsedHeading?.intExt ?? 'INT',
      location: parsedHeading?.location ?? '',
      dayNight: parsedHeading?.dayNight ?? '',
      shots: shots,
    );
  }

  // ── Celdas ───────────────────────────────────

  static List<XmlElement> _cells(XmlElement row) =>
      row.findElements('w:tc').toList();

  static String _cellText(XmlElement cell) =>
      cleanCellText(cell.findElements('w:p').map(_paragraphText).join('\n'));

  static String _paragraphText(XmlElement paragraph) {
    final buffer = StringBuffer();
    for (final node in paragraph.descendantElements) {
      switch (node.name.qualified) {
        case 'w:t':
          buffer.write(node.innerText);
        case 'w:tab':
          buffer.write(' ');
        case 'w:br' || 'w:cr':
          buffer.write('\n');
      }
    }
    return buffer.toString();
  }

  static Iterable<String> _imageRelIds(XmlElement cell) sync* {
    for (final node in cell.descendantElements) {
      final local = node.name.local;
      if (local == 'blip' || local == 'imagedata') {
        for (final attr in node.attributes) {
          if (attr.name.prefix == 'r' &&
              (attr.name.local == 'embed' || attr.name.local == 'id')) {
            yield attr.value;
          }
        }
      }
    }
  }

  static _Column? _columnOf(XmlElement cell) {
    final t = _fold(_cellText(cell));
    if (t.isEmpty) return null;
    if (t == 'esc' || t.startsWith('escena')) return _Column.scene;
    if (t.startsWith('plano') && !t.contains('planta')) return _Column.shot;
    if (t.startsWith('encuadre') || t == 'tipo de plano') {
      return _Column.framing;
    }
    if (t.startsWith('lente') || t.startsWith('optica')) return _Column.lens;
    if (t == 'f' || t == 'diafragma' || t.startsWith('f/')) {
      return _Column.fStop;
    }
    if (t.startsWith('pers')) return _Column.characters;
    if (t.startsWith('accion')) return _Column.action;
    if (t.startsWith('ref')) return _Column.reference;
    if (t.startsWith('planta')) return _Column.plan;
    if (t.startsWith('apuntes') || t.startsWith('notas')) return _Column.notes;
    return null;
  }

  // ── Archivo ──────────────────────────────────

  static String? _text(Archive archive, String name) {
    final file = archive.findFile(name);
    if (file == null) return null;
    return utf8.decode(file.content as List<int>, allowMalformed: true);
  }

  static Map<String, String> _relationships(String? xml) {
    if (xml == null) return const {};
    return {
      for (final rel in XmlDocument.parse(xml).findAllElements('Relationship'))
        if (rel.getAttribute('Id') case final id?)
          if (rel.getAttribute('Target') case final target?) id: target,
    };
  }
}

enum _Column {
  scene,
  shot,
  framing,
  lens,
  fStop,
  characters,
  action,
  reference,
  plan,
  notes,
}

/// Cabecera de escena leída del documento.
class SceneHeading {
  final int number;
  final String? suffix;
  final String intExt;
  final String location;
  final String dayNight;

  const SceneHeading({
    required this.number,
    this.suffix,
    required this.intExt,
    required this.location,
    required this.dayNight,
  });
}

final _headingPattern = RegExp(
  r'^(\d+)\s*([A-Za-z])?\s*[.)\-–]?\s*'
  r'(INT\.?\s*/\s*EXT|EXT\.?\s*/\s*INT|I/E|INT|EXT)\.?\s+'
  r'(.+?)\s*[-–—]\s*([^-–—]+?)\s*$',
  caseSensitive: false,
);

/// «13A. INT. KEBAB KHALED - NOCHE» → 13, A, INT, KEBAB KHALED, NOCHE.
SceneHeading? parseSceneHeading(String line) {
  final m = _headingPattern.firstMatch(line.trim());
  if (m == null) return null;
  final intExt = m.group(3)!.toUpperCase().replaceAll(RegExp(r'[\s.]'), '');
  return SceneHeading(
    number: int.parse(m.group(1)!),
    suffix: m.group(2)?.toUpperCase(),
    intExt: intExt,
    location: m.group(4)!.trim().replaceAll(RegExp(r'\s+'), ' '),
    dayNight: m.group(5)!.trim().toUpperCase(),
  );
}

(int, String?)? _parseSceneLabel(String? text) {
  final m = RegExp(r'^(\d+)\s*([A-Za-z])?').firstMatch(text?.trim() ?? '');
  if (m == null) return null;
  return (int.parse(m.group(1)!), m.group(2)?.toUpperCase());
}

int? _leadingInt(String? text) {
  final m = RegExp(r'^\s*(\d+)').firstMatch(text ?? '');
  return m == null ? null : int.parse(m.group(1)!);
}

/// «35mm Normal SEGUIMIENTO DORSAL» → lente 35mm, ángulo Normal, movimiento
/// SEGUIMIENTO DORSAL. Lo que no se reconoce queda como movimiento, tal cual.
({String? lens, String? angle, String? movement}) parseLensLine(String? text) {
  if (text == null || text.trim().isEmpty) {
    return (lens: null, angle: null, movement: null);
  }
  var rest = text.replaceAll('\n', ' ').trim();
  String? lens;
  final lensMatch = RegExp(
    r'(\d+(?:[.,]\d+)?)\s*mm\b',
    caseSensitive: false,
  ).firstMatch(rest);
  if (lensMatch != null) {
    lens = '${lensMatch.group(1)!.replaceAll(',', '.')}mm';
    rest = rest.replaceRange(lensMatch.start, lensMatch.end, ' ');
  }
  String? angle;
  for (final candidate in kShotAngles) {
    final m = RegExp(
      '(^|\\s)${RegExp.escape(_fold(candidate))}(\\s|\$)',
    ).firstMatch(_fold(rest));
    if (m != null) {
      angle = candidate;
      final words = rest.split(RegExp(r'\s+'));
      words.removeWhere((w) => _fold(w) == _fold(candidate));
      rest = words.join(' ');
      break;
    }
  }
  final movement = rest.replaceAll(RegExp(r'\s+'), ' ').trim();
  return (
    lens: lens,
    angle: angle,
    movement: movement.isEmpty ? null : _canonicalMovement(movement),
  );
}

String _canonicalMovement(String movement) {
  for (final known in kShotMovements) {
    if (_fold(known) == _fold(movement)) return known;
  }
  return movement.toUpperCase();
}

/// «ALI, DIEGO y CHICA» → [ALI, DIEGO, CHICA].
List<String> splitCharacters(String? text) {
  if (text == null) return const [];
  final seen = <String>{};
  return [
    for (final part in text.split(RegExp(r'[,;/\n]|\s+y\s+|\s+Y\s+')))
      if (part.trim().toUpperCase() case final name
          when name.isNotEmpty && seen.add(name))
        name,
  ];
}

/// Sin espacios duros ni espacios repetidos; conserva los saltos de línea.
String cleanCellText(String text) => text
    .replaceAll(' ', ' ')
    .split('\n')
    .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
    .where((line) => line.isNotEmpty)
    .join('\n');

const _accentFold = {
  'á': 'a',
  'é': 'e',
  'í': 'i',
  'ó': 'o',
  'ú': 'u',
  'ü': 'u',
  'ñ': 'n',
};

/// Minúsculas, sin tildes, sin puntos finales ni espacios de más.
String _fold(String text) {
  final lower = text.toLowerCase().trim();
  final buffer = StringBuffer();
  for (final char in lower.split('')) {
    buffer.write(_accentFold[char] ?? char);
  }
  return buffer
      .toString()
      .replaceAll(RegExp(r'[.:]+$'), '')
      .replaceAll(RegExp(r'\s+'), ' ');
}
