import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tarteel/src/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('favorites persist by stable IDs', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final store = FavoritesStore(prefs)..load();
    await store.toggleStation('station-1');
    final reloaded = FavoritesStore(prefs)..load();
    expect(reloaded.isStation('station-1'), isTrue);
  });

  test('theme and language preferences persist', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsStore(prefs)..load();
    await settings.setThemeMode(ThemeMode.dark);
    await settings.setLocale(const Locale('en'));
    final reloaded = SettingsStore(prefs)..load();
    expect(reloaded.themeMode, ThemeMode.dark);
    expect(reloaded.locale.languageCode, 'en');
  });
}
