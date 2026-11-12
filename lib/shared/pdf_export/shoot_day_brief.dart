import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/database/app_database.dart';
import '../../core/places/static_map.dart';
import '../../core/utils/pdf_safe_image.dart';
import '../../core/utils/shot_reference_import.dart';
import '../../core/weather/weather_models.dart';
import '../../features/locations/site_place.dart'
    show sitePlaceLines, siteMapsUrl, siteWazeUrl;
import '../../features/shoot_documents/shoot_day_timeline.dart';
import '../../features/shoot_documents/shoot_plan.dart';
import '../../features/technical_script/technical_script_export.dart'
    show formatShootDate, shootDayWeather;
import '../rich_text/script_markup.dart';

/// Un plano dentro del horario de la jornada.
class BriefShot {
  final int number;
  final String framing;

  /// «35mm · MANO · Normal».
  final String tech;
  final String time;
  final Uint8List? image;

  const BriefShot({
    required this.number,
    this.framing = '',
    this.tech = '',
    this.time = '',
    this.image,
  });
}

/// Una línea del horario: una franja o una escena con sus planos.
class BriefRow {
  final bool scene;

  /// El tipo de franja (`meal`, `setup`…); nulo en una escena.
  final ShootStripKind? kind;
  final String time;
  final String title;
  final String detail;
  final List<BriefShot> shots;

  const BriefRow({
    required this.time,
    required this.title,
    this.scene = false,
    this.kind,
    this.detail = '',
    this.shots = const [],
  });
}

/// Una hora de la previsión, para la tira del tiempo.
class BriefHour {
  final int hour;
  final double? temperature;
  final int? code;
  final int? rain;
  final double? wind;
  final bool isDay;

  const BriefHour({
    required this.hour,
    this.temperature,
    this.code,
    this.rain,
    this.wind,
    this.isDay = true,
  });
}

/// Todo lo que se cuenta de una jornada arriba de sus documentos: cuándo,
/// dónde (con mapa, QR y enlaces), el tiempo hora a hora, el sol y el
/// horario. Una sola lectura para el orden del día y el guion técnico.
class ShootDayBrief {
  final String dayName;

  /// «día 1 de 5».
  final String position;

  /// «viernes 13 de noviembre de 2026».
  final String date;

  /// «07:30 – 17:00».
  final String window;

  /// La primera hora del horario: la citación.
  final String call;
  final String placeName;
  final String placeDetail;
  final double? latitude;
  final double? longitude;
  final Uint8List? map;
  final Uint8List? cover;
  final String note;

  /// «Cubierto · 16–20 °C · lluvia 17 % · viento 20 km/h».
  final String weatherLine;
  final String? weatherNotice;
  final List<BriefHour> hours;

  /// («Amanecer», «07:38»)…
  final List<(String, String)> sun;
  final List<BriefRow> rows;

  const ShootDayBrief({
    required this.dayName,
    this.position = '',
    this.date = '',
    this.window = '',
    this.call = '',
    this.placeName = '',
    this.placeDetail = '',
    this.latitude,
    this.longitude,
    this.map,
    this.cover,
    this.note = '',
    this.weatherLine = '',
    this.weatherNotice,
    this.hours = const [],
    this.sun = const [],
    this.rows = const [],
  });

  bool get located => latitude != null && longitude != null;
  String? get mapsUrl => located ? siteMapsUrl(latitude!, longitude!) : null;
  String? get wazeUrl => located ? siteWazeUrl(latitude!, longitude!) : null;

  /// Las jornadas [dayIds] (todas si está vacío), en el orden del plan. Con
  /// [thumbs], cada plano lleva su imagen. La portada es [coverPath] si se
  /// eligió; si no, la primera foto de la localización y, sin ella,
  /// [fallbackCoverPath] (la del proyecto).
  static Future<List<ShootDayBrief>> load(
    AppDatabase db,
    int projectId, {
    Set<int> dayIds = const {},
    bool thumbs = true,
    String? coverPath,
    String? fallbackCoverPath,
    DateTime? now,
  }) async {
    final days = sortShootDays(await db.getShootDocumentsForProject(projectId));
    final scenes = {
      for (final s in await db.watchScenesForProject(projectId).first) s.id: s,
    };
    final shots = {
      for (final s in await db.getShotsForProject(projectId)) s.id: s,
    };
    final sites = await db.watchSitesForProject(projectId).first;
    final siteById = {for (final s in sites) s.id: s};
    final siteByUid = {
      for (final s in sites)
        if (s.uid != null) s.uid!: s,
    };
    final chosenCover = await PdfSafeImage.loadFromPathMaxEdge(
      coverPath,
      maxEdge: 1400,
    );
    final fallbackCover = chosenCover != null
        ? null
        : await PdfSafeImage.loadFromPathMaxEdge(
            fallbackCoverPath,
            maxEdge: 1400,
          );
    final out = <ShootDayBrief>[];
    for (final (i, day) in days.indexed) {
      if (dayIds.isNotEmpty && !dayIds.contains(day.id)) continue;
      final blocks = await db.getBlocksForShootDocument(day.id);
      final site = siteById[day.locationSiteId];
      final rows = <BriefRow>[];
      for (final entry in buildShootDayEntries(blocks, shots)) {
        switch (entry) {
          case ShootStripEntry(:final block, :final strip):
            rows.add(
              BriefRow(
                kind: strip.kind,
                time: shootTimeRange(strip.from, strip.to),
                title: ShootStrip.titleOf(block),
                detail: [
                  ?siteByUid[strip.siteUid]?.name,
                  if ((block.noteBody ?? '').trim().isNotEmpty)
                    block.noteBody!.trim(),
                ].join(' · '),
              ),
            );
          case ShootSceneEntry():
            final scene = scenes[entry.sceneId];
            final schedule = SceneSchedule.of(entry.blocks.first);
            rows.add(
              BriefRow(
                scene: true,
                time: shootTimeRange(schedule.from, schedule.to),
                title: scene == null
                    ? 'Escena'
                    : 'Esc. ${scene.label} · ${scene.intExt}. '
                          '${scene.locationPureName} · ${scene.dayNight}',
                detail: schedule.note.trim(),
                shots: [
                  for (final b in entry.shotBlocks(shots))
                    await _shot(shots[b.shotId]!, ShotTime.of(b), thumbs),
                ],
              ),
            );
        }
      }
      out.add(
        await _brief(
          db,
          projectId,
          day,
          site,
          rows,
          position: 'día ${i + 1} de ${days.length}',
          cover: chosenCover,
          fallbackCover: fallbackCover,
          now: now,
        ),
      );
    }
    return out;
  }

  static Future<BriefShot> _shot(Shot shot, ShotTime time, bool thumbs) async {
    String plain(String? s) =>
        scriptMarkupToPlain(s).trim().replaceAll('\n', ' ');
    final path = storyboardImageOf(shot) ?? referenceImageOf(shot);
    return BriefShot(
      number: shot.number,
      framing: plain(shot.framing),
      tech: [
        plain(shot.lens),
        plain(shot.movement),
        plain(shot.angle),
      ].where((s) => s.isNotEmpty).join(' · '),
      time: [
        shootTimeRange(time.from, time.to),
        if (time.note.trim().isNotEmpty) time.note.trim(),
      ].where((s) => s.isNotEmpty).join(' · '),
      image: thumbs
          ? await PdfSafeImage.loadFromPathMaxEdge(path, maxEdge: 520)
          : null,
    );
  }

  static Future<ShootDayBrief> _brief(
    AppDatabase db,
    int projectId,
    ShootDocument day,
    LocationSite? site,
    List<BriefRow> rows, {
    required String position,
    Uint8List? cover,
    Uint8List? fallbackCover,
    DateTime? now,
  }) async {
    final options = WeatherOptions.decode(day.weatherOptionsJson);
    final weather = shootDayWeather(day, site, now: now);
    final forecast = weather.forecast;
    final offset =
        forecast?.utcOffsetSeconds ?? DateTime.now().timeZoneOffset.inSeconds;
    String clock(DateTime? utc) {
      if (utc == null) return '—';
      final t = utc.add(Duration(seconds: offset));
      return '${t.hour.toString().padLeft(2, '0')}:'
          '${t.minute.toString().padLeft(2, '0')}';
    }

    String n(double? v) => v == null ? '—' : v.round().toString();
    final weatherLine = forecast == null
        ? ''
        : [
            if (options.sky) weatherCodeLabel(forecast.weatherCode),
            if (options.temperature)
              '${n(forecast.temperatureMin)}–${n(forecast.temperatureMax)} °C',
            if (options.rain)
              'lluvia ${forecast.precipitationProbabilityMax ?? '—'} %',
            if (options.wind)
              'viento ${n(forecast.windMax)} km/h, rachas '
                  '${n(forecast.gustsMax)}',
          ].join(' · ');
    int? hourOf(String? hm) =>
        hm == null ? null : int.tryParse(hm.split(':').first);
    final from = hourOf(day.shootFromTime);
    final to = hourOf(day.shootToTime);
    var hours = forecast == null || !options.hourly
        ? <WeatherHour>[]
        : [...forecast.hoursBetween(from, to)];
    if (from != null && to != null && from > to) {
      hours.sort(
        (a, b) => ((a.hour - from) % 24).compareTo((b.hour - from) % 24),
      );
    }
    // Más de doce horas no caben legibles: una de cada dos.
    if (hours.length > 13) {
      hours = [
        for (final (i, h) in hours.indexed)
          if (i.isEven) h,
      ];
    }
    final sun = weather.sun;
    final firstTime = rows
        .map((r) => r.time.split('–').first.trim())
        .where((t) => RegExp(r'^\d{1,2}:\d{2}$').hasMatch(t))
        .firstOrNull;

    Uint8List? map;
    Uint8List? photo = cover;
    if (site != null) {
      final lat = site.latitude;
      final lon = site.longitude;
      if (lat != null && lon != null) {
        final path = await ensureSiteMap(
          projectId: projectId,
          siteId: site.id,
          latitude: lat,
          longitude: lon,
        ).catchError((Object _) => null);
        map = await PdfSafeImage.loadFromPathMaxEdge(path, maxEdge: 900);
      }
      if (photo == null) {
        final images = await db.watchImagesForSite(site.id).first;
        for (final image in images) {
          photo = await PdfSafeImage.loadFromPathMaxEdge(
            image.imagePath,
            maxEdge: 1400,
          );
          if (photo != null) break;
        }
      }
    }
    photo ??= fallbackCover;
    final lines = site == null ? null : sitePlaceLines(site);
    return ShootDayBrief(
      dayName: day.name,
      position: position,
      date: formatShootDate(day.shootDate),
      window: shootTimeRange(day.shootFromTime, day.shootToTime),
      call: firstTime ?? day.shootFromTime ?? '',
      placeName: site?.name ?? '',
      placeDetail: lines == null || !site!.isLocated ? '' : lines.detail,
      latitude: site?.latitude,
      longitude: site?.longitude,
      map: map,
      cover: photo,
      note: (day.description ?? '').trim(),
      weatherLine: weatherLine,
      weatherNotice: forecast == null && weather.lines.isNotEmpty
          ? weather.lines.first
          : null,
      hours: [
        for (final h in hours)
          BriefHour(
            hour: h.hour,
            temperature: h.temperature,
            code: h.weatherCode,
            rain: h.precipitationProbability,
            wind: h.wind,
            isDay: h.isDay ?? true,
          ),
      ],
      sun: sun == null
          ? const []
          : [
              if (options.sun) ('Amanecer', clock(sun.sunrise)),
              if (options.blueAndGolden) ...[
                (
                  'Dorada mañana',
                  '${clock(sun.blueHourMorningEnd)}–'
                      '${clock(sun.goldenHourMorningEnd)}',
                ),
                (
                  'Dorada tarde',
                  '${clock(sun.goldenHourEveningStart)}–'
                      '${clock(sun.blueHourEveningStart)}',
                ),
                (
                  'Azul tarde',
                  '${clock(sun.blueHourEveningStart)}–${clock(sun.dusk)}',
                ),
              ],
              if (options.sun) ('Atardecer', clock(sun.sunset)),
            ],
      rows: rows,
    );
  }
}

extension on LocationSite {
  bool get isLocated => latitude != null && longitude != null;
}

/// Las piezas del PDF del resumen de jornada.
abstract final class BriefPdf {
  static const ink = PdfColor.fromInt(0xFF141414);
  static const soft = PdfColor.fromInt(0xFF6B6B6B);
  static const faint = PdfColor.fromInt(0xFF9A9A9A);
  static const line = PdfColor.fromInt(0xFFDADADA);
  static const paper = PdfColor.fromInt(0xFFF5F4F0);
  static const accent = PdfColor.fromInt(0xFFE2372D);

  /// Color de cada tipo de franja, el mismo que en la app.
  static PdfColor stripColor(ShootStripKind? kind) => switch (kind) {
    ShootStripKind.call => const PdfColor.fromInt(0xFF2F80ED),
    ShootStripKind.prelight => const PdfColor.fromInt(0xFF9B6FE0),
    ShootStripKind.setup => const PdfColor.fromInt(0xFFE0558F),
    ShootStripKind.wrap => const PdfColor.fromInt(0xFF7A8699),
    ShootStripKind.meal => const PdfColor.fromInt(0xFFE0A030),
    ShootStripKind.rest => const PdfColor.fromInt(0xFF4DB37A),
    ShootStripKind.move => const PdfColor.fromInt(0xFFD9744F),
    ShootStripKind.note || null => soft,
  };

  static pw.TextStyle _label() =>
      const pw.TextStyle(fontSize: 6.5, color: soft, letterSpacing: 1.1);

  /// La banda negra de arriba: el documento, la jornada y la fecha, con la
  /// foto de portada a la derecha.
  static pw.Widget band({
    required String project,
    required String document,
    required ShootDayBrief brief,
    double height = 128,
  }) {
    final cover = brief.cover;
    return pw.Container(
      height: height,
      color: ink,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(18, 14, 14, 14),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '${document.toUpperCase()}  ·  ${project.toUpperCase()}',
                    style: const pw.TextStyle(
                      fontSize: 7.5,
                      color: PdfColors.grey400,
                      letterSpacing: 1.4,
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        brief.dayName,
                        maxLines: 1,
                        style: pw.TextStyle(
                          fontSize: 26,
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        [
                          if (brief.date.isNotEmpty) brief.date,
                          if (brief.position.isNotEmpty) brief.position,
                        ].join('  ·  '),
                        style: const pw.TextStyle(
                          fontSize: 10.5,
                          color: PdfColors.grey300,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (cover != null)
            pw.SizedBox(
              width: height * 1.6,
              child: pw.Image(pw.MemoryImage(cover), fit: pw.BoxFit.cover),
            ),
        ],
      ),
    );
  }

  /// Cuándo y dónde: horario y citación, el lugar con sus enlaces, y el
  /// mapa con un QR para abrirlo en el móvil.
  static pw.Widget facts(ShootDayBrief brief, {double height = 118}) {
    pw.Widget fact(String name, String value, {String? sub}) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(name, style: _label()),
          pw.SizedBox(height: 1.5),
          pw.Text(
            value.isEmpty ? '—' : value,
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          if (sub != null && sub.isNotEmpty)
            pw.Text(sub, style: const pw.TextStyle(fontSize: 8, color: soft)),
        ],
      ),
    );
    pw.Widget link(String text, String url) => pw.UrlLink(
      destination: url,
      child: pw.Container(
        margin: const pw.EdgeInsets.only(right: 6, top: 4),
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: ink, width: 0.6),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Text(
          text,
          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
        ),
      ),
    );

    final when = pw.SizedBox(
      width: 118,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          fact('CITACIÓN', brief.call),
          fact('SE RUEDA', brief.window),
        ],
      ),
    );
    final where = pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('LUGAR', style: _label()),
          pw.SizedBox(height: 1.5),
          pw.Text(
            brief.placeName.isEmpty ? '—' : brief.placeName,
            maxLines: 2,
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          if (brief.placeDetail.isNotEmpty)
            pw.Text(
              brief.placeDetail,
              maxLines: 3,
              style: const pw.TextStyle(fontSize: 8.5, color: soft),
            ),
          if (brief.located)
            pw.Wrap(
              children: [
                link('Google Maps', brief.mapsUrl!),
                link('Waze', brief.wazeUrl!),
              ],
            ),
        ],
      ),
    );
    final mapBox = !brief.located
        ? null
        : pw.SizedBox(
            width: height * StaticMap.width / StaticMap.height,
            height: height,
            child: pw.Stack(
              children: [
                pw.Positioned.fill(
                  child: brief.map == null
                      ? pw.Container(color: paper)
                      : pw.Image(
                          pw.MemoryImage(brief.map!),
                          fit: pw.BoxFit.cover,
                        ),
                ),
                pw.Positioned(
                  left: 5,
                  bottom: 5,
                  child: pw.UrlLink(
                    destination: brief.mapsUrl!,
                    child: pw.Container(
                      color: PdfColors.white,
                      padding: const pw.EdgeInsets.all(3),
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: brief.mapsUrl!,
                        width: 46,
                        height: 46,
                        drawText: false,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
    return pw.SizedBox(
      height: height,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          when,
          pw.SizedBox(width: 10),
          where,
          if (mapBox != null) ...[pw.SizedBox(width: 12), mapBox],
        ],
      ),
    );
  }

  /// El tiempo: una casilla por hora con su icono, y debajo el sol.
  static pw.Widget weather(ShootDayBrief brief) {
    final children = <pw.Widget>[];
    if (brief.weatherLine.isNotEmpty || brief.weatherNotice != null) {
      children.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Row(
            children: [
              pw.Text('TIEMPO', style: _label()),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Text(
                  brief.weatherLine.isNotEmpty
                      ? brief.weatherLine
                      : brief.weatherNotice!,
                  style: const pw.TextStyle(fontSize: 8.5),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (brief.hours.isNotEmpty) {
      children.add(
        pw.Row(
          children: [
            for (final h in brief.hours)
              pw.Expanded(
                child: pw.Container(
                  margin: const pw.EdgeInsets.symmetric(horizontal: 1),
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: paper,
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        '${h.hour.toString().padLeft(2, '0')} h',
                        style: const pw.TextStyle(fontSize: 6.5, color: soft),
                      ),
                      pw.SizedBox(height: 2),
                      weatherIcon(h.code, isDay: h.isDay, size: 15),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        h.temperature == null
                            ? '—'
                            : '${h.temperature!.round()}°',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        '${h.rain ?? 0} %',
                        style: pw.TextStyle(
                          fontSize: 6.5,
                          color: (h.rain ?? 0) >= 30
                              ? const PdfColor.fromInt(0xFF2F80ED)
                              : soft,
                        ),
                      ),
                      if (h.wind != null)
                        pw.Text(
                          '${h.wind!.round()} km/h',
                          style: const pw.TextStyle(fontSize: 6, color: faint),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }
    if (brief.sun.isNotEmpty) {
      children.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 5),
          child: pw.Wrap(
            spacing: 14,
            runSpacing: 3,
            children: [
              for (final (name, value) in brief.sun)
                pw.RichText(
                  text: pw.TextSpan(
                    children: [
                      pw.TextSpan(
                        text: '${name.toUpperCase()}  ',
                        style: _label(),
                      ),
                      pw.TextSpan(
                        text: value,
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
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
    if (children.isEmpty) return pw.SizedBox();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: children,
    );
  }

  /// Un icono del tiempo dibujado (las fuentes del PDF no traen emojis).
  static pw.Widget weatherIcon(
    int? code, {
    bool isDay = true,
    double size = 14,
  }) {
    final c = code ?? 0;
    final sunny = c <= 1;
    final partly = c == 2;
    final rain = (c >= 51 && c <= 67) || (c >= 80 && c <= 82);
    final snow = (c >= 71 && c <= 77) || c == 85 || c == 86;
    final storm = c >= 95;
    return pw.SizedBox(
      width: size,
      height: size,
      child: pw.CustomPaint(
        size: PdfPoint(size, size),
        painter: (canvas, s) {
          final w = s.x;
          final h = s.y;
          void circle(double x, double y, double r, PdfColor color) {
            canvas
              ..setFillColor(color)
              ..drawEllipse(x, y, r, r)
              ..fillPath();
          }

          void cloud(double dy, PdfColor color) {
            circle(w * 0.36, h * 0.5 + dy, w * 0.2, color);
            circle(w * 0.58, h * 0.58 + dy, w * 0.24, color);
            circle(w * 0.76, h * 0.48 + dy, w * 0.17, color);
            canvas
              ..setFillColor(color)
              ..drawRect(w * 0.2, h * 0.32 + dy, w * 0.64, h * 0.18)
              ..fillPath();
          }

          const sunColor = PdfColor.fromInt(0xFFF2B200);
          const moonColor = PdfColor.fromInt(0xFF8C9BB0);
          const cloudColor = PdfColor.fromInt(0xFFA9AFB8);
          if (sunny || partly) {
            final at = partly ? 0.36 : 0.5;
            circle(
              w * at,
              h * (partly ? 0.64 : 0.5),
              w * (partly ? 0.2 : 0.26),
              isDay ? sunColor : moonColor,
            );
            if (isDay && sunny) {
              canvas
                ..setStrokeColor(sunColor)
                ..setLineWidth(w * 0.06);
              for (var i = 0; i < 8; i++) {
                final a = i * math.pi / 4;
                canvas
                  ..moveTo(
                    w / 2 + math.cos(a) * w * 0.34,
                    h / 2 + math.sin(a) * h * 0.34,
                  )
                  ..lineTo(
                    w / 2 + math.cos(a) * w * 0.46,
                    h / 2 + math.sin(a) * h * 0.46,
                  )
                  ..strokePath();
              }
            }
            if (partly) cloud(-h * 0.08, cloudColor);
            return;
          }
          cloud(rain || snow || storm ? h * 0.12 : 0, cloudColor);
          if (rain || storm) {
            canvas
              ..setStrokeColor(const PdfColor.fromInt(0xFF2F80ED))
              ..setLineWidth(w * 0.07);
            for (final x in [0.36, 0.56, 0.76]) {
              canvas
                ..moveTo(w * x, h * 0.36)
                ..lineTo(w * (x - 0.08), h * 0.12)
                ..strokePath();
            }
          }
          if (snow) {
            for (final x in [0.36, 0.56, 0.76]) {
              circle(
                w * x,
                h * 0.2,
                w * 0.05,
                const PdfColor.fromInt(0xFF6FA8DC),
              );
            }
          }
          if (storm) {
            canvas
              ..setFillColor(sunColor)
              ..moveTo(w * 0.55, h * 0.42)
              ..lineTo(w * 0.42, h * 0.18)
              ..lineTo(w * 0.52, h * 0.18)
              ..lineTo(w * 0.46, h * 0.0)
              ..lineTo(w * 0.64, h * 0.26)
              ..lineTo(w * 0.54, h * 0.26)
              ..closePath()
              ..fillPath();
          }
        },
      ),
    );
  }

  /// Una línea del horario. Las franjas, con su color; las escenas, con
  /// sus planos en imagen si [thumbs].
  static pw.Widget row(
    BriefRow row, {
    bool thumbs = true,
    double thumbWidth = 92,
  }) {
    final color = row.scene ? ink : stripColor(row.kind);
    final time = pw.SizedBox(
      width: 64,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (final (i, part) in row.time.split('–').indexed)
            if (part.trim().isNotEmpty)
              pw.Text(
                part.trim(),
                style: pw.TextStyle(
                  fontSize: i == 0 ? 11 : 8.5,
                  color: i == 0 ? ink : soft,
                  fontWeight: i == 0 ? pw.FontWeight.bold : null,
                ),
              ),
          if (row.time.trim().isEmpty)
            pw.Text('—', style: const pw.TextStyle(fontSize: 11, color: faint)),
        ],
      ),
    );
    final body = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          row.title,
          style: pw.TextStyle(
            fontSize: row.scene ? 10.5 : 9.5,
            fontWeight: row.scene ? pw.FontWeight.bold : null,
            color: row.scene ? ink : color,
          ),
        ),
        if (row.detail.isNotEmpty)
          pw.Text(
            row.detail,
            style: const pw.TextStyle(fontSize: 8, color: soft),
          ),
        if (row.shots.isNotEmpty) ...[
          pw.SizedBox(height: 5),
          if (thumbs)
            pw.Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final shot in row.shots) _thumb(shot, thumbWidth),
              ],
            )
          else
            for (final shot in row.shots)
              pw.Text(
                [
                  '${shot.number}',
                  if (shot.framing.isNotEmpty) shot.framing,
                  if (shot.time.isNotEmpty) shot.time,
                ].join(' · '),
                style: const pw.TextStyle(fontSize: 8),
              ),
        ],
      ],
    );
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 4),
      decoration: pw.BoxDecoration(
        color: row.scene ? null : paper,
        border: row.scene
            ? const pw.Border(bottom: pw.BorderSide(color: line, width: 0.6))
            : null,
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(width: 3, height: row.scene ? 22 : 18, color: color),
          pw.SizedBox(width: 8),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 5),
            child: time,
          ),
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 5),
              child: body,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _thumb(BriefShot shot, double width) {
    final height = width * 9 / 16;
    return pw.SizedBox(
      width: width,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Stack(
            children: [
              pw.Container(
                width: width,
                height: height,
                color: paper,
                alignment: pw.Alignment.center,
                child: shot.image == null
                    ? pw.Text(
                        'Sin imagen',
                        style: const pw.TextStyle(fontSize: 6.5, color: faint),
                      )
                    : pw.Image(
                        pw.MemoryImage(shot.image!),
                        fit: pw.BoxFit.cover,
                      ),
              ),
              pw.Positioned(
                left: 0,
                top: 0,
                child: pw.Container(
                  color: ink,
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1.5,
                  ),
                  child: pw.Text(
                    '${shot.number}',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 2),
          if (shot.framing.isNotEmpty)
            pw.Text(
              shot.framing,
              maxLines: 2,
              style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
            ),
          if (shot.tech.isNotEmpty)
            pw.Text(
              shot.tech,
              maxLines: 1,
              style: const pw.TextStyle(fontSize: 6.5, color: soft),
            ),
          if (shot.time.isNotEmpty)
            pw.Text(
              shot.time,
              maxLines: 1,
              style: const pw.TextStyle(fontSize: 6.5, color: soft),
            ),
        ],
      ),
    );
  }
}
