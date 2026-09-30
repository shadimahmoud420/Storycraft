import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User preferences, stored on the device.
@immutable
class AppSettingsData {
  const AppSettingsData({
    this.showWatermark = true,
    this.hijriOffset = 0,
    this.reminderOn = false,
    this.reminderHour = 9,
    this.reminderMinute = 0,
  });

  /// Small "StoryCraft" mark on exported designs.
  final bool showWatermark;

  /// Days added to the Umm al-Qura date to match local moon sighting.
  final int hijriOffset;

  /// Daily "your story of the day is ready" notification.
  final bool reminderOn;
  final int reminderHour;
  final int reminderMinute;

  AppSettingsData copyWith({
    bool? showWatermark,
    int? hijriOffset,
    bool? reminderOn,
    int? reminderHour,
    int? reminderMinute,
  }) =>
      AppSettingsData(
        showWatermark: showWatermark ?? this.showWatermark,
        hijriOffset: hijriOffset ?? this.hijriOffset,
        reminderOn: reminderOn ?? this.reminderOn,
        reminderHour: reminderHour ?? this.reminderHour,
        reminderMinute: reminderMinute ?? this.reminderMinute,
      );
}

class AppSettings extends ValueNotifier<AppSettingsData> {
  AppSettings._() : super(const AppSettingsData());

  static final instance = AppSettings._();

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      value = AppSettingsData(
        showWatermark: p.getBool('watermark') ?? true,
        hijriOffset: p.getInt('hijriOffset') ?? 0,
        reminderOn: p.getBool('reminderOn') ?? false,
        reminderHour: p.getInt('reminderHour') ?? 9,
        reminderMinute: p.getInt('reminderMinute') ?? 0,
      );
    } catch (_) {
      // Defaults are fine (e.g. storage unavailable).
    }
  }

  Future<void> update(AppSettingsData data) async {
    value = data;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('watermark', data.showWatermark);
      await p.setInt('hijriOffset', data.hijriOffset);
      await p.setBool('reminderOn', data.reminderOn);
      await p.setInt('reminderHour', data.reminderHour);
      await p.setInt('reminderMinute', data.reminderMinute);
    } catch (_) {}
  }
}
