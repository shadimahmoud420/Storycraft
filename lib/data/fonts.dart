import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A Google Font offered in the text editor.
@immutable
class StoryFont {
  const StoryFont(this.family, {required this.arabic, this.label});

  final String family;
  final bool arabic;

  /// Display name in the picker (defaults to [family]).
  final String? label;

  String get displayName => label ?? family;

  /// Applies the font to [base]. Falls back to the platform font if the
  /// family cannot be resolved (e.g. removed from Google Fonts).
  TextStyle style([TextStyle? base]) {
    try {
      return GoogleFonts.getFont(family, textStyle: base);
    } catch (_) {
      return base ?? const TextStyle();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is StoryFont && other.family == family;

  @override
  int get hashCode => family.hashCode;
}

class StoryFonts {
  StoryFonts._();

  /// Popular Arabic fonts (all include Latin glyphs too).
  static const arabic = <StoryFont>[
    StoryFont('Cairo', arabic: true, label: 'القاهرة'),
    StoryFont('Tajawal', arabic: true, label: 'تجوال'),
    StoryFont('Almarai', arabic: true, label: 'المراعي'),
    StoryFont('Amiri', arabic: true, label: 'أميري'),
    StoryFont('Reem Kufi', arabic: true, label: 'ريم كوفي'),
    StoryFont('El Messiri', arabic: true, label: 'المسيري'),
    StoryFont('Changa', arabic: true, label: 'تشانغا'),
    StoryFont('Lalezar', arabic: true, label: 'لاله‌زار'),
    StoryFont('Aref Ruqaa', arabic: true, label: 'رقعة'),
    StoryFont('Lateef', arabic: true, label: 'لطيف'),
    StoryFont('Rakkas', arabic: true, label: 'رقّاص'),
    StoryFont('Markazi Text', arabic: true, label: 'مركزي'),
  ];

  /// Popular English fonts.
  static const english = <StoryFont>[
    StoryFont('Montserrat', arabic: false),
    StoryFont('Poppins', arabic: false),
    StoryFont('Playfair Display', arabic: false),
    StoryFont('Bebas Neue', arabic: false),
    StoryFont('Oswald', arabic: false),
    StoryFont('Anton', arabic: false),
    StoryFont('Pacifico', arabic: false),
    StoryFont('Lobster', arabic: false),
    StoryFont('Dancing Script', arabic: false),
    StoryFont('Great Vibes', arabic: false),
    StoryFont('Caveat', arabic: false),
    StoryFont('Righteous', arabic: false),
  ];

  static StoryFont defaultFor(String text) =>
      _hasArabic(text) ? arabic.first : english.first;

  static bool _hasArabic(String text) =>
      RegExp(r'[؀-ۿݐ-ݿﭐ-﷿ﹰ-﻿]')
          .hasMatch(text);

  static bool hasArabic(String text) => _hasArabic(text);
}
