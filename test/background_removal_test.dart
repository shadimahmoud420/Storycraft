import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:storycraft/models/story_background.dart';
import 'package:storycraft/models/story_layer.dart';
import 'package:storycraft/services/background_remover.dart';
import 'package:storycraft/state/editor_controller.dart';

const _channel = MethodChannel('subject_cutout');

/// 100×80 transparent PNG with an opaque 20×40 block at (30, 20).
Uint8List _subjectPng() {
  final im = img.Image(width: 100, height: 80, numChannels: 4);
  img.fillRect(im, x1: 30, y1: 20, x2: 49, y2: 59,
      color: img.ColorRgba8(200, 50, 50, 255));
  return img.encodePng(im);
}

Uint8List _photoJpg() =>
    img.encodeJpg(img.Image(width: 100, height: 80)..clear(img.ColorRgb8(9, 9, 9)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(_channel, null));

  test('trimTransparent crops to the subject with a small margin', () {
    final cut = trimTransparent(_subjectPng())!;
    expect(cut.width, inInclusiveRange(20, 24));
    expect(cut.height, inInclusiveRange(40, 44));
    expect(cut.widthFraction, closeTo(cut.width / 100, 1e-9));
  });

  test('trimTransparent rejects an empty result', () {
    final empty = img.encodePng(img.Image(width: 50, height: 50, numChannels: 4));
    expect(trimTransparent(empty), isNull);
  });

  test('cutting out the photo adds the subject on a new background', () async {
    messenger.setMockMethodCallHandler(_channel, (call) async => _subjectPng());
    final c = EditorController(StoryBackground.image(_photoJpg()));
    c.addText('Hi');
    const bg = StoryBackground.gradient([Color(0xFF000000), Color(0xFFFFFFFF)]);
    await c.cutoutBackground(bg);

    expect(c.background.kind, BackgroundKind.gradient);
    expect(c.layers.first.kind, LayerKind.image); // behind the text
    expect(c.layers.last.text, 'Hi');
    expect(c.isBusy, isFalse);
    c.undo();
    expect(c.background.isImage, isTrue);
    expect(c.layers, hasLength(1));
  });

  test('cutting out an image layer keeps its scale', () async {
    messenger.setMockMethodCallHandler(_channel, (call) async => _subjectPng());
    final c = EditorController(const StoryBackground.solid(Color(0xFFFFFFFF)));
    final layer = c.addImage(_photoJpg(), size: 200);
    await c.cutoutLayer(layer.id);
    expect(c.layers.single.size, lessThan(50)); // ~22% of 200
  });

  test('no subject leaves the story untouched', () async {
    messenger.setMockMethodCallHandler(
        _channel, (call) async => throw PlatformException(code: 'no_subject'));
    final c = EditorController(StoryBackground.image(_photoJpg()));
    await expectLater(
      c.cutoutBackground(const StoryBackground.solid(Color(0xFF000000))),
      throwsA(isA<CutoutException>()
          .having((e) => e.error, 'error', CutoutError.noSubject)),
    );
    expect(c.background.isImage, isTrue);
    expect(c.layers, isEmpty);
    expect(c.isBusy, isFalse);
  });

  test('missing platform support is reported', () async {
    final c = EditorController(StoryBackground.image(_photoJpg()));
    await expectLater(
      c.cutoutBackground(const StoryBackground.solid(Color(0xFF000000))),
      throwsA(isA<CutoutException>()
          .having((e) => e.error, 'error', CutoutError.unsupported)),
    );
  });
}
