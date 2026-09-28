import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/filters.dart';

enum BackgroundKind { solid, gradient, image }

enum ImageFit { cover, contain }

/// What is painted behind the layers.
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
    this.imageOffset = Offset.zero,
    this.imageScale = 1,
    this.dim = 0,
    this.filter = PhotoFilter.none,
    this.filterIntensity = 1,
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
  StoryBackground.image(Uint8List bytes, {Uint8List? original})
      : this._(
          kind: BackgroundKind.image,
          imageBytes: bytes,
          originalImageBytes: original ?? bytes,
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

  /// User pan (canvas units) and zoom (>= 1) of the photo.
  final Offset imageOffset;
  final double imageScale;

  /// Black overlay strength (0 – 0.6) that makes text on photos readable.
  final double dim;

  /// Non-destructive photo filter and its strength (0 – 1).
  final PhotoFilter filter;
  final double filterIntensity;

  List<double>? get filterMatrix => filter == PhotoFilter.none
      ? null
      : PhotoFilters.blended(filter, filterIntensity);

  bool get isImage => kind == BackgroundKind.image;
  bool get isModified =>
      isImage && !identical(imageBytes, originalImageBytes);

  StoryBackground copyWith({
    Uint8List? imageBytes,
    ImageFit? imageFit,
    Offset? imageOffset,
    double? imageScale,
    double? dim,
    double? gradientAngle,
    PhotoFilter? filter,
    double? filterIntensity,
  }) =>
      StoryBackground._(
        kind: kind,
        color: color,
        gradientColors: gradientColors,
        gradientAngle: gradientAngle ?? this.gradientAngle,
        imageBytes: imageBytes ?? this.imageBytes,
        originalImageBytes: originalImageBytes,
        imageFit: imageFit ?? this.imageFit,
        imageOffset: imageOffset ?? this.imageOffset,
        imageScale: imageScale ?? this.imageScale,
        dim: dim ?? this.dim,
        filter: filter ?? this.filter,
        filterIntensity: filterIntensity ?? this.filterIntensity,
      );

  StoryBackground withImage(Uint8List bytes) => copyWith(imageBytes: bytes);

  StoryBackground restoreOriginal() => originalImageBytes == null
      ? this
      : copyWith(imageBytes: originalImageBytes);

  /// Switching fit resets pan/zoom so the photo is never lost off-canvas.
  StoryBackground withFit(ImageFit fit) =>
      copyWith(imageFit: fit, imageOffset: Offset.zero, imageScale: 1);

  StoryBackground withAngle(double angle) => copyWith(gradientAngle: angle);

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

  /// Serializable settings; image bytes are stored separately as files.
  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'color': color.toARGB32(),
        'gradient': [for (final c in gradientColors) c.toARGB32()],
        'angle': gradientAngle,
        'fit': imageFit.name,
        'dx': imageOffset.dx,
        'dy': imageOffset.dy,
        'scale': imageScale,
        'dim': dim,
        'filter': filter.name,
        'filterIntensity': filterIntensity,
      };

  factory StoryBackground.fromJson(
    Map<String, dynamic> j, {
    Uint8List? image,
    Uint8List? original,
  }) {
    final kind = BackgroundKind.values
            .where((k) => k.name == j['kind'])
            .firstOrNull ??
        BackgroundKind.solid;
    final base = switch (kind) {
      BackgroundKind.image when image != null =>
        StoryBackground.image(image, original: original),
      BackgroundKind.gradient => StoryBackground.gradient([
          for (final c in (j['gradient'] as List? ?? const [])) Color(c as int),
        ], angle: (j['angle'] as num? ?? 0).toDouble()),
      _ => StoryBackground.solid(Color(j['color'] as int? ?? 0xFF000000)),
    };
    return base.copyWith(
      imageFit: j['fit'] == 'contain' ? ImageFit.contain : ImageFit.cover,
      imageOffset: Offset(
        (j['dx'] as num? ?? 0).toDouble(),
        (j['dy'] as num? ?? 0).toDouble(),
      ),
      imageScale: (j['scale'] as num? ?? 1).toDouble(),
      dim: (j['dim'] as num? ?? 0).toDouble(),
      filter: PhotoFilter.values
              .where((f) => f.name == j['filter'])
              .firstOrNull ??
          PhotoFilter.none,
      filterIntensity: (j['filterIntensity'] as num? ?? 1).toDouble(),
    );
  }
}
