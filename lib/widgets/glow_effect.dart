import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Live "glow": a brightened, blurred copy of [child] laid softly over it.
/// Smooths skin and blemishes and adds a gentle bloom. [amount] is 0 – 1;
/// [sigma] is the blur radius in the child's logical pixels.
class GlowEffect extends StatelessWidget {
  const GlowEffect({
    super.key,
    required this.amount,
    required this.child,
    this.sigma = 7,
  });

  final double amount;
  final double sigma;
  final Widget child;

  static const _brighten = ColorFilter.matrix([
    1.04, 0, 0, 0, 14, //
    0, 1.04, 0, 0, 12, //
    0, 0, 1.04, 0, 10, //
    0, 0, 0, 1, 0, //
  ]);

  @override
  Widget build(BuildContext context) {
    if (amount <= 0.001) return child;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: (amount * 0.6).clamp(0.0, 1.0),
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                    sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.clamp),
                child: ColorFiltered(colorFilter: _brighten, child: child),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
