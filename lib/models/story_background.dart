import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

enum BackgroundKind { solid, gradient, image }

enum ImageFit { cover, contain }

/// What is painted behind the text layers.
@immutable
class StoryBackground {
  const StoryBackground._({
    required this.kind,
    this.color = Colors.black,
    this.gradientColors = const [],
    this.gradientAngle = 0,
    this.imageBytes,
    this.originalImageBytes,
    this.imageFit = ImageFit.cover,
  });

  const StoryBackground.solid(Color color)
      : this._(kind: BackgroundKind.solid, color: color);

  const StoryBackground.gradient(List<Color> colors, {double angle = 0})
      : this._(
          kind: BackgroundKind.gradient,
          gradientColors: colors,
          gradientAngle: angle,
        );

  // ignore: prefer_const_constructors_in_immutables
  StoryBackground.image(Uint8List bytes)
      : this._(
          kind: BackgroundKind.image,
          imageBytes: bytes,
          originalImageBytes: bytes,
        );

  final BackgroundKind kind;
  final Color color;
  final List<Color> gradientColors;

  /// Gradient direction in degrees (0 = top to bottom).
  final double gradientAngle;

  /// Current (possibly processed) image.
  final Uint8List? imageBytes;

  /// Untouched import, used by the "Original" button.
  final Uint8List? originalImageBytes;
  final ImageFit imageFit;

  bool get isImage => kind == BackgroundKind.image;
  bool get isModified =>
      isImage && !identical(imageBytes, originalImageBytes);

  StoryBackground withImage(Uint8List bytes) => StoryBackground._(
        kind: BackgroundKind.image,
        imageBytes: bytes,
        originalImageBytes: originalImageBytes ?? bytes,
        imageFit: imageFit,
      );

  StoryBackground restoreOriginal() =>
      originalImageBytes == null ? this : withImage(originalImageBytes!);

  StoryBackground withFit(ImageFit fit) => StoryBackground._(
        kind: kind,
        color: color,
        gradientColors: gradientColors,
        gradientAngle: gradientAngle,
        imageBytes: imageBytes,
        originalImageBytes: originalImageBytes,
        imageFit: fit,
      );

  StoryBackground withAngle(double angle) =>
      StoryBackground.gradient(gradientColors, angle: angle);

  LinearGradient get linearGradient {
    // Convert the angle into begin/end alignments on the unit square.
    final rad = gradientAngle * math.pi / 180;
    final dx = math.sin(rad), dy = math.cos(rad);
    return LinearGradient(
      begin: Alignment(-dx, -dy),
      end: Alignment(dx, dy),
      colors: gradientColors,
    );
  }
}
