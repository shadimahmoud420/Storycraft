import 'dart:ui';

import '../core/config.dart';

/// Canvas aspect ratios. The design width is always 360 units (exported
/// at 3x = 1080 px); the height follows the ratio.
enum StoryFormat {
  story(9 / 16),
  portrait(4 / 5),
  square(1),
  wide(16 / 9);

  const StoryFormat(this.aspectRatio);

  final double aspectRatio;

  Size get size => Size(
        AppConfig.canvasWidth,
        AppConfig.canvasWidth / aspectRatio,
      );

  static StoryFormat byName(Object? name) =>
      values.where((f) => f.name == name).firstOrNull ?? story;
}
