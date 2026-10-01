/// Photo filters as 4x5 color matrices, blended with the identity by an
/// intensity (0 – 1). Non-destructive: applied at render time.
enum PhotoFilter {
  none, glow, food, nature, vivid, warm, cool, vintage, mono, fade, drama, rose,
}

class PhotoFilters {
  PhotoFilters._();

  static const identity = <double>[
    1, 0, 0, 0, 0, //
    0, 1, 0, 0, 0, //
    0, 0, 1, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  static List<double> _saturation(double s) {
    const r = 0.2126, g = 0.7152, b = 0.0722;
    return [
      r * (1 - s) + s, g * (1 - s), b * (1 - s), 0, 0, //
      r * (1 - s), g * (1 - s) + s, b * (1 - s), 0, 0, //
      r * (1 - s), g * (1 - s), b * (1 - s) + s, 0, 0, //
      0, 0, 0, 1, 0, //
    ];
  }

  static List<double> _contrast(double c, {double lift = 0}) {
    final t = 128 * (1 - c) + lift;
    return [
      c, 0, 0, 0, t, //
      0, c, 0, 0, t, //
      0, 0, c, 0, t, //
      0, 0, 0, 1, 0, //
    ];
  }

  static List<double> _tint(double r, double g, double b,
          {double dr = 0, double dg = 0, double db = 0}) =>
      [
        r, 0, 0, 0, dr, //
        0, g, 0, 0, dg, //
        0, 0, b, 0, db, //
        0, 0, 0, 1, 0, //
      ];

  /// a ∘ b: apply [b] first, then [a].
  static List<double> _mul(List<double> a, List<double> b) {
    final out = List<double>.filled(20, 0);
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 5; c++) {
        var v = c == 4 ? a[r * 5 + 4] : 0.0;
        for (var k = 0; k < 4; k++) {
          v += a[r * 5 + k] * b[k * 5 + c];
        }
        out[r * 5 + c] = v;
      }
    }
    return out;
  }

  static List<double> matrixOf(PhotoFilter f) => switch (f) {
        PhotoFilter.none => identity,
        // Soft, bright and slightly warm; the skin smoothing itself is the
        // glow blur (see [glowOf]).
        PhotoFilter.glow => _mul(
            _tint(1.04, 1.0, 0.97, dr: 6, dg: 4, db: 2),
            _mul(_contrast(0.94, lift: 10), _saturation(1.05)),
          ),
        // Appetizing: rich reds/oranges/yellows, warmer light, more punch.
        PhotoFilter.food => _mul(
            _tint(1.07, 1.01, 0.9, dr: 4),
            _mul(_contrast(1.1), _saturation(1.5)),
          ),
        // Nature: lush greens and deep blue skies with clearer detail.
        PhotoFilter.nature => _mul(
            _tint(0.97, 1.07, 1.06),
            _mul(_contrast(1.12), _saturation(1.45)),
          ),
        PhotoFilter.vivid => _mul(_contrast(1.1), _saturation(1.4)),
        PhotoFilter.warm =>
          _mul(_tint(1.08, 1.0, 0.86, dr: 8, dg: 4), _saturation(1.1)),
        PhotoFilter.cool => _mul(_tint(0.9, 1.0, 1.1, db: 8), _saturation(1.05)),
        PhotoFilter.vintage => _mul(
            _tint(1.0, 0.95, 0.8, dr: 18, dg: 10),
            _mul(_contrast(0.9, lift: 12), _saturation(0.6)),
          ),
        PhotoFilter.mono => _mul(_contrast(1.1), _saturation(0)),
        PhotoFilter.fade => _mul(_contrast(0.78, lift: 22), _saturation(0.85)),
        PhotoFilter.drama => _mul(_contrast(1.35), _saturation(0.85)),
        PhotoFilter.rose =>
          _mul(_tint(1.06, 0.94, 1.0, dr: 12, db: 8), _saturation(1.05)),
      };

  /// How much of the soft-glow (skin smoothing) blur to add, 0 – 1.
  static double glowOf(PhotoFilter f, double intensity) =>
      f == PhotoFilter.glow ? intensity : 0;

  /// Filter matrix blended with the identity by [intensity].
  static List<double> blended(PhotoFilter f, double intensity) {
    final m = matrixOf(f);
    return [
      for (var i = 0; i < 20; i++) identity[i] + (m[i] - identity[i]) * intensity,
    ];
  }
}
