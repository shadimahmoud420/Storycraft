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

  /// Cinematic: comes into focus from a soft blur while settling.
  soft,
}

/// One line of the song, with the moment it starts (null until synced).
class LyricLine {
  LyricLine(this.text, [this.startMs, this.endMs]);

  String text;
  int? startMs;

  /// When the line leaves the screen (automatic captions end at the last
  /// sung word); otherwise it stays until the next line.
  int? endMs;

  Map<String, Object?> toJson() => {'t': text, 's': startMs, 'e': endMs};

  factory LyricLine.fromJson(Map<String, Object?> j) => LyricLine(
        j['t'] as String? ?? '',
        (j['s'] as num?)?.toInt(),
        (j['e'] as num?)?.toInt(),
      );
}

/// A recognized word and its timing in the song excerpt.
typedef CaptionWord = ({String text, int startMs, int durationMs});

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
    this.bold = true,
    this.shade = false,
    this.credit = '',
  });

  /// Cinematic look: calligraphy, soft glow, focus-in, darkened bottom.
  static const cinematic = LyricsStyle(
    fontFamily: 'Aref Ruqaa',
    color: Colors.white,
    accent: Color(0xFFFFF4E0),
    effect: LyricEffect.soft,
    size: 46,
    y: 0.7,
    bold: false,
    shade: true,
  );

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

  /// Bold weight (calligraphy fonts look best regular).
  final bool bold;

  /// A soft dark gradient over the bottom of the video.
  final bool shade;

  /// Small line under the lyrics (song · artist), always shown.
  final String credit;

  Map<String, Object?> toJson() => {
        'font': fontFamily,
        'color': color.toARGB32(),
        'accent': accent.toARGB32(),
        'effect': effect.name,
        'size': size,
        'y': y,
        'box': box,
        'glow': glow,
        'bold': bold,
        'shade': shade,
        'credit': credit,
      };

  factory LyricsStyle.fromJson(Map<String, Object?> j) {
    const d = LyricsStyle.cinematic;
    return LyricsStyle(
      fontFamily: j['font'] as String? ?? d.fontFamily,
      color: Color((j['color'] as num?)?.toInt() ?? d.color.toARGB32()),
      accent: Color((j['accent'] as num?)?.toInt() ?? d.accent.toARGB32()),
      effect: LyricEffect.values.asNameMap()[j['effect']] ?? d.effect,
      size: (j['size'] as num?)?.toDouble() ?? d.size,
      y: (j['y'] as num?)?.toDouble() ?? d.y,
      box: j['box'] as bool? ?? d.box,
      glow: j['glow'] as bool? ?? d.glow,
      bold: j['bold'] as bool? ?? d.bold,
      shade: j['shade'] as bool? ?? d.shade,
      credit: j['credit'] as String? ?? '',
    );
  }

  LyricsStyle copyWith({
    String? fontFamily,
    Color? color,
    Color? accent,
    LyricEffect? effect,
    double? size,
    double? y,
    bool? box,
    bool? glow,
    bool? bold,
    bool? shade,
    String? credit,
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
        bold: bold ?? this.bold,
        shade: shade ?? this.shade,
        credit: credit ?? this.credit,
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

  /// No lyric on screen (only the shade / credit, if any).
  static const none = LyricsFrame(-1, 0, 0, 0);

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
      var end = i + 1 < n
          ? starts[i + 1].clamp(0, totalMs.toDouble()).round()
          : totalMs;
      final own = lines[i].endMs;
      if (own != null && own > start) end = math.min(end, own);
      out.add(LyricTiming(i, start, math.max(start, end)));
    }
    return out;
  }

  /// Arabic-aware word normalization for matching: no diacritics or
  /// tatweel, unified alef / ya / ta marbuta forms, letters only.
  static String normalize(String word) {
    var w = word.toLowerCase();
    w = w.replaceAll(RegExp('[ً-ٰٟـ]'), '');
    w = w.replaceAll(RegExp('[آأإٱ]'), 'ا');
    w = w.replaceAll('ى', 'ي').replaceAll('ة', 'ه');
    w = w.replaceAll('ؤ', 'و').replaceAll('ئ', 'ي');
    return w.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');
  }

  /// 0 – 1 similarity of two normalized words (1 - edit distance / length).
  static double similarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    if (a == b) return 1;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        cur[j] = math.min(math.min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
      }
      prev = cur;
    }
    return 1 - prev[b.length] / math.max(a.length, b.length);
  }

  /// Times the user's own (correct) [lines] from recognized [words]: the
  /// two word sequences are aligned in order, tolerating recognition
  /// mistakes, and each line starts at its first matched word. Lines with
  /// no match keep no time and are spread between their neighbours.
  /// Returns how many lines were timed.
  static int align(List<LyricLine> lines, List<CaptionWord> words,
      {double minSimilarity = 0.5}) {
    // The lyric words, each remembering its line.
    final lyric = <(String, int, int)>[]; // (normalized, line, index in line)
    for (var l = 0; l < lines.length; l++) {
      final parts = lines[l].text.split(RegExp(r'\s+'));
      var k = 0;
      for (final p in parts) {
        final n = normalize(p);
        if (n.isNotEmpty) lyric.add((n, l, k++));
      }
    }
    final heard = [for (final w in words) normalize(w.text)];
    final n = lyric.length, m = heard.length;
    for (final l in lines) {
      l
        ..startMs = null
        ..endMs = null;
    }
    if (n == 0 || m == 0) return 0;

    // Best in-order matching (longest common subsequence, weighted by
    // similarity).
    final score = List.generate(n + 1, (_) => List<double>.filled(m + 1, 0));
    for (var i = 1; i <= n; i++) {
      for (var j = 1; j <= m; j++) {
        final sim = similarity(lyric[i - 1].$1, heard[j - 1]);
        var best = math.max(score[i - 1][j], score[i][j - 1]);
        if (sim >= minSimilarity) best = math.max(best, score[i - 1][j - 1] + sim);
        score[i][j] = best;
      }
    }
    final match = List<int?>.filled(n, null); // lyric word -> heard word
    var i = n, j = m;
    while (i > 0 && j > 0) {
      final sim = similarity(lyric[i - 1].$1, heard[j - 1]);
      if (sim >= minSimilarity &&
          (score[i][j] - (score[i - 1][j - 1] + sim)).abs() < 1e-9) {
        match[i - 1] = j - 1;
        i--;
        j--;
      } else if (score[i - 1][j] >= score[i][j - 1]) {
        i--;
      } else {
        j--;
      }
    }

    // Line times from their matched words.
    const wordMs = 380; // typical sung word, to back off unmatched words
    var timed = 0;
    var lastStart = -1;
    for (var l = 0; l < lines.length; l++) {
      int? start, end;
      for (var x = 0; x < n; x++) {
        if (lyric[x].$2 != l || match[x] == null) continue;
        final w = words[match[x]!];
        start ??= math.max(0, w.startMs - lyric[x].$3 * wordMs);
        end = w.startMs + w.durationMs;
      }
      if (start == null) continue;
      if (start <= lastStart) start = lastStart + 1;
      lines[l]
        ..startMs = start
        ..endMs = end! + 700;
      lastStart = start;
      timed++;
    }
    return timed;
  }

  /// Groups recognized words into caption lines: a new line after a pause,
  /// or when the line gets long. Each line keeps its words' timing.
  static List<LyricLine> fromWords(List<CaptionWord> words,
      {int maxWords = 5, int maxChars = 30, int pauseMs = 650}) {
    final lines = <LyricLine>[];
    var current = <CaptionWord>[];
    void flush() {
      if (current.isEmpty) return;
      final last = current.last;
      lines.add(LyricLine(
        current.map((w) => w.text).join(' '),
        current.first.startMs,
        last.startMs + last.durationMs + 600,
      ));
      current = [];
    }

    for (final w in words) {
      final text = w.text.trim();
      if (text.isEmpty) continue;
      if (current.isNotEmpty) {
        final prev = current.last;
        final gap = w.startMs - (prev.startMs + prev.durationMs);
        final length =
            current.fold<int>(0, (a, x) => a + x.text.length + 1) + text.length;
        if (gap > pauseMs || current.length >= maxWords || length > maxChars) {
          flush();
        }
      }
      current.add((text: text, startMs: w.startMs, durationMs: w.durationMs));
    }
    flush();
    return lines;
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
    final entrance = effect == LyricEffect.soft ? 800 : 450;
    final appear = lt / math.min(entrance, dur * 0.4);
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
