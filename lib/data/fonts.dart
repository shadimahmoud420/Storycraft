import 'package:flutter/material.dart';

part 'font_catalog.g.dart';

/// Style families shown as filter chips in the font picker.
enum FontCategory {
  // Arabic
  modern, kufi, naskh, calligraphy,
  // Both
  display,
  // English
  sans, serif, script, hand,
}

/// A bundled font (assets/fonts, registered in pubspec.yaml by
/// tool/fonts_catalog.py). Works fully offline.
@immutable
class StoryFont {
  const StoryFont(
    this.family, {
    required this.arabic,
    this.category = FontCategory.modern,
    this.label,
  });

  final String family;
  final bool arabic;
  final FontCategory category;

  /// Display name in the picker (defaults to [family]).
  final String? label;

  String get displayName => label ?? family;

  TextStyle style([TextStyle? base]) =>
      (base ?? const TextStyle()).copyWith(fontFamily: family);

  @override
  bool operator ==(Object other) =>
      other is StoryFont && other.family == family;

  @override
  int get hashCode => family.hashCode;
}

class StoryFonts {
  StoryFonts._();

  static const arabic = _arabicFonts;
  static const english = _englishFonts;
  static const all = <StoryFont>[..._arabicFonts, ..._englishFonts];

  static List<FontCategory> categories({required bool arabic}) => [
        for (final c in FontCategory.values)
          if ((arabic ? _arabicFonts : _englishFonts)
              .any((f) => f.category == c))
            c,
      ];

  /// Resolves a saved family name back to a font (drafts, brand kit).
  static StoryFont byFamily(String family) =>
      all.where((f) => f.family == family).firstOrNull ??
      StoryFont(family, arabic: false);

  static StoryFont defaultFor(String text) =>
      hasArabic(text) ? arabic.first : english.first;

  static bool hasArabic(String text) =>
      RegExp(r'[؀-ۿݐ-ݿﭐ-﷿ﹰ-﻿]')
          .hasMatch(text);
}
