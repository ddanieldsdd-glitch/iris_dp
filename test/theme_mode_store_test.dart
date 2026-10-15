import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/theme/theme_mode_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('el tema elegido se recupera al volver a abrir', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await ThemeModeStore.load(), ThemeMode.dark);

    await ThemeModeStore.save(ThemeMode.light);
    expect(await ThemeModeStore.load(), ThemeMode.light);

    await ThemeModeStore.save(ThemeMode.dark);
    expect(await ThemeModeStore.load(), ThemeMode.dark);
  });
}
