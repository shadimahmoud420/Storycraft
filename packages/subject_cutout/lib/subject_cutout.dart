import 'package:flutter/services.dart';

/// Why a cutout could not be made.
enum CutoutError {
  /// The platform (or OS version) has no on-device segmentation.
  unsupported,

  /// Android only: the ML Kit model is still downloading (first use).
  preparing,

  /// Segmentation ran but found nothing to keep.
  noSubject,

  /// Anything else (decode error, out of memory…).
  failed,
}

class CutoutException implements Exception {
  const CutoutException(this.error);

  final CutoutError error;

  @override
  String toString() => 'CutoutException($error)';
}

/// Separates the main subject (people, pets, objects) from the background,
/// entirely on the device:
/// - iOS 17+: Vision foreground instance mask (any subject);
///   iOS 15–16: Vision person segmentation (people only).
/// - Android: ML Kit subject segmentation (Google Play services).
class SubjectCutout {
  SubjectCutout._();

  static const _channel = MethodChannel('subject_cutout');

  /// Returns a PNG the same size as the input, transparent outside the
  /// subject. Throws [CutoutException].
  static Future<Uint8List> removeBackground(Uint8List imageBytes) async {
    try {
      final out = await _channel.invokeMethod<Uint8List>(
        'removeBackground',
        {'image': imageBytes},
      );
      if (out == null) throw const CutoutException(CutoutError.failed);
      return out;
    } on MissingPluginException {
      throw const CutoutException(CutoutError.unsupported);
    } on PlatformException catch (e) {
      throw CutoutException(switch (e.code) {
        'unsupported' => CutoutError.unsupported,
        'preparing' => CutoutError.preparing,
        'no_subject' => CutoutError.noSubject,
        _ => CutoutError.failed,
      });
    }
  }

  /// Face landmarks of every face found (Android: the most prominent face),
  /// in pixels of the upright image. Each face maps a region name
  /// (`bounds`, `contour`, `leftEye`, `rightEye`, `leftBrow`, `rightBrow`,
  /// `outerLips`, `innerLips`, `nose`, `noseCrest`) to a flat
  /// `[x0, y0, x1, y1, ...]` list (`bounds` is `[left, top, width, height]`).
  /// Send an image without EXIF rotation. Throws [CutoutException].
  static Future<List<Map<String, List<double>>>> detectFaces(
      Uint8List imageBytes) async {
    try {
      final out = await _channel.invokeMethod<List<Object?>>(
        'detectFaces',
        {'image': imageBytes},
      );
      return [
        for (final face in out ?? const [])
          {
            for (final e in (face as Map).entries)
              e.key as String: [
                for (final v in e.value as List) (v as num).toDouble(),
              ],
          },
      ];
    } on MissingPluginException {
      throw const CutoutException(CutoutError.unsupported);
    } on PlatformException catch (e) {
      throw CutoutException(switch (e.code) {
        'unsupported' => CutoutError.unsupported,
        'preparing' => CutoutError.preparing,
        _ => CutoutError.failed,
      });
    }
  }
}
