import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/fonts.dart';
import '../models/story_background.dart';
import '../models/text_layer.dart';
import '../services/image_processing.dart';

enum ImageOperation { natural, enhance }

/// Holds the whole story being edited.
class EditorController extends ChangeNotifier {
  EditorController(this._background);

  StoryBackground _background;
  final List<TextLayer> _layers = [];
  String? _selectedId;
  ImageOperation? _busy;
  bool _dirty = false;
  int _nextId = 0;

  StoryBackground get background => _background;
  List<TextLayer> get layers => List.unmodifiable(_layers);
  String? get selectedId => _selectedId;
  TextLayer? get selected =>
      _layers.where((l) => l.id == _selectedId).firstOrNull;
  ImageOperation? get busy => _busy;
  bool get isBusy => _busy != null;
  bool get hasChanges => _dirty;

  // --- Background -----------------------------------------------------------

  void setBackground(StoryBackground bg) {
    _background = bg;
    _changed();
  }

  void toggleImageFit() {
    if (!_background.isImage) return;
    _background = _background.withFit(
      _background.imageFit == ImageFit.cover ? ImageFit.contain : ImageFit.cover,
    );
    _changed();
  }

  void restoreOriginalImage() {
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

  // --- Text layers ----------------------------------------------------------

  TextLayer addText(String text, {StoryFont? font}) {
    final layer = TextLayer(
      id: 'layer_${_nextId++}',
      text: text,
      font: font ?? StoryFonts.defaultFor(text),
      color: suggestTextColor(),
      shadow: _background.isImage,
    );
    _layers.add(layer);
    _selectedId = layer.id;
    _changed();
    return layer;
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

  /// Applies [update] to a layer and repaints.
  void updateLayer(String id, void Function(TextLayer layer) update) {
    final layer = _layers.where((l) => l.id == id).firstOrNull;
    if (layer == null) return;
    update(layer);
    _changed();
  }

  void removeLayer(String id) {
    _layers.removeWhere((l) => l.id == id);
    if (_selectedId == id) _selectedId = null;
    _changed();
  }

  void duplicateLayer(String id) {
    final layer = _layers.where((l) => l.id == id).firstOrNull;
    if (layer == null) return;
    final copy = layer.copyWith(
      id: 'layer_${_nextId++}',
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
