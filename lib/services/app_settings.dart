import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translator/translator.dart';
import 'translations.dart';

/// Global app settings — language, theme, land unit.
/// Uses ValueNotifier so any widget can listen with ValueListenableBuilder.
class AppSettings {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  final _translator = GoogleTranslator();

  // ── Language (en | bn) ─────────────────────────────────────
  final ValueNotifier<String> language = ValueNotifier('en');

  // ── Theme ──────────────────────────────────────────────────
  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.light);

  // ── Land unit ──────────────────────────────────────────────
  final ValueNotifier<String> landUnit = ValueNotifier('Bigha');

  /// A combined listener that notifies when ANY setting changes.
  Listenable get updateListener => Listenable.merge([language, themeMode, landUnit]);

  // Helpers
  bool get isBengali => language.value == 'bn';
  bool get isDark => themeMode.value == ThemeMode.dark;
  bool get isBigha => landUnit.value == 'Bigha';

  /// Initialization called in main()
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    language.value = prefs.getString('language') ?? 'en';
    final themeStr = prefs.getString('themeMode') ?? 'light';
    themeMode.value = themeStr == 'dark' ? ThemeMode.dark : ThemeMode.light;
    landUnit.value = prefs.getString('landUnit') ?? 'Bigha';
  }

  Future<void> setLanguage(String lang) async {
    language.value = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', lang);
  }

  Future<void> setTheme(ThemeMode mode) async {
    themeMode.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode == ThemeMode.dark ? 'dark' : 'light');
  }

  Future<void> setUnit(String unit) async {
    landUnit.value = unit;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('landUnit', unit);
  }

  Future<void> toggleLanguage() => setLanguage(isBengali ? 'en' : 'bn');
  Future<void> toggleTheme() => setTheme(isDark ? ThemeMode.light : ThemeMode.dark);
  Future<void> toggleUnit() => setUnit(isBigha ? 'Acre' : 'Bigha');

  /// Translate a key using the current language.
  String t(String en, String bn) => isBengali ? bn : en;

  // Simple key-based translation for common UI elements
  String translate(String key) {
    if (isBengali) {
      return AppTranslations.bn[key] ?? AppTranslations.en[key] ?? key;
    }
    return AppTranslations.en[key] ?? key;
  }

  /// AI Fallback translation (Async)
  Future<String> translateAsync(String text) async {
    if (!isBengali) return text;
    // Check dictionary first
    final dict = translate(text);
    if (dict != text) return dict;

    try {
      final res = await _translator.translate(text, from: 'en', to: 'bn');
      return res.text;
    } catch (e) {
      return text;
    }
  }

  String translateCrop(String crop) {
    return crop; 
  }

  String translatePhase(String phase) {
    return phase;
  }

  String translatePhaseSubtitle(String sub) {
    return sub;
  }

  String translatePlanDescription(String desc) {
    return desc; 
  }

  String translatePrice(String price) {
    if (!isBengali) return price;
    String res = price.replaceAll('kg', 'কেজি').replaceAll('mon', 'মণ');
    const eng = ['0','1','2','3','4','5','6','7','8','9'];
    const bng = ['০','১','২','৩','৪','৫','৬','৭','৮','৯'];
    for (int i=0; i<10; i++) {
      res = res.replaceAll(eng[i], bng[i]);
    }
    return res;
  }
}
