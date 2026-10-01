import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Size (as displayed, rotation applied) and length of a video.
class VideoInfo {
  const VideoInfo(this.width, this.height, this.durationMs);

  final int width;
  final int height;
  final int durationMs;
}

class ComposeException implements Exception {
  const ComposeException(this.message);

  final String message;

  @override
  String toString() => 'ComposeException($message)';
}

/// Builds an MP4 from a video (its own sound removed), an optional music
/// track and an animated transparent overlay, entirely on the device
/// (AVFoundation on iOS, Media3 Transformer on Android).
///
/// The overlay is a folder of PNGs `f<index>.png` (each the size of the
/// output) plus [overlayFrames]: for every overlay frame at [overlayFps],
/// the PNG index to draw, or -1 for nothing. Identical moments share one
/// PNG, so a mostly static overlay needs only a few files.
class VideoComposer {
  VideoComposer._();

  static const _channel = MethodChannel('video_composer');

  static Future<VideoInfo> probe(String videoPath) async {
    try {
      final r = await _channel
          .invokeMapMethod<String, Object?>('probe', {'video': videoPath});
      if (r == null) throw const ComposeException('probe failed');
      return VideoInfo(
        (r['width'] as num).toInt(),
        (r['height'] as num).toInt(),
        (r['durationMs'] as num).toInt(),
      );
    } on PlatformException catch (e) {
      throw ComposeException(e.message ?? e.code);
    } on MissingPluginException {
      throw const ComposeException('unsupported');
    }
  }

  /// Output size for a video of [width] x [height]: the long side is at
  /// most 1920 and both sides are even (encoders require it).
  static (int, int) outputSize(int width, int height) {
    final long = width > height ? width : height;
    final scale = long > 1920 ? 1920 / long : 1.0;
    int even(double v) => (v / 2).round() * 2;
    return (even(width * scale), even(height * scale));
  }

  /// Writes the result to [outputPath] (.mp4).
  static Future<void> compose({
    required String videoPath,
    required int durationMs,
    String? audioPath,
    int audioStartMs = 0,
    required String overlayDir,
    required int overlayFps,
    required List<int> overlayFrames,
    required int outputWidth,
    required int outputHeight,
    required String outputPath,
  }) async {
    try {
      await _channel.invokeMethod<void>('compose', {
        'video': videoPath,
        'durationMs': durationMs,
        'audio': audioPath,
        'audioStartMs': audioStartMs,
        'overlayDir': overlayDir,
        'overlayFps': overlayFps,
        'overlayFrames': Int32List.fromList(overlayFrames),
        'width': outputWidth,
        'height': outputHeight,
        'output': outputPath,
      });
    } on PlatformException catch (e) {
      throw ComposeException(e.message ?? e.code);
    } on MissingPluginException {
      throw const ComposeException('unsupported');
    }
  }
}
