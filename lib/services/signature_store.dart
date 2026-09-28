import 'dart:convert';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/story_layer.dart';

/// Saved personal signatures (name + font + style + color), kept on the
/// device. Stored as layer specs, so they stay crisp at any size.
class SignatureStore extends ValueNotifier<List<StoryLayer>> {
  SignatureStore._() : super(const []);

  static final instance = SignatureStore._();
  static const _key = 'signatures';
  static const maxSaved = 12;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? const [];
      value = [
        for (final s in raw)
          StoryLayer.fromJson(jsonDecode(s) as Map<String, dynamic>),
      ];
    } catch (_) {
      // Start empty; signatures are optional.
    }
  }

  Future<void> add(StoryLayer signature) async {
    final sig = signature.copyWith(
      id: 'sig_${DateTime.now().millisecondsSinceEpoch}',
      position: Offset.zero,
    );
    await _save([sig, ...value].take(maxSaved).toList());
  }

  Future<void> remove(String id) =>
      _save(value.where((s) => s.id != id).toList());

  Future<void> _save(List<StoryLayer> list) async {
    value = list;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _key,
        [for (final s in list) jsonEncode(s.toJson())],
      );
    } catch (_) {}
  }
}
