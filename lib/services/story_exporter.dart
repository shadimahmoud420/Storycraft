import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:gal/gal.dart';
import 'package:instagram_story_share/instagram_story_share.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/config.dart';

enum StoryShareOutcome { instagram, shareSheet, failed }

/// Renders the story canvas to a 1080 x 1920 PNG and hands it to
/// Instagram, the system share sheet or the photo gallery.
class StoryExporter {
  StoryExporter(this.boundaryKey);

  final GlobalKey boundaryKey;

  Future<File> renderToFile() async {
    // Wait for any pending frame so the capture is up to date.
    await WidgetsBinding.instance.endOfFrame;
    final boundary = boundaryKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    final image =
        await boundary.toImage(pixelRatio: AppConfig.exportPixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/storycraft_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(data!.buffer.asUint8List(), flush: true);
    return file;
  }

  /// Opens Instagram's story composer with the design as the background.
  /// Falls back to the system share sheet when that is not possible.
  Future<StoryShareOutcome> shareToInstagramStory() async {
    final file = await renderToFile();
    if (AppConfig.facebookAppId.isNotEmpty) {
      final ok = await InstagramStoryShare.shareBackgroundImage(
        imagePath: file.path,
        appId: AppConfig.facebookAppId,
      );
      if (ok) return StoryShareOutcome.instagram;
    }
    return await _shareSheet(file)
        ? StoryShareOutcome.shareSheet
        : StoryShareOutcome.failed;
  }

  Future<bool> shareViaSheet() async => _shareSheet(await renderToFile());

  /// Saves the design to the photo gallery. Returns false when the user
  /// denied access or saving failed.
  Future<bool> saveToGallery() async {
    try {
      if (!await Gal.hasAccess()) {
        if (!await Gal.requestAccess()) return false;
      }
      final file = await renderToFile();
      await Gal.putImage(file.path);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _shareSheet(File file) async {
    try {
      final box = boundaryKey.currentContext?.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          // Required on iPad for the popover anchor.
          sharePositionOrigin:
              box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
