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

  colorKeyTests();

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

/// White canvas with a dark 4px ring (outer 60, inner 52) centered.
Uint8List _ringPng() {
  final im = img.Image(width: 120, height: 120)..clear(img.ColorRgb8(255, 255, 255));
  img.fillCircle(im, x: 60, y: 60, radius: 30, color: img.ColorRgb8(10, 20, 80));
  img.fillCircle(im, x: 60, y: 60, radius: 26, color: img.ColorRgb8(255, 255, 255));
  return img.encodeJpg(im, quality: 95);
}

int _alphaAtCenter(Cutout c) {
  final im = img.decodePng(c.png)!;
  return im.getPixel(im.width ~/ 2, im.height ~/ 2).a.toInt();
}

void colorKeyTests() {
  test('color key removes white, also inside loops, keeps the ink', () {
    final cut = colorKey(_ringPng(), const ColorKeyOptions())!;
    expect(cut.width, inInclusiveRange(58, 70)); // trimmed to the ring
    expect(_alphaAtCenter(cut), 0); // inside the loop is cleared
    final im = img.decodePng(cut.png)!;
    final ink = im.getPixel(im.width ~/ 2, 2); // top of the ring
    expect(ink.a.toInt(), greaterThan(200));
    expect(ink.b.toInt(), greaterThan(ink.r.toInt())); // still navy
  });

  test('edges-only keeps enclosed background-colored areas', () {
    final cut =
        colorKey(_ringPng(), const ColorKeyOptions(edgesOnly: true))!;
    expect(_alphaAtCenter(cut), 255);
  });

  test('recolor paints the drawing in one color', () {
    final cut = colorKey(
        _ringPng(), const ColorKeyOptions(recolor: 0xFFD4AF37))!;
    final im = img.decodePng(cut.png)!;
    final p = im.getPixel(im.width ~/ 2, 2);
    expect([p.r.toInt(), p.g.toInt(), p.b.toInt()], [0xD4, 0xAF, 0x37]);
  });

  test('a blank page has nothing to keep', () {
    final blank = img.encodePng(
        img.Image(width: 80, height: 80)..clear(img.ColorRgb8(250, 250, 250)));
    expect(colorKey(blank, const ColorKeyOptions()), isNull);
  });
}
