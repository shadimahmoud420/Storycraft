import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storycraft/services/ads.dart';
import 'package:storycraft/services/app_settings.dart';

void main() {
  test('without ads (Android, tests) the mark hides for good, for free', () async {
    SharedPreferences.setMockInitialValues({});
    expect(Ads.enabled, isFalse);
    await AppSettings.instance.load();
    expect(AppSettings.instance.value.showWatermark, isTrue);
    expect(await AppSettings.instance.hideMark(), RewardResult.earned);
    expect(AppSettings.instance.value.showWatermark, isFalse);
    await AppSettings.instance.load();
    expect(AppSettings.instance.value.showWatermark, isFalse);
  });

  test('the earned day is stored', () async {
    final until = DateTime(2026, 10, 14, 9);
    SharedPreferences.setMockInitialValues({
      'watermark': false,
      'markFreeUntil': until.millisecondsSinceEpoch,
    });
    await AppSettings.instance.load();
    expect(AppSettings.instance.value.markFreeUntil, until);
  });
}
