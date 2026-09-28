import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/story_background.dart';
import '../models/story_layer.dart';

/// A saved story shown in the "My drafts" list.
class DraftSummary {
  const DraftSummary(this.id, this.updatedAt, this.thumbnail);

  final String id;
  final DateTime updatedAt;
  final Uint8List? thumbnail;
}

class LoadedDraft {
  const LoadedDraft(this.background, this.layers);

  final StoryBackground background;
  final List<StoryLayer> layers;
}

/// Stores drafts on the device only:
/// `<documents>/drafts/<id>/` holding story.json, bg.jpg, bg_original.jpg
/// and thumb.png.
class DraftStore {
  DraftStore._();

  static final instance = DraftStore._();

  /// Bumped after every save/delete so the home screen can refresh.
  final revision = ValueNotifier<int>(0);

  Future<Directory> _root() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/drafts');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String newId() => DateTime.now().millisecondsSinceEpoch.toString();

  Future<List<DraftSummary>> list() async {
    try {
      final root = await _root();
      final result = <DraftSummary>[];
      await for (final e in root.list()) {
        if (e is! Directory) continue;
        final json = File('${e.path}/story.json');
        if (!await json.exists()) continue;
        final thumb = File('${e.path}/thumb.png');
        result.add(DraftSummary(
          e.uri.pathSegments.where((p) => p.isNotEmpty).last,
          await json.lastModified(),
          await thumb.exists() ? await thumb.readAsBytes() : null,
        ));
      }
      result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return result;
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(
    String id,
    StoryBackground background,
    List<StoryLayer> layers, {
    Uint8List? thumbnail,
  }) async {
    final dir = Directory('${(await _root()).path}/$id');
    await dir.create(recursive: true);
    if (background.isImage) {
      await File('${dir.path}/bg.jpg').writeAsBytes(background.imageBytes!);
      final original = background.originalImageBytes;
      final originalFile = File('${dir.path}/bg_original.jpg');
      if (original != null && !identical(original, background.imageBytes)) {
        await originalFile.writeAsBytes(original);
      } else if (await originalFile.exists()) {
        await originalFile.delete();
      }
    }
    if (thumbnail != null) {
      await File('${dir.path}/thumb.png').writeAsBytes(thumbnail);
    }
    await File('${dir.path}/story.json').writeAsString(jsonEncode({
      'version': 1,
      'background': background.toJson(),
      'layers': [for (final l in layers) l.toJson()],
    }));
    revision.value++;
  }

  Future<LoadedDraft?> load(String id) async {
    try {
      final dir = '${(await _root()).path}/$id';
      final json = jsonDecode(await File('$dir/story.json').readAsString())
          as Map<String, dynamic>;
      final bg = File('$dir/bg.jpg');
      final original = File('$dir/bg_original.jpg');
      final image = await bg.exists() ? await bg.readAsBytes() : null;
      final background = StoryBackground.fromJson(
        json['background'] as Map<String, dynamic>,
        image: image,
        original: await original.exists() ? await original.readAsBytes() : image,
      );
      final layers = [
        for (final l in json['layers'] as List)
          StoryLayer.fromJson(l as Map<String, dynamic>),
      ];
      return LoadedDraft(background, layers);
    } catch (_) {
      return null;
    }
  }

  Future<void> delete(String id) async {
    final dir = Directory('${(await _root()).path}/$id');
    if (await dir.exists()) await dir.delete(recursive: true);
    revision.value++;
  }
}
