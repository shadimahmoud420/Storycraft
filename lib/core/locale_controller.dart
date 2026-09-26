import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the user's language choice. `null` = follow the device.
class LocaleController extends ValueNotifier<Locale?> {
  LocaleController._(super.value);

  static const _key = 'locale';
  static const supported = [Locale('ar'), Locale('en')];

  static Future<LocaleController> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_key);
      return LocaleController._(code == null ? null : Locale(code));
    } catch (_) {
      return LocaleController._(null);
    }
  }

  /// Switches between Arabic and English.
  Future<void> toggle(Locale current) async {
    value = current.languageCode == 'ar' ? const Locale('en') : const Locale('ar');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, value!.languageCode);
    } catch (_) {}
  }
}
