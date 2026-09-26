import 'package:flutter/services.dart';

/// Opens Instagram's Story composer with an image as the background.
///
/// Uses Meta's official "Sharing to Stories" integration:
/// https://developers.facebook.com/docs/instagram-platform/sharing-to-stories
class InstagramStoryShare {
  InstagramStoryShare._();

  static const _channel = MethodChannel('instagram_story_share');

  /// Returns true if Instagram was opened with the image.
  /// [appId] is your Meta (Facebook) App ID.
  static Future<bool> shareBackgroundImage({
    required String imagePath,
    required String appId,
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>('shareBackgroundImage', {
        'imagePath': imagePath,
        'appId': appId,
      });
      return ok ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
