import 'package:iris_dp/features/script_import/script_text_formatter.dart';

void main() {
  const raw = '''
INT. COCINA - DÍA María cocina. EXT. CALLE - NOCHE Pasa un coche.
''';

  final formatted = ScriptTextFormatter.forDisplay(raw);
  assert(formatted.contains('\n'));
  assert(ScriptTextFormatter.isSlugline('INT. COCINA - DÍA'));
}
