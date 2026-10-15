import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/visual_bible/bible_section_ids.dart';

/// Lo que cada pantalla de la biblia no ha podido pintar: puntos de su
/// lista sin widget que los represente. Lo apunta la pantalla al dibujarse
/// y lo lee el panel lateral para avisar.
class BibleRenderReport extends StateNotifier<Map<String, Set<String>>> {
  BibleRenderReport() : super(const {});

  void report(String sectionId, Set<String> unrendered) {
    if (!mounted) return;
    final before = state[sectionId] ?? const <String>{};
    if (before.length == unrendered.length && before.containsAll(unrendered)) {
      return;
    }
    state = {...state, sectionId: unrendered};
  }
}

final bibleRenderReportProvider =
    StateNotifierProvider<BibleRenderReport, Map<String, Set<String>>>(
      (ref) => BibleRenderReport(),
    );

/// Pantallas que se pintan con bloques propios, fuera del sistema de
/// puntos: sus bloques no se ordenan ni se quitan desde el panel, y los
/// puntos de su lista no se ven todavía.
const kSectionFixedBlocks = <String, List<String>>{
  BibleSectionId.location: [
    'Tarjetas de localizaciones',
    'Ficha de cada set',
    'La luz del lugar',
    'Ubicación, sol y meteorología',
  ],
  BibleSectionId.moodboard: ['Rejilla del moodboard'],
};
