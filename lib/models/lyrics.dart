import 'dart:math' as math;

import 'package:flutter/material.dart';

/// How each lyric line enters and plays.
enum LyricEffect {
  /// Fades in while rising slightly.
  fade,

  /// The line is shown, then colored word by word as it is sung.
  karaoke,

  /// Revealed as if written, in the reading direction.
  wipe,

  /// Words appear one after another.
  words,

  /// Pops in with a springy zoom.
  zoom,

  /// Slides in from the side.
  slide,
}

/// One line of the song, with the moment it starts (null until synced).
class LyricLine {
  LyricLine(this.text, [this.startMs]);

  String text;
  int? startMs;
}

/// Look of the lyrics (shared by every line).
@immutable
class LyricsStyle {
  const LyricsStyle({
    this.fontFamily = 'Cairo',
    this.color = Colors.white,
    this.accent = const Color(0xFFFFD166),
    this.effect = LyricEffect.karaoke,
    this.size = 26,
    this.y = 0.72,
    this.box = false,
    this.glow = true,
  });

  final String fontFamily;
  final Color color;

  /// Highlight / glow color.
  final Color accent;
  final LyricEffect effect;

  /// Font size in the 360-wide design space.
  final double size;

  /// Vertical center of the lyrics, 0 (top) – 1 (bottom).
  final double y;

  /// A soft dark box behind the text.
  final bool box;
  final bool glow;

  LyricsStyle copyWith({
    String? fontFamily,
    Color? color,
    Color? accent,
    LyricEffect? effect,
    double? size,
    double? y,
    bool? box,
    bool? glow,
  }) =>
      LyricsStyle(
        fontFamily: fontFamily ?? this.fontFamily,
        color: color ?? this.color,
        accent: accent ?? this.accent,
        effect: effect ?? this.effect,
        size: size ?? this.size,
        y: y ?? this.y,
        box: box ?? this.box,
        glow: glow ?? this.glow,
      );
}

/// When a line is on screen.
@immutable
class LyricTiming {
  const LyricTiming(this.index, this.startMs, this.endMs);

  final int index;
  final int startMs;
  final int endMs;

  int get durationMs => endMs - startMs;
}

/// The visual state of the lyrics at one moment, quantized so identical
/// moments compare equal (the export renders each distinct state once).
@immutable
class LyricsFrame {
  const LyricsFrame(this.line, this.appear, this.leave, this.progress);

  static const steps = 60;

  final int line;

  /// Entrance, exit and effect progress in 0 – [steps].
  final int appear;
  final int leave;
  final int progress;

  double get appearT => appear / steps;
  double get leaveT => leave / steps;
  double get progressT => progress / steps;

  @override
  bool operator ==(Object other) =>
      other is LyricsFrame &&
      other.line == line &&
      other.appear == appear &&
      other.leave == leave &&
      other.progress == progress;

  @override
  int get hashCode => Object.hash(line, appear, leave, progress);
}

class Lyrics {
  Lyrics._();

  /// Splits pasted lyrics into lines (blank lines dropped).
  static List<LyricLine> parse(String text) => [
        for (final l in text.split('\n'))
          if (l.trim().isNotEmpty) LyricLine(l.trim()),
      ];

  /// Start and end of every line within [totalMs]. Lines that are not
  /// synced yet are spread evenly between their synced neighbours.
  static List<LyricTiming> timings(List<LyricLine> lines, int totalMs) {
    final n = lines.length;
    if (n == 0 || totalMs <= 0) return const [];
    // Anchors: synced lines, plus the start (0 ms) and the end.
    final anchors = <(int, double)>[
      if (lines.first.startMs == null) (0, 0),
      for (var i = 0; i < n; i++)
        if (lines[i].startMs != null) (i, lines[i].startMs!.toDouble()),
      (n, totalMs.toDouble()),
    ];
    final starts = List<double>.filled(n, 0);
    for (var a = 0; a + 1 < anchors.length; a++) {
      final (ia, ta) = anchors[a];
      final (ib, tb) = anchors[a + 1];
      for (var k = ia; k < ib && k < n; k++) {
        starts[k] = ta + (tb - ta) * (k - ia) / (ib - ia);
      }
    }
    final out = <LyricTiming>[];
    for (var i = 0; i < n; i++) {
      final start = starts[i].clamp(0, totalMs.toDouble()).round();
      final end = i + 1 < n
          ? starts[i + 1].clamp(0, totalMs.toDouble()).round()
          : totalMs;
      out.add(LyricTiming(i, start, math.max(start, end)));
    }
    return out;
  }

  /// The line on screen at [ms], if any.
  static LyricTiming? activeAt(List<LyricTiming> timings, int ms) {
    for (final t in timings) {
      if (ms >= t.startMs && ms < t.endMs) return t;
    }
    return null;
  }

  /// The visual state at [ms].
  static LyricsFrame? frameAt(
      List<LyricTiming> timings, LyricEffect effect, int ms) {
    final t = activeAt(timings, ms);
    if (t == null || t.durationMs <= 0) return null;
    final lt = (ms - t.startMs).toDouble();
    final dur = t.durationMs.toDouble();
    final appear = lt / math.min(450, dur * 0.4);
    final leave = dur > 700 ? (t.endMs - ms) / 250 : 1.0;
    final progress = switch (effect) {
      LyricEffect.karaoke => lt / (dur * 0.9),
      LyricEffect.wipe => lt / math.min(1300, dur * 0.7),
      LyricEffect.words => lt / (dur * 0.7),
      _ => appear,
    };
    int q(double v) => (v.clamp(0.0, 1.0) * LyricsFrame.steps).round();
    return LyricsFrame(t.index, q(appear), q(leave), q(progress));
  }
}
