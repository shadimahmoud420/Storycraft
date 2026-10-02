import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Look of the news template.
enum NewsDesign {
  /// Dark, with a red "breaking" band.
  breaking,

  /// The user's photo behind the news, darkened at the bottom.
  field,

  /// Light paper card with a colored header.
  paper,
}

/// Everything fixed about the user's news posts, set once: who signs them,
/// how they look. Each post then only needs its text.
@immutable
class NewsProfile {
  const NewsProfile({
    this.name = '',
    this.handle = '',
    this.signatureId,
    this.logo,
    this.accent = const Color(0xFFD62828),
    this.design = NewsDesign.breaking,
    this.showDateTime = true,
    this.location = '',
    this.tag = 'عاجل',
  });

  /// Reporter / page name shown under every post.
  final String name;

  /// e.g. @page or a phone number.
  final String handle;

  /// One of the saved signatures (SignatureStore), or null.
  final String? signatureId;
  final Uint8List? logo;
  final Color accent;
  final NewsDesign design;
  final bool showDateTime;

  /// Last used location and label, prefilled next time.
  final String location;
  final String tag;

  bool get isSetUp => name.trim().isNotEmpty || signatureId != null;

  NewsProfile copyWith({
    String? name,
    String? handle,
    String? signatureId,
    bool clearSignature = false,
    Uint8List? logo,
    bool clearLogo = false,
    Color? accent,
    NewsDesign? design,
    bool? showDateTime,
    String? location,
    String? tag,
  }) =>
      NewsProfile(
        name: name ?? this.name,
        handle: handle ?? this.handle,
        signatureId: clearSignature ? null : signatureId ?? this.signatureId,
        logo: clearLogo ? null : logo ?? this.logo,
        accent: accent ?? this.accent,
        design: design ?? this.design,
        showDateTime: showDateTime ?? this.showDateTime,
        location: location ?? this.location,
        tag: tag ?? this.tag,
      );

  Map<String, Object?> toJson() => {
        'name': name,
        'handle': handle,
        'signatureId': signatureId,
        'accent': accent.toARGB32(),
        'design': design.name,
        'showDateTime': showDateTime,
        'location': location,
        'tag': tag,
      };

  factory NewsProfile.fromJson(Map<String, Object?> j, {Uint8List? logo}) {
    const d = NewsProfile();
    return NewsProfile(
      name: j['name'] as String? ?? '',
      handle: j['handle'] as String? ?? '',
      signatureId: j['signatureId'] as String?,
      logo: logo,
      accent: Color((j['accent'] as num?)?.toInt() ?? d.accent.toARGB32()),
      design: NewsDesign.values.asNameMap()[j['design']] ?? d.design,
      showDateTime: j['showDateTime'] as bool? ?? true,
      location: j['location'] as String? ?? '',
      tag: j['tag'] as String? ?? d.tag,
    );
  }
}

/// Keeps the news profile on the device (preferences + logo file).
class NewsProfileStore extends ValueNotifier<NewsProfile> {
  NewsProfileStore._() : super(const NewsProfile());

  static final instance = NewsProfileStore._();
  static const _key = 'news_profile';

  static Future<File> _logoFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/news_logo.png');
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final file = await _logoFile();
      final logo = file.existsSync() ? await file.readAsBytes() : null;
      value = NewsProfile.fromJson(
          jsonDecode(raw) as Map<String, Object?>, logo: logo);
    } catch (_) {
      // Start fresh.
    }
  }

  Future<void> save(NewsProfile profile) async {
    final logoChanged = !identical(profile.logo, value.logo);
    value = profile;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(profile.toJson()));
      if (logoChanged) {
        final file = await _logoFile();
        if (profile.logo == null) {
          if (file.existsSync()) await file.delete();
        } else {
          await file.writeAsBytes(profile.logo!, flush: true);
        }
      }
    } catch (_) {}
  }
}
