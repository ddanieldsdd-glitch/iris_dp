import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tamaños de referencia: iPhone, iPad y escritorio.
const auditIphone = Size(390, 844);
const auditIpad = Size(820, 1180);
const auditDesktop = Size(1440, 900);

void setAuditSize(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = size * 3;
  addTearDown(tester.view.reset);
}

/// Busca el fallo que Flutter no marca como desborde: texto aplastado a una
/// columna de pocas letras, o que acaba fuera de la pantalla.
List<String> layoutProblems(WidgetTester tester) {
  final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
  final out = <String>[];
  final sideways = <RenderObject>{
    for (final e in find.byType(Scrollable).evaluate())
      if ((e.widget as Scrollable).axisDirection == AxisDirection.left ||
          (e.widget as Scrollable).axisDirection == AxisDirection.right)
        if (e.renderObject case final RenderObject o) o,
  };
  for (final r in tester.allRenderObjects) {
    if (r is! RenderParagraph || !r.hasSize || !r.attached) continue;
    final text = r.text.toPlainText().trim();
    if (text.length < 8 || _insideAny(r, sideways)) continue;
    if (_clipped(r)) continue;
    final origin = r.localToGlobal(Offset.zero);
    final preview = text.length > 40 ? '${text.substring(0, 40)}…' : text;
    if (r.size.width < 36) {
      out.add('aplastado (${r.size.width.toStringAsFixed(0)} pt): $preview');
    } else if (origin.dx + r.size.width > screen.width + 1) {
      out.add('fuera de la pantalla: $preview');
    }
  }
  return out;
}

bool _insideAny(RenderObject r, Set<RenderObject> ancestors) {
  for (RenderObject? p = r.parent; p != null; p = p.parent) {
    if (ancestors.contains(p)) return true;
  }
  return false;
}

/// Lo oculto por animaciones o Offstage no cuenta.
bool _clipped(RenderObject r) {
  for (RenderObject? p = r.parent; p != null; p = p.parent) {
    if (p is RenderOffstage && p.offstage) return true;
  }
  return false;
}

void expectCleanLayout(WidgetTester tester) {
  expect(tester.takeException(), isNull);
  expect(layoutProblems(tester), isEmpty);
}
