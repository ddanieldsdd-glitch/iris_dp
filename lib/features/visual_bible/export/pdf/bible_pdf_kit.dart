import 'dart:convert';

import '../../../../shared/visual_bible/lighting_metrics.dart';
import '../../../../shared/visual_bible/bible_equipment.dart';
import '../../../../shared/visual_bible/bible_table.dart';
import '../../../../shared/visual_bible/bible_text_specs.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../shared/visual_bible/bible_acts.dart';
import '../../../../shared/visual_bible/bible_cards.dart';
import '../../../../shared/visual_bible/bible_palette.dart';
import '../../../../shared/visual_bible/bible_point_extras.dart';
import '../../../../shared/visual_bible/bible_section_fields.dart';
import '../bible_section_export_reader.dart';

/// Tokens visuales del PDF de la biblia. Claro e imprimible.
abstract final class BiblePdfTokens {
  static const ink = PdfColor.fromInt(0xFF111113);
  static const secondary = PdfColor.fromInt(0xFF4A4F59);
  static const tertiary = PdfColor.fromInt(0xFF8A919E);
  static const rule = PdfColor.fromInt(0xFFE3E5EA);
  static const panel = PdfColor.fromInt(0xFFF5F6F8);
  static const accent = PdfColor.fromInt(0xFF0A84FF);

  static const double pageMargin = 40;
  static const double gap = 14;
  static const double radius = 6;
}

/// Componentes del PDF de la biblia: uno por tipo de punto.
///
/// Es el equivalente en PDF de `BiblePointPanel` y `BibleGenericPointView`.
class BiblePdfKit {
  final pw.Font regular;
  final pw.Font bold;

  /// Imágenes del moodboard ya cargadas, por id, para los puntos que las
  /// llevan (actos, paletas, tiras de imágenes).
  final Map<int, pw.ImageProvider> images;

  /// Los actos del proyecto, para los puntos «División por actos» que los
  /// comparten.
  final List<BibleCard> sharedActs;

  const BiblePdfKit({
    required this.regular,
    required this.bold,
    this.images = const {},
    this.sharedActs = const [],
  });

  List<pw.ImageProvider> _loaded(Iterable<int> ids) => [
    for (final id in ids)
      if (images[id] != null) images[id]!,
  ];

  /// División por actos: una columna por acto, con su imagen encima.
  pw.Widget actsPoint(String label, List<BibleCard> acts) {
    const perRow = 3;
    final numbers = BibleCard.actNumbers(acts);
    final rows = <List<int>>[];
    for (var i = 0; i < acts.length; i += perRow) {
      rows.add([for (var j = i; j < acts.length && j < i + perRow; j++) j]);
    }
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: BiblePdfTokens.gap),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          this.label(label),
          pw.SizedBox(height: 6),
          for (final row in rows)
            pw.Inseparable(
              child: pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < perRow; i++)
                      pw.Expanded(
                        child: i >= row.length
                            ? pw.SizedBox()
                            : pw.Padding(
                                padding: pw.EdgeInsets.only(
                                  right: i == perRow - 1 ? 0 : 10,
                                ),
                                child: _act(numbers[row[i]], acts[row[i]]),
                              ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// [number] es `null` en un punto de giro.
  pw.Widget _act(int? number, BibleCard act) {
    final image = _loaded(act.imageIds).firstOrNull;
    final phase = act.kicker.trim();
    final name = number == null ? 'Punto de giro' : 'Acto $number';
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (image != null) ...[
          pw.ClipRRect(
            horizontalRadius: BiblePdfTokens.radius,
            verticalRadius: BiblePdfTokens.radius,
            child: pw.AspectRatio(
              aspectRatio: 16 / 9,
              child: pw.Image(image, fit: pw.BoxFit.cover),
            ),
          ),
          pw.SizedBox(height: 5),
        ],
        pw.Container(height: 1.5, color: BiblePdfTokens.accent),
        pw.SizedBox(height: 4),
        pw.Text(
          (phase.isEmpty ? name : '$name · $phase').toUpperCase(),
          style: pw.TextStyle(
            font: bold,
            fontSize: 7,
            letterSpacing: 0.6,
            color: BiblePdfTokens.accent,
          ),
        ),
        pw.SizedBox(height: 2),
        _titled(act.title, act.body),
        // Lo que la ficha del acto desarrolla: sus puntos y el resto de
        // sus imágenes.
        for (final point in act.points)
          if (!point.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 5),
              child: _pointBlock(point),
            ),
        ..._moreImages(act),
      ],
    );
  }

  /// Un bloque de una ficha: su texto y, debajo, las imágenes que lo
  /// explican.
  pw.Widget _pointBlock(BibleCard point) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _titled(point.title.trim(), point.body.trim()),
      ..._moreImages(point, skip: 0),
    ],
  );

  /// Imágenes de una ficha que no son la portada, en pequeño.
  List<pw.Widget> _moreImages(BibleCard card, {int skip = 1}) {
    final rest = _loaded(card.imageIds).skip(skip).toList();
    if (rest.isEmpty) return const [];
    return [
      pw.SizedBox(height: 5),
      pw.Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final image in rest)
            pw.ClipRRect(
              horizontalRadius: 3,
              verticalRadius: 3,
              child: pw.Image(image, height: 38, fit: pw.BoxFit.cover),
            ),
        ],
      ),
    ];
  }

  /// Tarjetas con título y desarrollo: una debajo de otra o, con [columns],
  /// como pilares. Cada una lleva sus imágenes.
  pw.Widget cardsPoint(
    String label,
    List<BibleCard> cards, {
    bool columns = false,
  }) {
    if (!columns) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: BiblePdfTokens.gap),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            this.label(label),
            pw.SizedBox(height: 4),
            for (final card in cards)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _titled(card.title.trim(), card.body.trim()),
                    ..._moreImages(card, skip: 0),
                    // Lo que cuenta cada imagen (láminas del mosaico).
                    for (final (i, id) in card.imageIds.indexed)
                      if (card.imageNotes[id] case final note?
                          when !note.isEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 4),
                          child: _titled(
                            'Lámina ${i + 1}'
                            '${note.title.trim().isEmpty ? '' : ' · ${note.title.trim()}'}',
                            note.text.trim(),
                          ),
                        ),
                    for (final point in card.points)
                      if (!point.isEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 5),
                          child: _pointBlock(point),
                        ),
                  ],
                ),
              ),
          ],
        ),
      );
    }
    const perRow = 4;
    return pw.Inseparable(
      child: pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: BiblePdfTokens.gap),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            this.label(label),
            pw.SizedBox(height: 6),
            for (var i = 0; i < cards.length; i += perRow)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    for (var c = 0; c < perRow; c++)
                      pw.Expanded(
                        child: i + c >= cards.length
                            ? pw.SizedBox()
                            : pw.Padding(
                                padding: pw.EdgeInsets.only(
                                  right: c == perRow - 1 ? 0 : 10,
                                ),
                                child: _pillar(cards[i + c]),
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

  pw.Widget _pillar(BibleCard card) {
    final cover = _loaded(card.imageIds).firstOrNull;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (cover != null) ...[
          pw.ClipRRect(
            horizontalRadius: BiblePdfTokens.radius,
            verticalRadius: BiblePdfTokens.radius,
            child: pw.AspectRatio(
              aspectRatio: 16 / 9,
              child: pw.Image(cover, fit: pw.BoxFit.cover),
            ),
          ),
          pw.SizedBox(height: 5),
        ],
        pw.Container(
          padding: const pw.EdgeInsets.only(left: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              left: pw.BorderSide(color: BiblePdfTokens.rule, width: 1.5),
            ),
          ),
          child: _titled(card.title.trim(), card.body.trim()),
        ),
        ..._moreImages(card),
      ],
    );
  }

  /// Complementos de un punto: sus imágenes y su texto. Mientras no se hayan
  /// guardado, las imágenes son [legacy] (las que el punto tenía antes).
  List<pw.Widget> extras(
    Map<String, String> values,
    String pointKey, {
    List<pw.ImageProvider> legacy = const [],
    String? label,
  }) {
    final extras = BiblePointExtras.read(values, pointKey);
    final images = values.containsKey(BiblePointExtras.keyFor(pointKey))
        ? _loaded(extras.imageIds)
        : legacy;
    final text = (extras.text ?? '').trim();
    if (images.isEmpty && text.isEmpty) return const [];
    return [
      if (label != null) ...[this.label(label), pw.SizedBox(height: 6)],
      if (images.isNotEmpty) imageStrip(images),
      if (text.isNotEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: BiblePdfTokens.gap),
          child: pw.Text(
            text,
            style: pw.TextStyle(
              font: regular,
              fontSize: 10,
              lineSpacing: 3,
              color: BiblePdfTokens.secondary,
            ),
          ),
        ),
    ];
  }

  /// Los actos de un punto tal como se ven en pantalla. Un acto del proyecto
  /// del que esta pantalla no dice nada (ni texto ni imagen) no sale.
  pw.Widget? actsPointOf(String label, BibleActsValue value) {
    final acts = [
      for (final act in value.resolve(sharedActs))
        if (value.shared
            ? act.body.trim().isNotEmpty || _loaded(act.imageIds).isNotEmpty
            : !act.isEmpty)
          act,
    ];
    return acts.isEmpty ? null : actsPoint(label, acts);
  }

  /// Punto de paleta: lo que esté marcado para mostrarse, en el orden de la
  /// pantalla (imágenes, paleta, texto).
  pw.Widget? _palettePoint(BibleSectionField field, String raw) {
    final value = BiblePaletteValue.decode(raw);
    final shots = value.shows(BiblePalettePart.images)
        ? _loaded(value.imageIds)
        : const <pw.ImageProvider>[];
    final colors = value.shows(BiblePalettePart.palette)
        ? value.colors
        : const <BiblePaletteColor>[];
    final text = value.shows(BiblePalettePart.text) ? value.text.trim() : '';
    if (shots.isEmpty && colors.isEmpty && text.isEmpty) return null;

    // Una simbología lleva el significado de cada color.
    final symbolism =
        field.widget == 'palette_symbolism' ||
        colors.any((c) => c.note.trim().isNotEmpty);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (shots.isNotEmpty) ...[
          label(field.label),
          pw.SizedBox(height: 6),
          imageStrip(shots, height: 96),
        ],
        if (colors.isNotEmpty)
          symbolism
              ? swatchList(shots.isEmpty ? field.label : 'Colores', [
                  for (final c in colors)
                    (
                      hex: c.hex,
                      title: c.name.isEmpty ? c.hex : c.name,
                      text: c.note,
                    ),
                ])
              : swatchRow(shots.isEmpty ? field.label : 'Paleta', [
                  for (final c in colors) (c.hex, c.name),
                ]),
        if (text.isNotEmpty)
          shots.isEmpty && colors.isEmpty
              ? textPoint(field.label, text)
              : pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: BiblePdfTokens.gap),
                  child: pw.Text(text, style: body),
                ),
      ],
    );
  }

  pw.TextStyle get body => pw.TextStyle(
    font: regular,
    fontSize: 11,
    lineSpacing: 4,
    color: BiblePdfTokens.ink,
  );

  /// Cabecera de una sección. Con [image] (la que el usuario eligió para la
  /// pantalla), el título va en grande sobre una banda con ella. [accent]
  /// es el color de la pantalla, si lo tiene.
  pw.Widget sectionHeader(
    String title, {
    pw.ImageProvider? image,
    PdfColor? accent,
  }) {
    if (image != null) {
      return pw.ClipRRect(
        horizontalRadius: BiblePdfTokens.radius,
        verticalRadius: BiblePdfTokens.radius,
        child: pw.SizedBox(
          height: 118,
          width: double.infinity,
          child: pw.Stack(
            children: [
              pw.Positioned.fill(child: pw.Image(image, fit: pw.BoxFit.cover)),
              pw.Positioned.fill(
                child: pw.Container(
                  decoration: const pw.BoxDecoration(
                    gradient: pw.LinearGradient(
                      begin: pw.Alignment.topCenter,
                      end: pw.Alignment.bottomCenter,
                      colors: [PdfColor(0, 0, 0, 0.1), PdfColor(0, 0, 0, 0.8)],
                    ),
                  ),
                ),
              ),
              if (accent != null)
                pw.Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: pw.Container(height: 3, color: accent),
                ),
              pw.Positioned(
                left: 14,
                right: 14,
                bottom: 12,
                child: pw.Text(
                  title,
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: 24,
                    color: PdfColors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          height: 3,
          width: 32,
          color: accent ?? BiblePdfTokens.accent,
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          title.toUpperCase(),
          style: pw.TextStyle(
            font: bold,
            fontSize: 11,
            letterSpacing: 3,
            color: BiblePdfTokens.tertiary,
          ),
        ),
      ],
    );
  }

  pw.Widget label(String text) => pw.Text(
    text.toUpperCase(),
    style: pw.TextStyle(
      font: bold,
      fontSize: 8,
      letterSpacing: 1,
      color: BiblePdfTokens.tertiary,
    ),
  );

  pw.Widget chip(String label, String value) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: pw.BoxDecoration(
      color: BiblePdfTokens.panel,
      borderRadius: pw.BorderRadius.circular(BiblePdfTokens.radius),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label.toUpperCase(),
          style: pw.TextStyle(
            font: regular,
            fontSize: 7,
            color: BiblePdfTokens.tertiary,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            font: bold,
            fontSize: 11,
            color: BiblePdfTokens.ink,
          ),
        ),
      ],
    ),
  );

  /// Punto de texto: rótulo y párrafo.
  pw.Widget textPoint(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: BiblePdfTokens.gap),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        this.label(label),
        pw.SizedBox(height: 4),
        pw.Text(value, style: body),
      ],
    ),
  );

  /// Punto de lista: rótulo y viñetas.
  pw.Widget listPoint(String label, List<String> items) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: BiblePdfTokens.gap),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        this.label(label),
        pw.SizedBox(height: 4),
        for (final item in items)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 3,
                  height: 3,
                  margin: const pw.EdgeInsets.only(top: 5, right: 7),
                  decoration: const pw.BoxDecoration(
                    color: BiblePdfTokens.accent,
                    shape: pw.BoxShape.circle,
                  ),
                ),
                pw.Expanded(child: pw.Text(item, style: body)),
              ],
            ),
          ),
      ],
    ),
  );

  /// Punto de datos técnicos: rótulo y tabla etiqueta/valor.
  pw.Widget specsPoint(String label, List<(String, String)> rows) =>
      pw.Inseparable(
        child: pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: BiblePdfTokens.gap),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              this.label(label),
              pw.SizedBox(height: 4),
              for (final (name, value) in rows)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(
                        color: BiblePdfTokens.rule,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          name.toUpperCase(),
                          style: pw.TextStyle(
                            font: regular,
                            fontSize: 8,
                            letterSpacing: 0.6,
                            color: BiblePdfTokens.secondary,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 3,
                        child: pw.Text(
                          value,
                          style: pw.TextStyle(
                            font: bold,
                            fontSize: 10,
                            color: BiblePdfTokens.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );

  /// Punto con entradas de título y texto (tono, transiciones).
  pw.Widget titledList(String label, List<(String, String)> entries) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: BiblePdfTokens.gap),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            this.label(label),
            pw.SizedBox(height: 4),
            for (final (title, text) in entries)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: _titled(title, text),
              ),
          ],
        ),
      );

  /// Punto en columnas (pilares de estrategia, actos). Cada entrada lleva
  /// una antetítulo opcional, un título y un texto.
  pw.Widget columnsPoint(
    String label,
    List<({String? kicker, String title, String text})> entries, {
    int perRow = 3,
  }) {
    final rows = <List<({String? kicker, String title, String text})>>[];
    for (var i = 0; i < entries.length; i += perRow) {
      rows.add(entries.skip(i).take(perRow).toList());
    }
    // Rótulo y columnas van juntos: no se separan entre páginas.
    return pw.Inseparable(
      child: pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: BiblePdfTokens.gap),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            this.label(label),
            pw.SizedBox(height: 6),
            for (final row in rows)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < perRow; i++)
                      pw.Expanded(
                        child: i >= row.length
                            ? pw.SizedBox()
                            : pw.Container(
                                margin: pw.EdgeInsets.only(
                                  right: i == perRow - 1 ? 0 : 10,
                                ),
                                padding: const pw.EdgeInsets.only(left: 8),
                                decoration: const pw.BoxDecoration(
                                  border: pw.Border(
                                    left: pw.BorderSide(
                                      color: BiblePdfTokens.rule,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                child: pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: [
                                    if (row[i].kicker?.isNotEmpty == true) ...[
                                      pw.Text(
                                        row[i].kicker!.toUpperCase(),
                                        style: pw.TextStyle(
                                          font: regular,
                                          fontSize: 7,
                                          letterSpacing: 0.6,
                                          color: BiblePdfTokens.accent,
                                        ),
                                      ),
                                      pw.SizedBox(height: 2),
                                    ],
                                    _titled(row[i].title, row[i].text),
                                  ],
                                ),
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

  pw.Widget _titled(String title, String text) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      if (title.isNotEmpty)
        pw.Text(
          title,
          style: pw.TextStyle(
            font: bold,
            fontSize: 11,
            color: BiblePdfTokens.ink,
          ),
        ),
      if (text.isNotEmpty)
        pw.Text(
          text,
          style: pw.TextStyle(
            font: regular,
            fontSize: 10,
            lineSpacing: 3,
            color: BiblePdfTokens.secondary,
          ),
        ),
    ],
  );

  /// Ficha de referencia: imagen opcional, antetítulo, título y apartados
  /// con rótulo. Los apartados vacíos no se pintan.
  pw.Widget referencePoint({
    required String kicker,
    required String title,
    required List<(String, String)> sections,
    pw.ImageProvider? image,
  }) {
    final text = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (kicker.isNotEmpty) ...[
          pw.Text(
            kicker.toUpperCase(),
            style: pw.TextStyle(
              font: regular,
              fontSize: 7,
              letterSpacing: 0.6,
              color: BiblePdfTokens.accent,
            ),
          ),
          pw.SizedBox(height: 2),
        ],
        if (title.isNotEmpty)
          pw.Text(
            title,
            style: pw.TextStyle(
              font: bold,
              fontSize: 12,
              color: BiblePdfTokens.ink,
            ),
          ),
        for (final (heading, body) in sections)
          if (body.trim().isNotEmpty) ...[
            pw.SizedBox(height: 6),
            label(heading),
            pw.SizedBox(height: 2),
            pw.Text(
              body.trim(),
              style: pw.TextStyle(
                font: regular,
                fontSize: 10,
                lineSpacing: 3,
                color: BiblePdfTokens.secondary,
              ),
            ),
          ],
      ],
    );
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: BiblePdfTokens.gap),
      padding: const pw.EdgeInsets.only(left: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(color: BiblePdfTokens.rule, width: 1.5),
        ),
      ),
      child: image == null
          ? text
          : pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.ClipRRect(
                  horizontalRadius: BiblePdfTokens.radius,
                  verticalRadius: BiblePdfTokens.radius,
                  child: pw.Image(image, width: 190, fit: pw.BoxFit.contain),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(child: text),
              ],
            ),
    );
  }

  /// Tira de imágenes que acompañan a un punto.
  pw.Widget imageStrip(List<pw.ImageProvider> images, {double height = 78}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: BiblePdfTokens.gap),
        child: pw.Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final image in images)
              pw.ClipRRect(
                horizontalRadius: BiblePdfTokens.radius,
                verticalRadius: BiblePdfTokens.radius,
                child: pw.Image(image, height: height, fit: pw.BoxFit.cover),
              ),
          ],
        ),
      );

  /// Muestras de color con su código y nombre (paleta).
  pw.Widget swatchRow(String label, List<(String hex, String name)> colors) =>
      pw.Inseparable(
        child: pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: BiblePdfTokens.gap),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              this.label(label),
              pw.SizedBox(height: 6),
              pw.Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (hex, name) in colors)
                    pw.SizedBox(
                      width: 62,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _swatch(hex, 62),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            hex.toUpperCase(),
                            style: pw.TextStyle(
                              font: regular,
                              fontSize: 6.5,
                              color: BiblePdfTokens.secondary,
                            ),
                          ),
                          if (name.isNotEmpty)
                            pw.Text(
                              name.toUpperCase(),
                              style: pw.TextStyle(
                                font: bold,
                                fontSize: 6,
                                letterSpacing: 0.4,
                                color: BiblePdfTokens.tertiary,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );

  /// Entradas con muestra de color, título y texto (simbología).
  pw.Widget swatchList(
    String label,
    List<({String hex, String title, String text})> entries,
  ) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: BiblePdfTokens.gap),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        this.label(label),
        pw.SizedBox(height: 4),
        for (final entry in entries)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 2, right: 8),
                  child: _swatch(entry.hex, 12),
                ),
                pw.Expanded(child: _titled(entry.title, entry.text)),
              ],
            ),
          ),
      ],
    ),
  );

  pw.Widget _swatch(String hex, double size) {
    final value = int.tryParse(hex.replaceAll('#', '').trim(), radix: 16);
    return pw.Container(
      width: size,
      height: size,
      decoration: pw.BoxDecoration(
        color: value == null
            ? BiblePdfTokens.panel
            : PdfColor.fromInt(0xFF000000 | value),
        borderRadius: pw.BorderRadius.circular(3),
        border: pw.Border.all(color: BiblePdfTokens.rule, width: 0.5),
      ),
    );
  }

  /// Etiquetas cortas en línea (emociones, tags).
  pw.Widget tagRow(List<String> tags) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: BiblePdfTokens.gap),
    child: pw.Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final tag in tags)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: pw.BoxDecoration(
              color: BiblePdfTokens.panel,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Text(
              tag.toUpperCase(),
              style: pw.TextStyle(
                font: regular,
                fontSize: 7,
                letterSpacing: 0.6,
                color: BiblePdfTokens.secondary,
              ),
            ),
          ),
      ],
    ),
  );

  /// Fila de imágenes adjuntas a un punto.
  pw.Widget imageRow(List<pw.MemoryImage> images) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: BiblePdfTokens.gap),
    child: pw.Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final image in images)
          pw.ClipRRect(
            horizontalRadius: BiblePdfTokens.radius,
            verticalRadius: BiblePdfTokens.radius,
            child: pw.Image(image, height: 110, fit: pw.BoxFit.cover),
          ),
      ],
    ),
  );

  /// Luz: color y contraste. La temperatura (o los colores de la escena),
  /// el tinte, el ratio con sus stops y la corrección que hace falta.
  pw.Widget? lightMetricsPoint(
    String label,
    LightingMetrics metrics, {
    List<CorrectionGel> gels = const [],
  }) {
    if (metrics.isEmpty) return null;
    String hex(int rgb) =>
        '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
    final ratio = metrics.ratioOption;
    final recipe = metrics.usesColors ? null : metrics.recipe(gels);
    final cct = !metrics.usesColors && metrics.sources.isNotEmpty;
    String stops(double s) => s == 0
        ? 'clave'
        : '${s > 0 ? '+' : ''}${s % 1 == 0 ? s.toInt() : s} st'.replaceAll(
            '.',
            ',',
          );
    final rows = <(String, String)>[
      if (cct)
        for (final s in metrics.sources)
          (
            [
              s.role.label,
              if (s.name.trim().isNotEmpty) s.name.trim(),
            ].join(' · '),
            [
              'CCT ${s.kelvin} K',
              if (s.tint.abs() >= 0.5) LightingMetrics(tint: s.tint).tintLabel,
              stops(s.stops),
              s.soft ? 'suave' : 'dura',
            ].join(' · '),
          )
      else if (!metrics.usesColors && metrics.kelvin != null)
        ('Temperatura', 'CCT ${metrics.kelvin} K'),
      if (!cct &&
          !metrics.usesColors &&
          metrics.tint != null &&
          metrics.tint!.abs() >= 0.5)
        ('Tinte', metrics.tintLabel),
      if (!metrics.usesColors &&
          metrics.tint != null &&
          metrics.tint!.abs() >= 0.5)
        ('Tinte', metrics.tintLabel),
      if (ratio != null)
        ('Contraste', '${ratio.label} · ${ratio.stopsLabel} · ${ratio.use}'),
      if (recipe != null && !recipe.needsNothing)
        (
          'Corrección desde ${recipe.sourceKelvin} K',
          [
            ...recipe.gels.map((g) => g.name),
            if (recipe.tintGel != null) recipe.tintGel!,
          ].join(' + '),
        ),
      if (metrics.usesColors)
        for (final c in metrics.colors)
          (
            [
              c.role.label,
              if (c.name.trim().isNotEmpty) c.name.trim(),
            ].join(' · '),
            'HSI · ${c.hsiLabel}   ${c.rgbLabel}',
          ),
    ];
    final swatches = <(String, String)>[
      if (metrics.usesColors)
        for (final c in metrics.colors) (hex(c.rgb), c.role.label)
      else if (cct)
        for (final s in metrics.sources) (hex(s.rgb), '${s.kelvin} K')
      else if (metrics.color != null)
        (hex(metrics.color!), '${metrics.kelvin} K'),
    ];
    if (rows.isEmpty && swatches.isEmpty) return null;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (swatches.isNotEmpty) swatchRow(label, swatches),
        if (rows.isNotEmpty) specsPoint(swatches.isEmpty ? label : '', rows),
      ],
    );
  }

  /// Equipo: cada pieza con su papel, su estado y su alternativa.
  pw.Widget equipmentPoint(
    String label,
    List<BibleEquipmentItem> items, {
    bool feminine = true,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: BiblePdfTokens.gap),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        this.label(label),
        pw.SizedBox(height: 4),
        for (final item in items)
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 6),
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: BiblePdfTokens.panel,
              borderRadius: pw.BorderRadius.circular(BiblePdfTokens.radius),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    if (item.role.isNotEmpty) ...[
                      pw.Text(
                        item.role,
                        style: pw.TextStyle(
                          font: bold,
                          fontSize: 12,
                          color: BiblePdfTokens.accent,
                        ),
                      ),
                      pw.SizedBox(width: 8),
                    ],
                    pw.Expanded(
                      child: pw.Text(
                        item.name,
                        style: pw.TextStyle(
                          font: bold,
                          fontSize: 11,
                          color: BiblePdfTokens.ink,
                        ),
                      ),
                    ),
                    pw.Text(
                      (feminine ? item.status.feminine : item.status.masculine)
                          .toUpperCase(),
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: 7,
                        letterSpacing: 0.8,
                        color: item.status == BibleEquipmentStatus.definitive
                            ? BiblePdfTokens.accent
                            : BiblePdfTokens.secondary,
                      ),
                    ),
                  ],
                ),
                if (item.facts.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    item.facts.entries
                        .map((e) => '${e.key}: ${e.value}')
                        .join('  ·  '),
                    style: pw.TextStyle(
                      font: regular,
                      fontSize: 8,
                      color: BiblePdfTokens.secondary,
                    ),
                  ),
                ],
                if (item.note.trim().isNotEmpty) ...[
                  pw.SizedBox(height: 3),
                  pw.Text(
                    item.note.trim(),
                    style: pw.TextStyle(
                      font: regular,
                      fontSize: 9,
                      color: BiblePdfTokens.ink,
                    ),
                  ),
                ],
                if (item.hasAlternative) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'ALTERNATIVA · ${item.altName}'
                    '${item.altNote.trim().isEmpty ? '' : ' — ${item.altNote.trim()}'}',
                    style: pw.TextStyle(
                      font: regular,
                      fontSize: 8,
                      color: BiblePdfTokens.secondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    ),
  );

  /// Texto con datos: el desarrollo y, debajo, los datos con valor.
  pw.Widget? textSpecsPoint(String label, BibleTextSpecsValue value) {
    if (value.isEmpty) return null;
    final text = value.text.trim();
    final rows = value.filledRows;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (text.isNotEmpty) textPoint(label, text),
        if (rows.isNotEmpty) specsPoint(text.isEmpty ? label : '', rows),
      ],
    );
  }

  /// Tabla con su fila de títulos; solo las filas con algo escrito.
  pw.Widget tablePoint(String label, BibleTableValue table) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: BiblePdfTokens.gap),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        this.label(label),
        pw.SizedBox(height: 4),
        pw.Table(
          border: const pw.TableBorder(
            horizontalInside: pw.BorderSide(
              color: BiblePdfTokens.rule,
              width: 0.5,
            ),
            bottom: pw.BorderSide(color: BiblePdfTokens.rule, width: 0.5),
          ),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: BiblePdfTokens.panel),
              children: [
                for (final column in table.columns)
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      column.toUpperCase(),
                      style: pw.TextStyle(
                        font: regular,
                        fontSize: 7,
                        letterSpacing: 0.6,
                        color: BiblePdfTokens.secondary,
                      ),
                    ),
                  ),
              ],
            ),
            for (final row in table.filledRows)
              pw.TableRow(
                children: [
                  for (var c = 0; c < row.length; c++)
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        row[c],
                        style: pw.TextStyle(
                          font: c == 0 ? bold : regular,
                          fontSize: 9,
                          color: BiblePdfTokens.ink,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ],
    ),
  );

  /// Medidores: dato, valor, barra de escala si la hay y nota.
  pw.Widget metersPoint(String label, List<BibleMeter> meters) =>
      pw.Inseparable(
        child: pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: BiblePdfTokens.gap),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              this.label(label),
              pw.SizedBox(height: 4),
              for (final meter in meters)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Expanded(
                            child: pw.Text(
                              meter.label.toUpperCase(),
                              style: pw.TextStyle(
                                font: regular,
                                fontSize: 8,
                                letterSpacing: 0.6,
                                color: BiblePdfTokens.secondary,
                              ),
                            ),
                          ),
                          pw.Text(
                            meter.value,
                            style: pw.TextStyle(
                              font: bold,
                              fontSize: 10,
                              color: BiblePdfTokens.ink,
                            ),
                          ),
                        ],
                      ),
                      if (meter.fraction != null) ...[
                        pw.SizedBox(height: 2),
                        pw.Stack(
                          children: [
                            pw.Container(height: 2, color: BiblePdfTokens.rule),
                            pw.Row(
                              children: [
                                pw.Expanded(
                                  flex: (meter.fraction! * 1000).round().clamp(
                                    1,
                                    1000,
                                  ),
                                  child: pw.Container(
                                    height: 2,
                                    color: BiblePdfTokens.accent,
                                  ),
                                ),
                                pw.Spacer(
                                  flex:
                                      1000 -
                                      (meter.fraction! * 1000).round().clamp(
                                        1,
                                        999,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                      if (meter.note.trim().isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(
                          meter.note.trim(),
                          style: pw.TextStyle(
                            font: regular,
                            fontSize: 8,
                            color: BiblePdfTokens.secondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      );

  /// Pinta un punto según su tipo. `null` si no tiene contenido.
  /// Análisis de una imagen: la imagen, su título, lo que cuenta y su luz.
  pw.Widget? _imageAnalysisPoint(String label, String raw) {
    Map<dynamic, dynamic> map;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      map = decoded;
    } catch (_) {
      return null;
    }
    final id = (map['image'] as num?)?.toInt();
    final note = BibleImageNote.fromJson(map);
    final image = id == null ? null : _loaded([id]).firstOrNull;
    if (image == null && note.isEmpty) return null;
    final light = lightMetricsPoint(
      'Su luz',
      LightingMetrics.fromJson(note.light),
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: BiblePdfTokens.gap),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          this.label(label),
          pw.SizedBox(height: 4),
          if (image != null)
            pw.ClipRRect(
              horizontalRadius: BiblePdfTokens.radius,
              verticalRadius: BiblePdfTokens.radius,
              child: pw.Image(image, height: 200, fit: pw.BoxFit.contain),
            ),
          pw.SizedBox(height: 5),
          _titled(note.title.trim(), note.text.trim()),
          ?light,
        ],
      ),
    );
  }

  pw.Widget? point(BibleSectionField field, String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    switch (field.type) {
      case BibleSectionFieldType.list:
        final items = BibleSectionPointValue.decodeList(
          raw,
        ).where((e) => e.trim().isNotEmpty).toList();
        return items.isEmpty ? null : listPoint(field.label, items);
      case BibleSectionFieldType.specs:
        if (field.widget == 'light_metrics') {
          return lightMetricsPoint(field.label, LightingMetrics.fromJson(raw));
        }
        if (field.widget == 'image_analysis') {
          return _imageAnalysisPoint(field.label, raw);
        }
        if (field.widget == 'text_specs') {
          return textSpecsPoint(field.label, BibleTextSpecsValue.decode(raw));
        }
        final rows = BibleSectionPointValue.decodeSpecs(raw)
            .where((r) => r.$1.trim().isNotEmpty || r.$2.trim().isNotEmpty)
            .toList();
        return rows.isEmpty ? null : specsPoint(field.label, rows);
      case BibleSectionFieldType.palette:
        return _palettePoint(field, raw);
      case BibleSectionFieldType.cards:
        final cards = BibleCard.listFrom(raw).where((c) => !c.isEmpty).toList();
        if (cards.isEmpty) return null;
        return cardsPoint(
          field.label,
          cards,
          // El mosaico sale como tarjetas con su imagen, en columnas.
          columns:
              field.widget == 'cards_pillars' || field.widget == 'cards_mosaic',
        );
      case BibleSectionFieldType.acts:
        return actsPointOf(field.label, BibleActsValue.decode(raw));
      case BibleSectionFieldType.tags:
        final tags = BibleSectionPointValue.decodeList(
          raw,
        ).where((e) => e.trim().isNotEmpty).toList();
        if (tags.isEmpty) return null;
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [label(field.label), pw.SizedBox(height: 6), tagRow(tags)],
        );
      case BibleSectionFieldType.referenceDeck:
        final items = BibleSectionExportReader.referenceItems(
          raw,
        ).where((r) => !r.isEmpty).toList();
        if (items.isEmpty) return null;
        final (why, purpose) = BibleSectionExportReader.referenceLabels(raw);
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            label(field.label),
            pw.SizedBox(height: 6),
            for (final item in items)
              referencePoint(
                kicker: [
                  item.kind,
                  item.work,
                ].where((e) => e.isNotEmpty).join(' · '),
                title: item.title,
                sections: [
                  (why, item.why),
                  (purpose, item.purpose),
                  ('Momento', item.scene),
                ],
              ),
          ],
        );
      case BibleSectionFieldType.equipment:
        final items = BibleEquipmentItem.listFrom(
          raw,
        ).where((item) => !item.isEmpty).toList();
        return items.isEmpty ? null : equipmentPoint(field.label, items);
      case BibleSectionFieldType.table:
        final table = BibleTableValue.decode(raw);
        return table.isEmpty ? null : tablePoint(field.label, table);
      case BibleSectionFieldType.meters:
        final meters = BibleMeter.listFrom(
          raw,
        ).where((m) => !m.isEmpty).toList();
        return meters.isEmpty ? null : metersPoint(field.label, meters);
      case BibleSectionFieldType.gallery:
        final shots = _loaded([
          for (final id in BibleSectionPointValue.decodeList(raw))
            if (int.tryParse(id) != null) int.parse(id),
        ]);
        if (shots.isEmpty) return null;
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            label(field.label),
            pw.SizedBox(height: 6),
            imageStrip(shots, height: 96),
          ],
        );
      default:
        return textPoint(field.label, raw.trim());
    }
  }
}
