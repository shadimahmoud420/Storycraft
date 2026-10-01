import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// The song-video project in progress, kept on the device so leaving the
/// app (or the screen) never loses work. Media files are copied into the
/// draft folder because picked files live in temporary storage.
class LyricVideoDraft {
  LyricVideoDraft._();

  static Future<Directory> _dir() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/lyric_video_draft').create(recursive: true);
  }

  /// Copies [source] into the draft as `<name>.<ext>` (replacing any
  /// previous file of that name) and returns the new path.
  static Future<String> keepMedia(String source, String name) async {
    final dir = await _dir();
    for (final f in dir.listSync()) {
      final base = f.uri.pathSegments.last;
      if (base.startsWith('$name.')) f.deleteSync();
    }
    final dot = source.lastIndexOf('.');
    final ext = dot > source.lastIndexOf('/') ? source.substring(dot + 1) : 'bin';
    // A fresh name each time so players never show a cached older file.
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final target = '${dir.path}/$name.$stamp.$ext';
    await File(source).copy(target);
    return target;
  }

  static Future<void> removeMedia(String name) async {
    final dir = await _dir();
    for (final f in dir.listSync()) {
      if (f.uri.pathSegments.last.startsWith('$name.')) f.deleteSync();
    }
  }

  static Future<void> save(Map<String, Object?> project) async {
    final dir = await _dir();
    final file = File('${dir.path}/project.json');
    final tmp = File('${dir.path}/project.json.tmp');
    await tmp.writeAsString(jsonEncode(project), flush: true);
    await tmp.rename(file.path);
  }

  /// The saved project, or null. Media paths that no longer exist are
  /// dropped.
  static Future<Map<String, Object?>?> load() async {
    try {
      final dir = await _dir();
      final file = File('${dir.path}/project.json');
      if (!file.existsSync()) return null;
      final j = jsonDecode(await file.readAsString()) as Map<String, Object?>;
      for (final key in ['video', 'audio']) {
        final path = j[key] as String?;
        if (path != null && !File(path).existsSync()) j.remove(key);
      }
      return j['video'] == null ? null : j;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final dir = await _dir();
    if (dir.existsSync()) await dir.delete(recursive: true);
  }
}
