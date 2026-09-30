import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/date_text.dart';
import '../data/daily_texts.dart';
import '../data/fonts.dart';
import '../data/occasions.dart';
import '../models/story_background.dart';
import '../models/story_layer.dart';

/// A generated "story of the day": editable layers over a background.
class DailyStory {
  const DailyStory({
    required this.date,
    required this.info,
    required this.text,
    required this.label,
    required this.background,
    required this.layers,
  });

  final DateTime date;
  final DayInfo info;
  final DailyText text;
  final String label;
  final StoryBackground background;
  final List<StoryLayer> layers;
}

class _Palette {
  const _Palette(this.bg, this.acc, this.txt, this.sub, {required this.dark});

  final List<Color> bg;
  final Color acc, txt, sub;
  final bool dark;
}

enum _Layout { frame, pill, number, badge, card }

enum _Pattern { none, stars, bokeh, waves, rays, dots }

/// Builds a different design every day from layouts, palettes, patterns,
/// fonts and texts. Everything is picked from the date, so everyone sees
/// the same story on the same day, and [variant] / [textShift] give
/// endless alternatives ("another design", "another text").
class DailyStoryGenerator {
  DailyStoryGenerator._();

  static const _palettes = <_Palette>[
    _Palette([Color(0xFF083A34), Color(0xFF0A263C), Color(0xFF061428)], Color(0xFFDEB860), Colors.white, Color(0xFFC8DED7), dark: true),
    _Palette([Color(0xFFFFE0C4), Color(0xFFFFBABA), Color(0xFFEC96BE)], Color(0xFF963C6E), Color(0xFF5A1E46), Color(0xFFAA5A82), dark: false),
    _Palette([Color(0xFF16141A), Color(0xFF0E0D11), Color(0xFF08080A)], Color(0xFFDEB860), Color(0xFFF0E6D2), Color(0xFFBEAA82), dark: true),
    _Palette([Color(0xFF241254), Color(0xFF582896), Color(0xFFC85AA0)], Color(0xFFFFD678), Colors.white, Color(0xFFE6D2FF), dark: true),
    _Palette([Color(0xFFE8F4EE), Color(0xFFCEE8DE), Color(0xFFAAD4C8)], Color(0xFF146E5A), Color(0xFF143C37), Color(0xFF3C7869), dark: false),
    _Palette([Color(0xFFFAF0DE), Color(0xFFF0DEC4), Color(0xFFE2C8AA)], Color(0xFF965A28), Color(0xFF50321E), Color(0xFF8C6446), dark: false),
    _Palette([Color(0xFF0C1E46), Color(0xFF1E468C), Color(0xFF5096D2)], Colors.white, Colors.white, Color(0xFFC8E1FF), dark: true),
    _Palette([Color(0xFF2B0F1E), Color(0xFF5A1E3C), Color(0xFF8C2D50)], Color(0xFFFFC8A0), Colors.white, Color(0xFFF0C8D2), dark: true),
    _Palette([Color(0xFFF3EEFF), Color(0xFFE2D8FF), Color(0xFFCBB8F5)], Color(0xFF5B3FB5), Color(0xFF2E2257), Color(0xFF6A5A9A), dark: false),
    _Palette([Color(0xFFFFF1E6), Color(0xFFFFD2BF), Color(0xFFFF9E8A)], Color(0xFFB2413A), Color(0xFF5A1E1E), Color(0xFF9A4A40), dark: false),
  ];

  /// Palettes that suit each layout (the big gold number needs a dark one).
  static const _layoutPalettes = {
    _Layout.frame: [0, 5, 7, 4, 3, 8],
    _Layout.pill: [1, 9, 3, 8, 6],
    _Layout.number: [2, 0, 7, 3],
    _Layout.badge: [6, 4, 9, 7, 1, 5],
    _Layout.card: [3, 2, 0, 6, 7],
  };

  static const _titleFonts = ['Aref Ruqaa', 'Lemonada', 'Reem Kufi', 'Rakkas', 'El Messiri'];
  static const _sacredFonts = ['Amiri', 'Aref Ruqaa', 'El Messiri', 'Scheherazade New'];
  static const _plainFonts = ['El Messiri', 'Cairo', 'Reem Kufi', 'Lemonada', 'Amiri'];

  static const labels = {
    DailyCategory.dua: 'دعاء اليوم',
    DailyCategory.dhikr: 'ذكر اليوم',
    DailyCategory.ayah: 'آية اليوم',
    DailyCategory.wisdom: 'حكمة اليوم',
    DailyCategory.quote: 'اقتباس اليوم',
  };

  static const _rotation = [
    DailyCategory.dua,
    DailyCategory.wisdom,
    DailyCategory.dhikr,
    DailyCategory.quote,
    DailyCategory.ayah,
  ];

  /// Days since 2024-01-01 (stable across time zones and DST).
  static int dayIndex(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day)
          .difference(DateTime.utc(2024))
          .inDays;

  /// The text for [date]: occasion texts first (in auto mode), otherwise
  /// the category rotation. Repeats only after hundreds of days.
  static (DailyText, String) pickText(DateTime date, DayInfo info,
      {DailyCategory? category, int shift = 0}) {
    final day = dayIndex(date);
    if (category == null && info.texts != null) {
      final list = info.texts!;
      return (list[(day + shift) % list.length], info.textLabel ?? 'جمعة مباركة');
    }
    final cat = category ?? _rotation[day % _rotation.length];
    final list = DailyTexts.of(cat);
    final stride = [17, 13, 11, 7, 3].firstWhere((p) => list.length % p != 0);
    final k = (category == null ? day ~/ _rotation.length : day) + shift;
    return (list[(k * stride) % list.length], labels[cat]!);
  }

  static bool _sacred(String label) =>
      !label.contains('حكمة') && !label.contains('اقتباس');

  static DailyStory build(
    DateTime date, {
    int variant = 0,
    int textShift = 0,
    DailyCategory? category,
    bool watermark = true,
    DateTime? now,
  }) {
    final info = DayInfo.of(date);
    final (text, label) =
        pickText(date, info, category: category, shift: textShift);
    final day = dayIndex(date);

    final layout = _Layout.values[(day * 3 + variant) % _Layout.values.length];
    final options = _layoutPalettes[layout]!;
    final pal = _palettes[options[(day + variant * 2) % options.length]];
    final pattern = _Pattern.values[(day * 2 + variant * 3) % _Pattern.values.length];
    final titleFont = _titleFonts[(day + variant) % _titleFonts.length];
    final bodyFonts = _sacred(label) ? _sacredFonts : _plainFonts;
    final bodyFont = bodyFonts[(day * 7 + variant) % bodyFonts.length];

    final b = _Builder(pal, titleFont, bodyFont, date);
    final headline = info.title ?? DayInfo.greeting(now ?? DateTime.now());
    final limit = info.tag != null ? 468.0 : 500.0;

    // Shrink the text until everything fits above the tag/watermark.
    for (var scale = 1.0; ; scale *= 0.9) {
      b.reset(scale);
      if (pattern != _Pattern.none) b.pattern(pattern, day);
      switch (layout) {
        case _Layout.frame:
          b.frame(info, headline, text, label);
        case _Layout.pill:
          b.pill(info, headline, text, label, now ?? DateTime.now());
        case _Layout.number:
          b.number(text, label);
        case _Layout.badge:
          b.badge(text, label);
        case _Layout.card:
          b.card(headline, text, label);
      }
      if (b.bottom <= limit || scale < 0.5) break;
    }
    if (info.tag != null) b.tag(info.tag!);
    if (watermark) b.watermark();

    return DailyStory(
      date: date,
      info: info,
      text: text,
      label: label,
      background: StoryBackground.gradient(pal.bg),
      layers: b.layers,
    );
  }
}

class _Builder {
  _Builder(this.p, this.titleFont, this.bodyFont, this.date);

  final _Palette p;
  final DateTime date;
  final String titleFont;
  final String bodyFont;
  final layers = <StoryLayer>[];
  double scale = 1;
  double bottom = 0;
  int _id = 0;

  static const w = AppConfig.canvasWidth;
  static const h = AppConfig.canvasHeight;
  static const cx = w / 2;

  void reset(double s) {
    layers.clear();
    scale = s;
    bottom = 0;
  }

  StoryLayer _layer(LayerKind kind) =>
      StoryLayer(id: 'daily${_id++}', kind: kind);

  /// Adds a text block whose top is at [top]; returns its bottom.
  double text(
    String value, {
    required double top,
    required String font,
    required double size,
    Color? color,
    TextFill fill = TextFill.solid,
    String? template,
    double lineHeight = 1.35,
    bool scaled = true,
  }) {
    // Live-date layers are measured (and saved) with the story's date.
    if (template != null) value = DateText.resolve(template, date);
    final l = _layer(LayerKind.text)
      ..text = value
      ..template = template
      ..font = StoryFonts.byFamily(font)
      ..fontSize = scaled ? size * scale : size
      ..color = color ?? p.txt
      ..fill = fill
      ..lineHeight = lineHeight;
    final tp = TextPainter(
      text: TextSpan(text: value, style: l.textStyle()),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
    )..layout(maxWidth: AppConfig.canvasWidth - 48);
    final height = tp.height + 12;
    tp.dispose();
    l.position = Offset(cx, top + height / 2);
    layers.add(l);
    bottom = top + height;
    return bottom;
  }

  void ornament(OrnamentKind kind, Offset center, double width,
      {double height = 0, Color? color, bool locked = false, int seed = 0}) {
    layers.add(_layer(LayerKind.ornament)
      ..ornament = kind
      ..position = center
      ..size = width
      ..height = height
      ..color = color ?? p.acc
      ..locked = locked
      ..seed = seed);
  }

  TextFill get accentFill =>
      p.dark && p.acc.computeLuminance() > 0.35 && p.acc != Colors.white
          ? TextFill.gold
          : TextFill.solid;

  Color get ink => p.dark ? Colors.white : Colors.black;

  void pattern(_Pattern kind, int seed) {
    final (k, color) = switch (kind) {
      _Pattern.stars => (OrnamentKind.stars, ink.withValues(alpha: 0.06)),
      _Pattern.bokeh => (OrnamentKind.bokeh, p.acc.withValues(alpha: 0.32)),
      _Pattern.waves => (OrnamentKind.waves, p.acc.withValues(alpha: 0.10)),
      _Pattern.rays => (OrnamentKind.rays, ink.withValues(alpha: 0.05)),
      _Pattern.dots => (OrnamentKind.dots, ink.withValues(alpha: 0.09)),
      _Pattern.none => (OrnamentKind.stars, Colors.transparent),
    };
    ornament(k, const Offset(cx, h / 2), w,
        height: h, color: color, locked: true, seed: seed);
  }

  double body(DailyText t, String label, double top,
      {Color? color, Color? sourceColor, Color? labelColor,
      TextFill fill = TextFill.solid, double size = 25}) {
    var y = text(label, top: top, font: 'El Messiri', size: 16,
            color: labelColor ?? p.acc) + 8;
    y = text(t.text, top: y, font: bodyFont, size: size, color: color, fill: fill,
        lineHeight: 1.55);
    if (t.source != null) {
      y = text('[ ${t.source} ]', top: y + 2, font: 'Amiri', size: 14,
          color: sourceColor ?? p.sub);
    }
    return y;
  }

  // --- Layouts (canvas 360 x 640) ------------------------------------------

  void frame(DayInfo info, String headline, DailyText t, String label) {
    ornament(OrnamentKind.frame, const Offset(cx, h / 2), w - 40, height: h - 44, locked: true);
    ornament(OrnamentKind.crescent, Offset(cx, 78 * scale + 8), 30);
    var y = text(info.title ?? '', top: 92 * scale + 8, font: titleFont, size: 46,
        color: p.acc, fill: accentFill,
        template: info.title == null ? '{weekday}' : null);
    y = text('', top: y, font: 'El Messiri', size: 20,
        template: info.title == null ? '{greg}' : '{weekday} · {greg}');
    y = text('', top: y - 4, font: 'El Messiri', size: 16, color: p.sub, template: '{hijri}');
    ornament(OrnamentKind.divider, Offset(cx, y + 14), 150, height: 12);
    body(t, label, y + 30, size: 25);
  }

  void pill(DayInfo info, String headline, DailyText t, String label, DateTime now) {
    final evening = now.hour >= 17 || now.hour < 4;
    ornament(evening ? OrnamentKind.crescent : OrnamentKind.sun,
        Offset(cx, 110 * scale), evening ? 60 : 140,
        color: evening ? p.acc : const Color(0xFFFFC76A));
    var y = text(headline, top: 175 * scale, font: titleFont, size: 42,
        color: p.acc, fill: accentFill);
    final pillTop = y + 12;
    ornament(OrnamentKind.pill, Offset(cx, pillTop + 34), 270,
        height: 68, color: Colors.white.withValues(alpha: 0.92));
    text('', top: pillTop + 5, font: 'Cairo', size: 17, color: const Color(0xFF3C2846),
        template: '{weekday} · {greg}', scaled: false);
    text('', top: pillTop + 33, font: 'Cairo', size: 14, color: const Color(0xFF785A78),
        template: '{hijri}', scaled: false);
    body(t, label, pillTop + 90, size: 27);
    ornament(OrnamentKind.flowers, const Offset(cx, 598), 330, height: 70,
        color: Colors.white.withValues(alpha: 0.9), locked: true, seed: 7);
  }

  void number(DailyText t, String label) {
    var y = text('', top: 60 * scale, font: 'Rakkas', size: 110, color: p.acc,
        fill: accentFill, template: '{day}', lineHeight: 1.1);
    y = text('', top: y - 6, font: 'Reem Kufi', size: 29, template: '{month} {year}');
    ornament(OrnamentKind.divider, Offset(cx, y + 12), 140, height: 10);
    y = text('', top: y + 24, font: 'Cairo', size: 15, color: p.sub,
        template: '{weekday} · {hijri}');
    body(t, label, y + 30, color: p.acc, fill: accentFill, size: 30);
  }

  void badge(DailyText t, String label) {
    final c = Offset(cx, 150 * scale + 10);
    final r = 76 * scale;
    ornament(OrnamentKind.ring, c, r * 2);
    final onBadge = p.bg.first;
    text('', top: c.dy - r * 0.78, font: 'Cairo', size: 17, color: onBadge, template: '{weekday}');
    text('', top: c.dy - r * 0.48, font: 'Rakkas', size: 50, color: onBadge, template: '{day}', lineHeight: 1.1);
    text('', top: c.dy + r * 0.32, font: 'Cairo', size: 15, color: onBadge, template: '{month}');
    final y = text('', top: c.dy + r + 12, font: 'Cairo', size: 17, color: p.sub, template: '{hijri}');
    body(t, label, y + 26, size: 27);
  }

  void card(String headline, DailyText t, String label) {
    var y = text(headline, top: 62 * scale + 8, font: titleFont, size: 38);
    y = text('', top: y, font: 'Cairo', size: 17, color: p.sub, template: '{weekday} · {greg}');
    y = text('', top: y - 6, font: 'Cairo', size: 15, color: p.sub, template: '{hijri}');
    final cardTop = y + 24;
    final at = layers.length;
    // On the white card a light accent would vanish; use a dark tone.
    final onCard = p.acc.computeLuminance() > 0.55 ? p.bg[1] : p.acc;
    var yy = text('”', top: cardTop + 4, font: 'Amiri', size: 64, color: onCard, lineHeight: 1);
    yy = body(t, label, yy - 18, color: const Color(0xFF28283A),
        sourceColor: const Color(0xFF777786), labelColor: onCard, size: 24);
    final cardHeight = yy - cardTop + 18;
    final cardLayer = _layer(LayerKind.ornament)
      ..ornament = OrnamentKind.card
      ..position = Offset(cx, cardTop + cardHeight / 2)
      ..size = w - 60
      ..height = cardHeight
      ..color = Colors.white.withValues(alpha: 0.95);
    layers.insert(at, cardLayer);
    bottom = cardTop + cardHeight;
  }

  void tag(String value) {
    final l = _layer(LayerKind.text)
      ..text = '🌙 $value'
      ..font = StoryFonts.byFamily('Cairo')
      ..fontSize = 13
      ..color = p.dark ? p.bg.first : Colors.white;
    final tp = TextPainter(
      text: TextSpan(text: l.text, style: l.textStyle()),
      textDirection: TextDirection.rtl,
    )..layout();
    final width = tp.width + 34;
    tp.dispose();
    ornament(OrnamentKind.pill, const Offset(cx, 497), width, height: 27,
        color: p.dark ? p.acc : p.acc.withValues(alpha: 0.9));
    layers.add(l..position = const Offset(cx, 497));
  }

  void watermark() {
    layers.add(_layer(LayerKind.watermark)
      ..position = const Offset(cx, 538)
      ..color = p.dark ? Colors.white : Colors.black);
  }
}
