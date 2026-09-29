import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/fonts.dart';

enum LayerKind { text, emoji, shape, image, art, signature }

/// Decorations around a signature name.
enum SignatureStyle {
  swash, plain, underline, seal, monogram, framed,
  // Ornamental styles.
  ornate, laurel, royal, arabesque, divider, sparkle,
}

enum ShapeKind { roundedFrame, rectFrame, circleFrame, line, label }

/// Background behind a text block. [blur] frosts whatever is behind the
/// text, which keeps it readable on busy photos.
enum TextHighlight { none, solid, soft, blur }

/// How the letters are painted: a flat color, a two-color gradient or a
/// metallic texture.
enum TextFill { solid, gradient, gold, silver, rose }

/// One movable, scalable, rotatable element on the story canvas: text,
/// emoji/symbol sticker, decorative shape, image (brand logo) or cartoon
/// illustration ([text] holds the art name for [LayerKind.art]).
/// [position] is the element's center in canvas coordinates (360 x 640).
class StoryLayer {
  StoryLayer({
    required this.id,
    this.kind = LayerKind.text,
    this.text = '',
    this.font = const StoryFont('Cairo', arabic: true),
    this.color = Colors.white,
    this.fontSize = 32,
    this.align = TextAlign.center,
    this.highlight = TextHighlight.none,
    this.shadow = false,
    this.fill = TextFill.solid,
    this.color2 = const Color(0xFFFF6B9A),
    this.strokeWidth = 0,
    this.strokeColor = Colors.black,
    this.letterSpacing = 0,
    this.lineHeight = 1.3,
    this.curve = 0,
    this.signatureStyle = SignatureStyle.swash,
    this.shape = ShapeKind.roundedFrame,
    this.size = 160,
    this.imageBytes,
    this.position = const Offset(180, 320),
    this.scale = 1,
    this.rotation = 0,
    this.opacity = 1,
    this.hidden = false,
  });

  final String id;
  final LayerKind kind;
  String text;
  StoryFont font;
  Color color;
  double fontSize;
  TextAlign align;
  TextHighlight highlight;
  bool shadow;
  TextFill fill;

  /// Second gradient color ([TextFill.gradient]).
  Color color2;

  /// Outline around the letters; 0 = none.
  double strokeWidth;
  Color strokeColor;
  double letterSpacing;
  double lineHeight;

  /// Bends the text along an arc: -1 (smile) … 0 (straight) … 1 (rainbow).
  double curve;

  /// Decoration for [LayerKind.signature] ([text] holds the name).
  SignatureStyle signatureStyle;

  /// Shape and image layers: base width in canvas units.
  ShapeKind shape;
  double size;
  Uint8List? imageBytes;

  Offset position;
  double scale;
  double rotation;

  /// Layer transparency, 0…1 (e.g. a photo blended over another).
  double opacity;

  /// Hidden layers stay in the list but are not drawn or exported.
  bool hidden;

  bool get isText => kind == LayerKind.text;

  StoryLayer copyWith({required String id, Offset? position}) => StoryLayer(
        id: id,
        kind: kind,
        text: text,
        font: font,
        color: color,
        fontSize: fontSize,
        align: align,
        highlight: highlight,
        shadow: shadow,
        fill: fill,
        color2: color2,
        strokeWidth: strokeWidth,
        strokeColor: strokeColor,
        letterSpacing: letterSpacing,
        lineHeight: lineHeight,
        curve: curve,
        signatureStyle: signatureStyle,
        shape: shape,
        size: size,
        imageBytes: imageBytes,
        position: position ?? this.position,
        scale: scale,
        rotation: rotation,
        opacity: opacity,
        hidden: hidden,
      );

  StoryLayer clone() => copyWith(id: id);

  /// Background color used behind the text when [highlight] is on.
  /// Picks black or white for contrast with the text color.
  Color? get highlightColor {
    final contrast =
        color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    return switch (highlight) {
      TextHighlight.none => null,
      TextHighlight.solid => contrast,
      TextHighlight.soft => contrast.withValues(alpha: 0.55),
      TextHighlight.blur => contrast.withValues(alpha: 0.18),
    };
  }

  static const _shadows = [
    Shadow(color: Color(0x99000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  /// Text style with the given paint. Pass [foreground] for strokes; the
  /// fill uses [color] (white under a gradient mask).
  TextStyle textStyle({
    Color? color,
    Paint? foreground,
    bool withShadow = false,
  }) {
    final base = TextStyle(
      color: foreground == null ? (color ?? this.color) : null,
      foreground: foreground,
      fontSize: fontSize,
      height: lineHeight,
      letterSpacing: letterSpacing,
      shadows: withShadow ? _shadows : null,
    );
    // Emoji and symbols use the platform font so they render in color.
    return kind == LayerKind.emoji ? base : font.style(base);
  }

  /// Plain style (solid fill + shadow): text field, emoji, previews.
  TextStyle get style => textStyle(withShadow: shadow);

  /// Shader for non-solid fills, or null for a flat color.
  Gradient? get fillGradient => switch (fill) {
        TextFill.solid => null,
        TextFill.gradient => LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color2],
          ),
        TextFill.gold => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFA67C00), Color(0xFFFFEBA8), Color(0xFFD4AF37),
                Color(0xFFFFF6C8), Color(0xFF9C7400)],
            stops: [0, 0.3, 0.5, 0.72, 1],
          ),
        TextFill.silver => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6E7B85), Color(0xFFFFFFFF), Color(0xFFAEB6BF),
                Color(0xFFF4F6F7), Color(0xFF7F8C8D)],
            stops: [0, 0.3, 0.5, 0.72, 1],
          ),
        TextFill.rose => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFA85A66), Color(0xFFFAD4D8), Color(0xFFE8A0A7),
                Color(0xFFFFE4E8), Color(0xFF9E4F5B)],
            stops: [0, 0.3, 0.5, 0.72, 1],
          ),
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'text': text,
        'font': font.family,
        'color': color.toARGB32(),
        'fontSize': fontSize,
        'align': align.name,
        'highlight': highlight.name,
        'shadow': shadow,
        'fill': fill.name,
        'color2': color2.toARGB32(),
        'strokeWidth': strokeWidth,
        'strokeColor': strokeColor.toARGB32(),
        'letterSpacing': letterSpacing,
        'lineHeight': lineHeight,
        'curve': curve,
        'signature': signatureStyle.name,
        'shape': shape.name,
        'size': size,
        if (imageBytes != null) 'image': base64Encode(imageBytes!),
        'x': position.dx,
        'y': position.dy,
        'scale': scale,
        'rotation': rotation,
        'opacity': opacity,
        'hidden': hidden,
      };

  factory StoryLayer.fromJson(Map<String, dynamic> j) => StoryLayer(
        id: j['id'] as String,
        kind: _enum(LayerKind.values, j['kind'], LayerKind.text),
        text: j['text'] as String? ?? '',
        font: StoryFonts.byFamily(j['font'] as String? ?? 'Cairo'),
        color: Color(j['color'] as int? ?? 0xFFFFFFFF),
        fontSize: (j['fontSize'] as num? ?? 32).toDouble(),
        align: _enum(TextAlign.values, j['align'], TextAlign.center),
        highlight: _enum(TextHighlight.values, j['highlight'], TextHighlight.none),
        shadow: j['shadow'] as bool? ?? false,
        fill: _enum(TextFill.values, j['fill'], TextFill.solid),
        color2: Color(j['color2'] as int? ?? 0xFFFF6B9A),
        strokeWidth: (j['strokeWidth'] as num? ?? 0).toDouble(),
        strokeColor: Color(j['strokeColor'] as int? ?? 0xFF000000),
        letterSpacing: (j['letterSpacing'] as num? ?? 0).toDouble(),
        lineHeight: (j['lineHeight'] as num? ?? 1.3).toDouble(),
        curve: (j['curve'] as num? ?? 0).toDouble(),
        signatureStyle: _enum(
            SignatureStyle.values, j['signature'], SignatureStyle.swash),
        shape: _enum(ShapeKind.values, j['shape'], ShapeKind.roundedFrame),
        size: (j['size'] as num? ?? 160).toDouble(),
        imageBytes:
            j['image'] == null ? null : base64Decode(j['image'] as String),
        position: Offset(
          (j['x'] as num? ?? 180).toDouble(),
          (j['y'] as num? ?? 320).toDouble(),
        ),
        scale: (j['scale'] as num? ?? 1).toDouble(),
        rotation: (j['rotation'] as num? ?? 0).toDouble(),
        opacity: (j['opacity'] as num? ?? 1).toDouble(),
        hidden: j['hidden'] as bool? ?? false,
      );
}

T _enum<T extends Enum>(List<T> values, Object? name, T fallback) =>
    values.where((v) => v.name == name).firstOrNull ?? fallback;
