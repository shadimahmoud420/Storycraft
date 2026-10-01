import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../services/face_beauty.dart';

/// Result of the beauty studio: the retouched JPEG and the settings used
/// (so reopening starts from them, always from the original photo).
typedef BeautyResult = ({Uint8List bytes, BeautySettings settings});

/// Face-only retouching with live preview: skin, eyes, lips and nose.
/// Press and hold the photo to compare with the original.
class BeautyScreen extends StatefulWidget {
  const BeautyScreen({
    super.key,
    required this.imageBytes,
    this.initial = BeautySettings.natural,
  });

  final Uint8List imageBytes;
  final BeautySettings initial;

  @override
  State<BeautyScreen> createState() => _BeautyScreenState();
}

class _BeautyScreenState extends State<BeautyScreen> {
  late BeautySettings _settings = widget.initial;
  BeautyPreview? _preview;
  ui.Image? _original;
  ui.Image? _shown;
  BeautyError? _error;
  bool _comparing = false;
  bool _rendering = false;
  bool _pending = false;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _original?.dispose();
    _shown?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await FaceBeauty.preview(widget.imageBytes);
      final original = await _toImage(p.rgba, p.width, p.height);
      if (!mounted) return;
      setState(() {
        _preview = p;
        _original = original;
      });
      _render();
    } on BeautyException catch (e) {
      if (mounted) setState(() => _error = e.error);
    } catch (_) {
      if (mounted) setState(() => _error = BeautyError.failed);
    }
  }

  static Future<ui.Image> _toImage(Uint8List rgba, int w, int h) {
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(
        rgba, w, h, ui.PixelFormat.rgba8888, done.complete);
    return done.future;
  }

  /// Renders the preview; slider moves during a render are coalesced into
  /// one follow-up render.
  Future<void> _render() async {
    final p = _preview;
    if (p == null) return;
    if (_rendering) {
      _pending = true;
      return;
    }
    _rendering = true;
    try {
      do {
        _pending = false;
        final pixels = await FaceBeauty.render(p, _settings);
        final image = await _toImage(pixels, p.width, p.height);
        if (!mounted) {
          image.dispose();
          return;
        }
        final old = _shown;
        setState(() => _shown = image);
        old?.dispose();
      } while (_pending);
    } finally {
      _rendering = false;
    }
  }

  void _set(BeautySettings s) {
    setState(() => _settings = s);
    _render();
  }

  Future<void> _apply() async {
    final p = _preview;
    if (p == null) return;
    setState(() => _applying = true);
    try {
      final bytes = await FaceBeauty.apply(widget.imageBytes, p, _settings);
      if (mounted) {
        Navigator.pop<BeautyResult>(
            context, (bytes: bytes, settings: _settings));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _applying = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.of(context).processFailed)));
      }
    }
  }

  String _errorText(S s) => switch (_error!) {
        BeautyError.noFace => s.beautyNoFace,
        BeautyError.unsupported => s.beautyUnsupported,
        BeautyError.preparing => s.removeBgPreparing,
        BeautyError.failed => s.processFailed,
      };

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final image = _comparing ? _original : (_shown ?? _original);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(s.beauty),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: FilledButton.icon(
              onPressed: _preview == null || _applying ? null : _apply,
              icon: _applying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(s.apply),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.face_retouching_off_rounded,
                                color: Colors.white54, size: 56),
                            const SizedBox(height: 12),
                            Text(_errorText(s),
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white)),
                          ],
                        ),
                      )
                    : image == null
                        ? const Center(child: CircularProgressIndicator())
                        : GestureDetector(
                            onLongPressStart: (_) =>
                                setState(() => _comparing = true),
                            onLongPressEnd: (_) =>
                                setState(() => _comparing = false),
                            child: Center(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: RawImage(
                                    image: image, fit: BoxFit.contain),
                              ),
                            ),
                          ),
              ),
            ),
            if (_error == null) ...[
              Text(s.beautyHold,
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 4),
              _SliderRow(
                icon: Icons.face_retouching_natural_rounded,
                label: s.beautySkin,
                value: _settings.skin,
                onChanged: (v) => _set(_settings.copyWith(skin: v)),
              ),
              _SliderRow(
                icon: Icons.remove_red_eye_rounded,
                label: s.beautyEyes,
                value: _settings.eyes,
                onChanged: (v) => _set(_settings.copyWith(eyes: v)),
              ),
              _SliderRow(
                icon: Icons.favorite_rounded,
                label: s.beautyLips,
                value: _settings.lips,
                onChanged: (v) => _set(_settings.copyWith(lips: v)),
              ),
              _SliderRow(
                icon: Icons.face_rounded,
                label: s.beautyNose,
                value: _settings.nose,
                onChanged: (v) => _set(_settings.copyWith(nose: v)),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 8),
          SizedBox(
            width: 92,
            child: Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
          Expanded(
            child: Slider(
              value: value,
              // Rendering is async; updating per change keeps it live.
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 40,
            child: Text('${(value * 100).round()}%',
                textDirection: TextDirection.ltr,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
