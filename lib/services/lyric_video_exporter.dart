import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_composer/video_composer.dart';

import '../models/lyrics.dart';
import '../widgets/lyrics_painter.dart';

/// Turns a video, a song and synced lyrics into an MP4: the lyric
/// animation is rendered here (same painter as the preview) and the
/// platform composes it over the video with the music.
class LyricVideoExporter {
  LyricVideoExporter._();

  static const fps = 30;

  /// Longest video exported (Instagram stories show up to 60 s).
  static const maxDurationMs = 60000;

  /// Renders the overlay frames into [dir] as `f<index>.png` and returns,
  /// for every frame at [fps], the PNG index (-1 = nothing on screen).
  /// Identical moments share one PNG.
  static Future<List<int>> renderOverlay({
    required Directory dir,
    required int width,
    required int height,
    required List<LyricLine> lines,
    required LyricsStyle style,
    required int durationMs,
    void Function(double progress)? onProgress,
  }) async {
    final timings = Lyrics.timings(lines, durationMs);
    final count = (durationMs * fps / 1000).ceil();
    final rendered = <LyricsFrame, int>{};
    final map = <int>[];
    for (var f = 0; f < count; f++) {
      final ms = f * 1000 ~/ fps;
      var frame = Lyrics.frameAt(timings, style.effect, ms);
      if (frame == null || lines[frame.line].text.isEmpty) {
        if (!lyricsHaveBackdrop(style)) {
          map.add(-1);
          continue;
        }
        frame = LyricsFrame.none;
      }
      final known = rendered[frame];
      if (known != null) {
        map.add(known);
        continue;
      }
      final index = rendered.length;
      final recorder = ui.PictureRecorder();
      paintLyrics(
        Canvas(recorder),
        Size(width.toDouble(), height.toDouble()),
        text: frame.line < 0 ? '' : lines[frame.line].text,
        style: style,
        frame: frame,
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(width, height);
      picture.dispose();
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await File('${dir.path}/f$index.png')
          .writeAsBytes(png!.buffer.asUint8List());
      rendered[frame] = index;
      map.add(index);
      onProgress?.call(f / count);
    }
    onProgress?.call(1);
    return map;
  }

  /// Full export; returns the MP4 path. [onProgress] reports the overlay
  /// rendering (0 – 1); composing follows with no progress information.
  static Future<String> export({
    required String videoPath,
    required VideoInfo info,
    String? audioPath,
    int audioStartMs = 0,
    required List<LyricLine> lines,
    required LyricsStyle style,
    void Function(double progress)? onProgress,
  }) async {
    final tmp = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final dir = await Directory('${tmp.path}/lyrics_$stamp').create();
    try {
      final durationMs = info.durationMs.clamp(1, maxDurationMs);
      final (w, h) = VideoComposer.outputSize(info.width, info.height);
      final frames = await renderOverlay(
        dir: dir,
        width: w,
        height: h,
        lines: lines,
        style: style,
        durationMs: durationMs,
        onProgress: onProgress,
      );
      final output = '${tmp.path}/StoryCraft_lyrics_$stamp.mp4';
      await VideoComposer.compose(
        videoPath: videoPath,
        durationMs: durationMs,
        audioPath: audioPath,
        audioStartMs: audioStartMs,
        overlayDir: dir.path,
        overlayFps: fps,
        overlayFrames: frames,
        outputWidth: w,
        outputHeight: h,
        outputPath: output,
      );
      return output;
    } finally {
      dir.delete(recursive: true).ignore();
    }
  }
}
