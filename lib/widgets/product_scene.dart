import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/surfaces.dart';

/// Size of the scene's design space (a 9:16 story); exported at 3x.
const productSceneSize = Size(360, 640);

/// Everything that describes a product composition.
@immutable
class ProductLook {
  const ProductLook({
    this.shadow = 0.6,
    this.reflection = 0.5,
    this.blur = 0,
    this.brightness = 0,
    this.match = 0.5,
    this.standing = false,
  });

  /// Standing products (bottles, jars) cast a shadow behind them and
  /// reflect on polished surfaces; lying ones (bags, boxes shot from
  /// above) get a soft shadow all around.
  final bool standing;

  /// 0 – 1.
  final double shadow;
  final double reflection;
  final double blur;

  /// -1 – 1.
  final double brightness;

  /// How much the product takes the scene's color, 0 – 1.
  final double match;

  ProductLook copyWith({
    double? shadow,
    double? reflection,
    double? blur,
    double? brightness,
    double? match,
    bool? standing,
  }) =>
      ProductLook(
        shadow: shadow ?? this.shadow,
        reflection: reflection ?? this.reflection,
        blur: blur ?? this.blur,
        brightness: brightness ?? this.brightness,
        match: match ?? this.match,
        standing: standing ?? this.standing,
      );
}

/// Color matrix that tints the product toward the scene's light and
/// adjusts its brightness. Public for tests.
List<double> productLightMatrix(Color? scene, double match, double brightness) {
  var fr = 1.0, fg = 1.0, fb = 1.0;
  if (scene != null && match > 0) {
    final r = scene.r, g = scene.g, b = scene.b;
    final lum = (r + g + b) / 3;
    if (lum > 0.02) {
      final k = match * 0.22;
      fr = 1 - k + k * (r / lum);
      fg = 1 - k + k * (g / lum);
      fb = 1 - k + k * (b / lum);
    }
  }
  final gain = 1 + brightness * 0.25;
  final lift = brightness * 18;
  return [
    fr * gain, 0, 0, 0, lift, //
    0, fg * gain, 0, 0, lift,
    0, 0, fb * gain, 0, lift,
    0, 0, 0, 1, 0,
  ];
}

/// The product on its new surface: backdrop, cast and contact shadows,
/// an optional reflection and the color-matched product. Laid out in the
/// 360x640 design space.
class ProductScene extends StatelessWidget {
  const ProductScene({
    super.key,
    required this.product,
    required this.productAspect,
    required this.center,
    required this.width,
    required this.look,
    this.surface,
    this.customBackground,
  });

  final Uint8List product;

  /// Product height / width.
  final double productAspect;

  /// Bottom center of the product (where it touches the surface).
  final Offset center;
  final double width;
  final ProductLook look;
  final StudioSurface? surface;
  final Uint8List? customBackground;

  @override
  Widget build(BuildContext context) {
    final h = width * productAspect;
    final left = center.dx - width / 2;
    final top = center.dy - h;
    final productImage = Image.memory(product,
        width: width, height: h, fit: BoxFit.fill, gaplessPlayback: true);
    final glossy = surface?.glossy ?? false;

    final ImageProvider bg = customBackground != null
        ? MemoryImage(customBackground!)
        : AssetImage(surface!.asset) as ImageProvider;
    final sigma = look.blur * 10;

    return SizedBox.fromSize(
      size: productSceneSize,
      child: ClipRect(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: ImageFiltered(
                enabled: sigma > 0.05,
                imageFilter: ui.ImageFilter.blur(
                    sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.clamp),
                child: Image(image: bg, fit: BoxFit.cover, gaplessPlayback: true),
              ),
            ),

            // Lying product: a soft shadow all around, plus a tight one
            // where it touches the surface.
            if (look.shadow > 0 && !look.standing) ...[
              _silhouetteShadow(left + width * 0.02, top + width * 0.05, h,
                  blur: 14, opacity: look.shadow * 0.5, child: productImage),
              _silhouetteShadow(left, top + width * 0.012, h,
                  blur: 3, opacity: look.shadow * 0.45, child: productImage),
            ],

            // Standing product: the silhouette laid back on the surface.
            if (look.shadow > 0 && look.standing)
              Positioned(
                left: left,
                top: top,
                width: width,
                height: h,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: (look.shadow * 0.42).clamp(0.0, 1.0),
                    child: Transform(
                      alignment: Alignment.bottomCenter,
                      transform: Matrix4.identity()
                        ..scaleByDouble(1.0, 0.3, 1.0, 1.0)
                        ..multiply(Matrix4.skewX(0.75)),
                      child: ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                        child: ColorFiltered(
                          colorFilter: const ColorFilter.mode(
                              Colors.black, BlendMode.srcIn),
                          child: productImage,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Reflection on polished surfaces.
            if (glossy && look.standing && look.reflection > 0)
              Positioned(
                left: left,
                top: center.dy - 1,
                width: width,
                height: h,
                child: IgnorePointer(
                  child: ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (r) => LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: look.reflection * 0.38),
                        Colors.white.withValues(alpha: 0),
                      ],
                      stops: const [0, 0.38],
                    ).createShader(r),
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: 1.2, sigmaY: 1.2),
                      child: Transform.flip(flipY: true, child: productImage),
                    ),
                  ),
                ),
              ),

            // Contact shadow right under a standing product.
            if (look.shadow > 0 && look.standing)
              Positioned(
                left: center.dx - width * 0.55,
                top: center.dy - width * 0.08,
                width: width * 1.1,
                height: width * 0.16,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(
                          Radius.elliptical(width * 0.55, width * 0.08)),
                      gradient: RadialGradient(
                        colors: [
                          Colors.black.withValues(alpha: look.shadow * 0.55),
                          Colors.black.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            Positioned(
              left: left,
              top: top,
              width: width,
              height: h,
              child: ColorFiltered(
                colorFilter: ColorFilter.matrix(productLightMatrix(
                    customBackground != null ? null : surface?.average,
                    look.match,
                    look.brightness)),
                child: productImage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _silhouetteShadow(double x, double y, double h,
          {required double blur,
          required double opacity,
          required Widget child}) =>
      Positioned(
        left: x,
        top: y,
        width: width,
        height: h,
        child: IgnorePointer(
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: ColorFiltered(
                colorFilter:
                    const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                child: child,
              ),
            ),
          ),
        ),
      );
}
