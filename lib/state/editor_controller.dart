import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/art.dart';
import '../data/fonts.dart';
import '../models/story_background.dart';
import '../models/story_layer.dart';
import '../services/image_processing.dart';

enum ImageOperation { natural, enhance }

class _Snapshot {
  _Snapshot(this.background, this.layers, this.selectedId);

  final StoryBackground background;
  final List<StoryLayer> layers;
  final String? selectedId;
}

/// Holds the whole story being edited, with undo/redo history.
class EditorController extends ChangeNotifier {
  EditorController(this._background, {List<StoryLayer> layers = const []}) {
    // Fresh ids: template layers share placeholder ids.
    _layers.addAll(layers.map((l) => l.copyWith(id: _newId())));
  }

  static const _maxHistory = 40;

  StoryBackground _background;
  final List<StoryLayer> _layers = [];
  String? _selectedId;
  ImageOperation? _busy;
  bool _dirty = false;
  int _nextId = 0;
  final List<_Snapshot> _undo = [];
  final List<_Snapshot> _redo = [];

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
    _background = s.background;
    _layers
      ..clear()
      ..addAll(s.layers.map((l) => l.clone()));
    _selectedId =
        _layers.any((l) => l.id == s.selectedId) ? s.selectedId : null;
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

  StoryLayer addImage(Uint8List bytes) => addLayer(StoryLayer(
        id: _newId(),
        kind: LayerKind.image,
        imageBytes: bytes,
        size: 120,
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
        position: const Offset(180, 150),
      ),
      keepPosition: wide,
    );
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
    const candidates = [320.0, 390.0, 250.0, 460.0, 180.0, 520.0, 120.0];
    for (final y in candidates) {
      if (_layers.every((l) => (l.position.dx - x).abs() > 120 ||
          (l.position.dy - y).abs() >= minGap)) {
        return Offset(x, y);
      }
    }
    return const Offset(x, 320);
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
