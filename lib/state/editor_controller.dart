import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/art.dart';
import '../data/filters.dart';
import '../data/formats.dart';
import '../data/fonts.dart';
import '../models/story_background.dart';
import '../models/story_layer.dart';
import '../services/background_remover.dart';
import '../services/image_processing.dart';

enum ImageOperation { natural, enhance, cutout }

class _Snapshot {
  _Snapshot(this.format, this.background, this.layers, this.selectedId);

  final StoryFormat format;
  final StoryBackground background;
  final List<StoryLayer> layers;
  final String? selectedId;
}

/// Holds the whole story being edited, with undo/redo history.
class EditorController extends ChangeNotifier {
  EditorController(
    this._background, {
    List<StoryLayer> layers = const [],
    StoryFormat format = StoryFormat.story,
  }) : _format = format {
    // Fresh ids: template layers share placeholder ids.
    _layers.addAll(layers.map((l) => l.copyWith(id: _newId())));
  }

  static const _maxHistory = 40;

  StoryFormat _format;
  StoryBackground _background;
  final List<StoryLayer> _layers = [];
  String? _selectedId;
  ImageOperation? _busy;
  bool _dirty = false;
  int _nextId = 0;
  final List<_Snapshot> _undo = [];
  final List<_Snapshot> _redo = [];

  StoryFormat get format => _format;
  Size get canvasSize => _format.size;
  StoryBackground get background => _background;
  List<StoryLayer> get layers => List.unmodifiable(_layers);
  String? get selectedId => _selectedId;
  StoryLayer? get selected =>
      _layers.where((l) => l.id == _selectedId).firstOrNull;
  ImageOperation? get busy => _busy;
  bool get isBusy => _busy != null;
  bool get hasChanges => _dirty;
  bool get canUndo => _undo.isNotEmpty && !isBusy;
  bool get canRedo => _redo.isNotEmpty && !isBusy;

  /// Marks the current state as saved (e.g. after a draft save).
  void markSaved() => _dirty = false;

  // --- History --------------------------------------------------------------

  _Snapshot _snapshot() => _Snapshot(
        _format,
        _background,
        [for (final l in _layers) l.clone()],
        _selectedId,
      );

  /// Records the current state so the next change can be undone.
  /// Call once before a change (or once at the start of a gesture).
  void checkpoint() {
    _undo.add(_snapshot());
    if (_undo.length > _maxHistory) _undo.removeAt(0);
    _redo.clear();
  }

  void undo() {
    if (!canUndo) return;
    _redo.add(_snapshot());
    _restore(_undo.removeLast());
  }

  void redo() {
    if (!canRedo) return;
    _undo.add(_snapshot());
    _restore(_redo.removeLast());
  }

  void _restore(_Snapshot s) {
    _format = s.format;
    _background = s.background;
    _layers
      ..clear()
      ..addAll(s.layers.map((l) => l.clone()));
    _selectedId =
        _layers.any((l) => l.id == s.selectedId) ? s.selectedId : null;
    _changed();
  }

  // --- Format ---------------------------------------------------------------

  /// Switches the canvas ratio; layers keep their relative positions.
  void setFormat(StoryFormat format) {
    if (format == _format) return;
    checkpoint();
    final ratio = format.size.height / _format.size.height;
    for (final l in _layers) {
      l.position = Offset(l.position.dx, l.position.dy * ratio);
    }
    _format = format;
    _background = _background.copyWith(imageOffset: Offset.zero, imageScale: 1);
    _changed();
  }

  // --- Background -----------------------------------------------------------

  void setBackground(StoryBackground bg) {
    checkpoint();
    _background = bg;
    _changed();
  }

  void toggleImageFit() {
    if (!_background.isImage) return;
    checkpoint();
    _background = _background.withFit(
      _background.imageFit == ImageFit.cover ? ImageFit.contain : ImageFit.cover,
    );
    _changed();
  }

  /// Cycles the readability dim: 0 → 20% → 40% → 60% → 0.
  void cycleDim() {
    if (!_background.isImage) return;
    checkpoint();
    final next = _background.dim >= 0.59 ? 0.0 : _background.dim + 0.2;
    _background = _background.copyWith(dim: next);
    _changed();
  }

  /// Live filter change (call [checkpoint] when the filter sheet opens).
  void setFilter(PhotoFilter filter, double intensity) {
    if (!_background.isImage) return;
    _background =
        _background.copyWith(filter: filter, filterIntensity: intensity);
    _changed();
  }

  /// Live pan/zoom of the photo (call [checkpoint] when the gesture starts).
  void transformImage(Offset offset, double scale) {
    _background = _background.copyWith(
      imageOffset: offset,
      imageScale: scale.clamp(1.0, 5.0),
    );
    _changed();
  }

  void restoreOriginalImage() {
    checkpoint();
    _background = _background.restoreOriginal();
    _changed();
  }

  /// Runs a one-tap photo operation. Returns false on failure.
  Future<bool> runImageOperation(ImageOperation op) async {
    final bytes = _background.imageBytes;
    if (bytes == null || isBusy) return false;
    _busy = op;
    notifyListeners();
    try {
      final Uint8List result = switch (op) {
        ImageOperation.natural => await ImageProcessing.naturalColors(bytes),
        ImageOperation.enhance => await ImageProcessing.enhance(bytes),
        ImageOperation.cutout => throw ArgumentError.value(op),
      };
      checkpoint();
      _background = _background.withImage(result);
      _dirty = true;
      return true;
    } catch (_) {
      return false;
    } finally {
      _busy = null;
      notifyListeners();
    }
  }

  // --- Background removal ---------------------------------------------------

  /// Cuts the subject out of the photo background: the subject becomes an
  /// image layer and the background turns into [newBackground], ready to
  /// change. Throws [CutoutException]; one undo step.
  Future<void> cutoutBackground(StoryBackground newBackground) async {
    final bytes = _background.imageBytes;
    if (bytes == null || isBusy) return;
    final cut = await _whileBusy(() => BackgroundRemover.cutout(bytes));
    checkpoint();
    _background = newBackground;
    // As large as fits in the safe area, standing on the lower part.
    final h = canvasSize.height;
    final width = math.min(330.0, h * 0.72 / cut.aspect);
    final layer = StoryLayer(
      id: _newId(),
      kind: LayerKind.image,
      imageBytes: cut.png,
      size: width,
      position: Offset(180, h * 0.84 - width * cut.aspect / 2),
    );
    _layers.insert(0, layer); // behind existing text
    _selectedId = layer.id;
    _changed();
  }

  /// Removes the background of an image layer in place (e.g. an added
  /// photo). Throws [CutoutException]; one undo step.
  Future<void> cutoutLayer(String id) async {
    final layer = _layers.where((l) => l.id == id).firstOrNull;
    final bytes = layer?.imageBytes;
    if (layer == null || bytes == null || isBusy) return;
    final cut = await _whileBusy(() => BackgroundRemover.cutout(bytes));
    updateLayer(id, (l) {
      l.imageBytes = cut.png;
      l.size *= cut.widthFraction;
    });
  }

  Future<T> _whileBusy<T>(Future<T> Function() task) async {
    _busy = ImageOperation.cutout;
    notifyListeners();
    try {
      return await task();
    } finally {
      _busy = null;
      notifyListeners();
    }
  }

  // --- Layers ---------------------------------------------------------------

  String _newId() => 'layer_${_nextId++}_${DateTime.now().microsecond}';

  StoryLayer addText(String text, {StoryFont? font, double? fontSize}) {
    return addLayer(StoryLayer(
      id: _newId(),
      text: text,
      font: font ?? StoryFonts.defaultFor(text),
      fontSize: fontSize ?? 32,
      color: suggestTextColor(),
      shadow: _background.isImage,
    ));
  }

  StoryLayer addEmoji(String emoji) => addLayer(StoryLayer(
        id: _newId(),
        kind: LayerKind.emoji,
        text: emoji,
        fontSize: 72,
        color: suggestTextColor(),
      ));

  StoryLayer addShape(ShapeKind shape) => addLayer(StoryLayer(
        id: _newId(),
        kind: LayerKind.shape,
        shape: shape,
        size: shape == ShapeKind.line ? 200 : 180,
        color: suggestTextColor(),
      ));

  StoryLayer addImage(Uint8List bytes, {double size = 120}) =>
      addLayer(StoryLayer(
        id: _newId(),
        kind: LayerKind.image,
        imageBytes: bytes,
        size: size,
      ));

  /// Cartoon illustration from assets/stickers. Wide art (garlands,
  /// bunting) spans the top of the story instead of the center.
  StoryLayer addArt(String name) {
    final wide = StoryArt.isWide(name);
    return addLayer(
      StoryLayer(
        id: _newId(),
        kind: LayerKind.art,
        text: name,
        size: wide ? 360 : 150,
        position: Offset(180, canvasSize.height * 0.23),
      ),
      keepPosition: wide,
    );
  }

  /// Places a saved signature in the bottom corner (inside the story safe
  /// zone), on the reading side's end.
  StoryLayer addSignature(StoryLayer signature) => addLayer(
        signature.copyWith(
          id: _newId(),
          position: signatureSpot(signature.text, _format),
        ),
        keepPosition: true,
      );

  /// Bottom corner on the name's reading-end side, inside Instagram's
  /// safe zone for stories.
  static Offset signatureSpot(String name, StoryFormat format) {
    final h = format.size.height;
    final rtl = StoryFonts.hasArabic(name);
    final y = format == StoryFormat.story ? h * 0.74 : h * 0.86;
    return Offset(rtl ? 110 : 250, y);
  }

  /// Adds a ready-made layer with a fresh id, placed in a free spot.
  StoryLayer addLayer(StoryLayer layer, {bool keepPosition = false}) {
    checkpoint();
    final l = layer.copyWith(
      id: _newId(),
      position: keepPosition ? layer.position : _freeSpot(),
    );
    _layers.add(l);
    _selectedId = l.id;
    _changed();
    return l;
  }

  /// First spot down the center column (inside Instagram's safe zone)
  /// that no existing layer occupies, so new items never cover old ones.
  Offset _freeSpot() {
    const x = 180.0, minGap = 56.0;
    final h = canvasSize.height;
    const fractions = [0.5, 0.61, 0.39, 0.72, 0.28, 0.81, 0.19];
    for (final f in fractions) {
      final y = h * f;
      if (_layers.every((l) => (l.position.dx - x).abs() > 120 ||
          (l.position.dy - y).abs() >= minGap)) {
        return Offset(x, y);
      }
    }
    return Offset(x, h / 2);
  }

  void select(String? id) {
    if (_selectedId == id) return;
    _selectedId = id;
    if (id != null) {
      // Bring the selected layer to the front.
      final i = _layers.indexWhere((l) => l.id == id);
      if (i >= 0) _layers.add(_layers.removeAt(i));
    }
    notifyListeners();
  }

  /// Applies [update] to a layer and repaints. Pass `record: false` for
  /// live gesture updates (a checkpoint is taken when the gesture starts).
  void updateLayer(
    String id,
    void Function(StoryLayer layer) update, {
    bool record = true,
  }) {
    final layer = _layers.where((l) => l.id == id).firstOrNull;
    if (layer == null) return;
    if (record) checkpoint();
    update(layer);
    _changed();
  }

  void removeLayer(String id) {
    checkpoint();
    _layers.removeWhere((l) => l.id == id);
    if (_selectedId == id) _selectedId = null;
    _changed();
  }

  void duplicateLayer(String id) {
    final layer = _layers.where((l) => l.id == id).firstOrNull;
    if (layer == null) return;
    checkpoint();
    final copy = layer.copyWith(
      id: _newId(),
      position: layer.position + const Offset(16, 24),
    );
    _layers.add(copy);
    _selectedId = copy.id;
    _changed();
  }

  /// Black or white, whichever reads better on the current background.
  Color suggestTextColor() {
    final bg = switch (_background.kind) {
      BackgroundKind.solid => _background.color,
      BackgroundKind.gradient => _background.gradientColors.first,
      BackgroundKind.image => Colors.black,
    };
    return bg.computeLuminance() > 0.55 ? Colors.black : Colors.white;
  }

  void _changed() {
    _dirty = true;
    notifyListeners();
  }
}
