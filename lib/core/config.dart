/// App-wide configuration.
class AppConfig {
  AppConfig._();

  static const appName = 'StoryCraft';

  /// Meta (Facebook) App ID. Instagram requires it to accept images shared
  /// straight to Stories. Create a free app at https://developers.facebook.com
  /// and paste its App ID here. While empty, the app falls back to the
  /// system share sheet (the user can still pick Instagram from there).
  static const facebookAppId = '';

  /// Story canvas in logical pixels. Exported at 3x => 1080 x 1920,
  /// the exact size Instagram Stories use (9:16).
  static const canvasWidth = 360.0;
  static const canvasHeight = 640.0;
  static const exportPixelRatio = 3.0;

  /// Longest edge kept for imported photos (keeps processing fast and
  /// memory-safe on older phones while staying sharper than 1920 px).
  static const maxImageEdge = 2400;

  static const privacyPolicyUrl = 'https://shadimahmoud420.github.io/Storycraft/privacy-policy.html';
}
