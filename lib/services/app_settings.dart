import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ads.dart';

/// User preferences, stored on the device.
@immutable
class AppSettingsData {
  const AppSettingsData({
    this.showWatermark = true,
    this.hijriOffset = 0,
    this.reminderOn = false,
    this.reminderHour = 9,
    this.reminderMinute = 0,
    this.markFreeUntil,
  });

  /// Small "StoryCraft" mark on exported designs.
  final bool showWatermark;

  /// Days added to the Umm al-Qura date to match local moon sighting.
  final int hijriOffset;

  /// Daily "your story of the day is ready" notification.
  final bool reminderOn;
  final int reminderHour;
  final int reminderMinute;

  /// Until when the mark stays hidden (earned by watching an ad).
  final DateTime? markFreeUntil;

  AppSettingsData copyWith({
    bool? showWatermark,
    int? hijriOffset,
    bool? reminderOn,
    int? reminderHour,
    int? reminderMinute,
    DateTime? markFreeUntil,
  }) =>
      AppSettingsData(
        showWatermark: showWatermark ?? this.showWatermark,
        hijriOffset: hijriOffset ?? this.hijriOffset,
        reminderOn: reminderOn ?? this.reminderOn,
        reminderHour: reminderHour ?? this.reminderHour,
        reminderMinute: reminderMinute ?? this.reminderMinute,
        markFreeUntil: markFreeUntil ?? this.markFreeUntil,
      );
}

class AppSettings extends ValueNotifier<AppSettingsData> {
  AppSettings._() : super(const AppSettingsData());

  static final instance = AppSettings._();

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final until = p.getInt('markFreeUntil');
      final free = until == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(until);
      // With ads, a hidden mark comes back once the earned day is over.
      final expired =
          Ads.enabled && (free == null || DateTime.now().isAfter(free));
      value = AppSettingsData(
        showWatermark: (p.getBool('watermark') ?? true) || expired,
        markFreeUntil: free,
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
      final free = data.markFreeUntil;
      if (free != null) {
        await p.setInt('markFreeUntil', free.millisecondsSinceEpoch);
      }
    } catch (_) {}
  }

  /// Hides the mark: free without ads, otherwise for a day after a
  /// rewarded ad. Returns false when the viewer closed the ad early.
  Future<bool> hideMark() async {
    if (!Ads.enabled) {
      await update(value.copyWith(showWatermark: false));
      return true;
    }
    if (!await Ads.showRewarded()) return false;
    await update(value.copyWith(
      showWatermark: false,
      markFreeUntil: DateTime.now().add(Ads.markFreeFor),
    ));
    return true;
  }
}
