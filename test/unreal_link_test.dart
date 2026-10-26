import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iris_dp/features/unreal_link/unreal_link.dart';
import 'package:iris_dp/features/unreal_link/unreal_stage_payload.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _fixture({
  String id = 'L1',
  List<double> pos = const [1, 2, 3],
  List<double> aim = const [1, 2, 0],
  double cd = 12000,
  double beam = 30,
  double sizeM = 0.2,
  bool on = true,
}) => {
  'id': id,
  'name': 'Fresnel',
  'pos': pos,
  'aim': aim,
  'beamDeg': beam,
  'cct': 3200,
  'on': on,
  'source': {'cd': cd, 'beamDeg': beam, 'cct': 3200, 'sizeM': sizeM},
};

void main() {
  group('UnrealStagePayload', () {
    test('metros de la escena a centímetros de Unreal, con la y al revés', () {
      expect(UnrealStagePayload.loc([1.5, 2, 3]), [150, -200, 300]);
    });

    test('un foco que mira hacia abajo tiene pitch −90', () {
      final l = UnrealStagePayload.light(_fixture())!;
      expect(l['rot'][0], -90);
      expect(l['kind'], 'spot');
      expect(l['cd'], 12000);
    });

    test('yaw: hacia +x de la escena es 0; hacia +y de la escena es −90', () {
      expect(UnrealStagePayload.rotToward(1, 0, 0), [0, 0, 0]);
      expect(UnrealStagePayload.rotToward(0, 1, 0)[1], -90);
    });

    test('el haz cae entre el cono interior y el exterior', () {
      final l = UnrealStagePayload.light(_fixture(beam: 40))!;
      expect(((l['innerDeg'] as num) + (l['outerDeg'] as num)) / 2, 20);
    });

    test('las fuentes grandes son rectangulares y las omni puntuales', () {
      expect(UnrealStagePayload.light(_fixture(sizeM: 0.6))!['kind'], 'rect');
      expect(UnrealStagePayload.light(_fixture(beam: 360))!['kind'], 'point');
    });

    test('el sol: la luz va al contrario de hacia donde está', () {
      final s = UnrealStagePayload.sun({
        'dir': [0, 0, 1],
        'lux': 80000,
        'cct': 5400,
      })!;
      expect(s['rot'][0], -90);
      expect(s['lux'], 80000);
    });

    test('diff: entera la primera vez, luego solo lo cambiado', () {
      final a = UnrealStagePayload.build({
        'fixtures': [_fixture(), _fixture(id: 'L2')],
      });
      expect(UnrealStagePayload.diff(null, a)!['full'], true);
      expect(UnrealStagePayload.diff(a, a), isNull);

      final b = UnrealStagePayload.build({
        'fixtures': [_fixture(cd: 6000)],
      });
      final patch = UnrealStagePayload.diff(a, b)!;
      expect([for (final l in patch['lights']) l['id']], ['L1']);
      expect(patch['remove'], ['L2']);
      expect(patch.containsKey('sun'), isFalse);
    });
  });

  group('UnrealLink', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('llama a IrisStageLink con application/json sin charset', () async {
      final calls = <Map<String, dynamic>>[];
      final client = MockClient((req) async {
        expect(req.method, 'PUT');
        expect(req.url.path, '/remote/object/call');
        expect(req.headers['Content-Type'], 'application/json');
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        calls.add(body);
        expect(body['objectPath'], UnrealLink.objectPath);
        final result = body['functionName'] == 'Ping'
            ? {'ok': true, 'version': 1, 'engine': '5.5.4-x'}
            : {'ok': true, 'lights': 1, 'ms': 1.0};
        return http.Response(jsonEncode({'ReturnValue': jsonEncode(result)}), 200);
      });
      final link = UnrealLink(client: client);
      link.offer({
        'fixtures': [_fixture()],
      });
      expect(await link.connect(host: '127.0.0.1'), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(link.engine, '5.5.4-x');
      expect([for (final c in calls) c['functionName']], ['Ping', 'ApplyScene']);
      final payload = jsonDecode(calls.last['parameters']['payload'] as String);
      expect(payload['full'], true);
      expect(payload['lights'].single['id'], 'L1');

      // Sin cambios no se manda nada; con uno, solo ese.
      link.offer({
        'fixtures': [_fixture()],
      });
      await Future<void>.delayed(Duration.zero);
      expect(calls, hasLength(2));
      link.offer({
        'fixtures': [_fixture(on: false)],
      });
      await Future<void>.delayed(Duration.zero);
      expect(calls, hasLength(3));
      final patch = jsonDecode(calls.last['parameters']['payload'] as String);
      expect(patch.containsKey('full'), isFalse);
      expect(patch['lights'].single['on'], false);
    });

    test('sin el plugin en Unreal explica qué falta', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'errorMessage':
                'Object: ${UnrealLink.objectPath} does not exist.',
          }),
          400,
        ),
      );
      final link = UnrealLink(client: client);
      expect(await link.connect(host: '127.0.0.1'), isFalse);
      expect(link.state, UnrealLinkState.error);
      expect(link.error, contains('IRIS Stage Link'));
    });
  });
}
