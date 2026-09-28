import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/fonts.dart';

/// A business's logo, colors and favorite font, reused in every design.
@immutable
class BrandKit {
  const BrandKit({this.colors = const [], this.fontFamily, this.logo});

  final List<Color> colors;
  final String? fontFamily;
  final Uint8List? logo;

  StoryFont? get font =>
      fontFamily == null ? null : StoryFonts.byFamily(fontFamily!);

  bool get isEmpty => colors.isEmpty && fontFamily == null && logo == null;

  BrandKit copyWith({
    List<Color>? colors,
    String? fontFamily,
    bool clearFont = false,
    Uint8List? logo,
    bool clearLogo = false,
  }) =>
      BrandKit(
        colors: colors ?? this.colors,
        fontFamily: clearFont ? null : fontFamily ?? this.fontFamily,
        logo: clearLogo ? null : logo ?? this.logo,
      );
}

/// Persists the brand kit on the device (preferences + logo file).
class BrandKitStore extends ValueNotifier<BrandKit> {
  BrandKitStore._() : super(const BrandKit());

  static final instance = BrandKitStore._();
  static const _key = 'brand_kit';

  Future<File> _logoFile() async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}/brand_logo.png');
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      final json = raw == null
          ? const <String, dynamic>{}
          : jsonDecode(raw) as Map<String, dynamic>;
      final logoFile = await _logoFile();
      value = BrandKit(
        colors: [
          for (final c in (json['colors'] as List? ?? const []))
            Color(c as int),
        ],
        fontFamily: json['font'] as String?,
        logo: await logoFile.exists() ? await logoFile.readAsBytes() : null,
      );
    } catch (_) {
      // Keep the empty kit; the app works without it.
    }
  }

  Future<void> update(BrandKit kit) async {
    value = kit;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'colors': [for (final c in kit.colors) c.toARGB32()],
          'font': kit.fontFamily,
        }),
      );
      final logoFile = await _logoFile();
      if (kit.logo == null) {
        if (await logoFile.exists()) await logoFile.delete();
      } else {
        await logoFile.writeAsBytes(kit.logo!);
      }
    } catch (_) {}
  }

  /// Shrinks a picked logo to at most 600 px and keeps transparency (PNG).
  static Future<Uint8List> prepareLogo(Uint8List bytes) =>
      compute(_prepareLogo, bytes);
}

Uint8List _prepareLogo(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Unsupported image');
  var image = img.bakeOrientation(decoded);
  final longEdge = image.width > image.height ? image.width : image.height;
  if (longEdge > 600) {
    final s = 600 / longEdge;
    image = img.copyResize(
      image,
      width: (image.width * s).round(),
      height: (image.height * s).round(),
      interpolation: img.Interpolation.average,
    );
  }
  return img.encodePng(image);
}
