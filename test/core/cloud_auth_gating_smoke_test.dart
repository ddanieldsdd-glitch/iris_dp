import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iris_dp/core/cloud/cloud_providers.dart';
import 'package:iris_dp/core/cloud/cloud_runtime_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CloudRuntimeConfig.load();
  });

  test('sin nube activa, providers de auth/cliente quedan desactivados', () {
    expect(CloudRuntimeConfig.isActive, isFalse);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(isCloudModeProvider), isFalse);
    expect(container.read(supabaseClientProvider), isNull);
    expect(container.read(currentUserProvider), isNull);
  });
}
