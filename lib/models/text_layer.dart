import 'package:flutter/material.dart';

import '../data/fonts.dart';

enum TextHighlight { none, solid, soft }

/// A movable, scalable, rotatable text block on the story canvas.
/// Position is the block's center in canvas coordinates (360 x 640).
class TextLayer {
  TextLayer({
    required this.id,
    required this.text,
    required this.font,
    this.color = Colors.white,
    this.fontSize = 32,
    this.align = TextAlign.center,
    this.highlight = TextHighlight.none,
    this.shadow = false,
    this.position = const Offset(180, 320),
    this.scale = 1,
    this.rotation = 0,
  });

  final String id;
  String text;
  StoryFont font;
  Color color;
  double fontSize;
  TextAlign align;
  TextHighlight highlight;
  bool shadow;
  Offset position;
  double scale;
  double rotation;

  TextLayer copyWith({required String id, Offset? position}) => TextLayer(
        id: id,
        text: text,
        font: font,
        color: color,
        fontSize: fontSize,
        align: align,
        highlight: highlight,
        shadow: shadow,
        position: position ?? this.position,
        scale: scale,
        rotation: rotation,
      );

  /// Background color used behind the text when [highlight] is on.
  /// Picks black or white for contrast with the text color.
  Color? get highlightColor {
    final contrast =
        color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    return switch (highlight) {
      TextHighlight.none => null,
      TextHighlight.solid => contrast,
      TextHighlight.soft => contrast.withValues(alpha: 0.55),
    };
  }

  TextStyle get style => font.style(
        TextStyle(
          color: color,
          fontSize: fontSize,
          height: 1.3,
          shadows: shadow
              ? const [
                  Shadow(
                    color: Color(0x99000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
      );
}
