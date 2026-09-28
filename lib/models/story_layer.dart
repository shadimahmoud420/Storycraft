import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/fonts.dart';

enum LayerKind { text, emoji, shape, image, art }

enum ShapeKind { roundedFrame, rectFrame, circleFrame, line, label }

/// Background behind a text block. [blur] frosts whatever is behind the
/// text, which keeps it readable on busy photos.
enum TextHighlight { none, solid, soft, blur }

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
    this.shape = ShapeKind.roundedFrame,
    this.size = 160,
    this.imageBytes,
    this.position = const Offset(180, 320),
    this.scale = 1,
    this.rotation = 0,
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

  /// Shape and image layers: base width in canvas units.
  ShapeKind shape;
  double size;
  Uint8List? imageBytes;

  Offset position;
  double scale;
  double rotation;

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
        shape: shape,
        size: size,
        imageBytes: imageBytes,
        position: position ?? this.position,
        scale: scale,
        rotation: rotation,
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

  TextStyle get style {
    final base = TextStyle(
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
    );
    // Emoji and symbols use the platform font so they render in color.
    return kind == LayerKind.emoji ? base : font.style(base);
  }

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
        'shape': shape.name,
        'size': size,
        if (imageBytes != null) 'image': base64Encode(imageBytes!),
        'x': position.dx,
        'y': position.dy,
        'scale': scale,
        'rotation': rotation,
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
      );
}

T _enum<T extends Enum>(List<T> values, Object? name, T fallback) =>
    values.where((v) => v.name == name).firstOrNull ?? fallback;
