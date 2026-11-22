import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/pdf_export/rig_sheet_pdf.dart';

/// Lo último que se eligió para la hoja de luz: lo comparten la pantalla de
/// alzado y perfil y la ventana de exportar, para que lo que se ve sea lo
/// que sale.
abstract final class LightSheetPrefs {
  static const _gaffer = 'iris_light_sheet_gaffer';
  static const _layout = 'iris_light_sheet_layout';
  static const _paper = 'iris_light_sheet_paper';
  static const _numbers = 'iris_light_sheet_numbers';
  static const _beams = 'iris_light_sheet_beams';
  static const _pools = 'iris_light_sheet_pools';
  static const _people = 'iris_light_sheet_people';
  static const _schedule = 'iris_light_sheet_schedule';

  static Future<RigSheetOptions> load() async {
    const base = RigSheetOptions();
    try {
      final p = await SharedPreferences.getInstance();
      return RigSheetOptions(
        layout:
            RigSheetLayout.values.asNameMap()[p.getString(_layout)] ??
            base.layout,
        paper:
            RigSheetPaper.values.asNameMap()[p.getString(_paper)] ?? base.paper,
        numbers:
            RigSheetNumbers.values.asNameMap()[p.getString(_numbers)] ??
            base.numbers,
        schedule: p.getBool(_schedule) ?? base.schedule,
        beams: p.getBool(_beams) ?? base.beams,
        pools: p.getBool(_pools) ?? base.pools,
        people: p.getBool(_people) ?? base.people,
      );
    } catch (_) {
      return base;
    }
  }

  static Future<void> save(RigSheetOptions o) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_layout, o.layout.name);
      await p.setString(_paper, o.paper.name);
      await p.setString(_numbers, o.numbers.name);
      await p.setBool(_schedule, o.schedule);
      await p.setBool(_beams, o.beams);
      await p.setBool(_pools, o.pools);
      await p.setBool(_people, o.people);
    } catch (_) {
      // La próxima vez saldrá lo de siempre.
    }
  }

  static Future<String> gaffer() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getString(_gaffer) ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<void> saveGaffer(String name) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_gaffer, name);
    } catch (_) {}
  }
}
