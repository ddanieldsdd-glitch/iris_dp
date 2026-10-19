import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/sync/project_content_bundle.dart';

/// La huella cuenta si hay archivo, no dónde está: un dibujo nuevo o
/// borrado llega a los demás; la carpeta de cada equipo no.
void main() {
  Map<String, dynamic> bundle(Object? storyboard, {Object? sketches}) => {
    'shots': [
      {
        'uid': 'a',
        'number': 1,
        'storyboardImagePath': storyboard,
        'cameraPlanImagePath': sketches,
      },
    ],
  };

  test('la carpeta no cuenta; tener o no tener archivo, sí', () {
    final mac = ProjectContentBundle.hashBundle(bundle('/Users/d/sb.jpg'));
    final ipad = ProjectContentBundle.hashBundle(
      bundle('/var/mobile/Containers/x/sb-1234.jpg'),
    );
    final none = ProjectContentBundle.hashBundle(bundle(null));
    expect(mac, ipad);
    expect(mac, isNot(none));
  });

  test('en una lista cuenta cuántos hay', () {
    final two = ProjectContentBundle.hashBundle(
      bundle(null, sketches: '["/a.png","setup:3"]'),
    );
    final twoElsewhere = ProjectContentBundle.hashBundle(
      bundle(null, sketches: '["","setup:3"]'),
    );
    final one = ProjectContentBundle.hashBundle(
      bundle(null, sketches: '["setup:3"]'),
    );
    expect(two, twoElsewhere);
    expect(two, isNot(one));
  });

  test('las huellas guardadas a la manera anterior se siguen reconociendo',
      () {
    final b = bundle('/Users/d/sb.jpg');
    // Sin nada de rutas, como se calculaba antes.
    final before = ProjectContentBundle.hashBundle({
      'shots': [
        {'uid': 'a', 'number': 1},
      ],
    });
    expect(ProjectContentBundle.bundleMatchesHash(b, before), isTrue);
  });
}
