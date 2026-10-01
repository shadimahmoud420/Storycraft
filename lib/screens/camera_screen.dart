import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';

import '../core/strings.dart';
import '../data/filters.dart';
import '../models/story_background.dart';
import '../services/face_beauty.dart';
import '../services/image_processing.dart';
import 'beauty_screen.dart';
import 'editor_screen.dart';

/// Filters offered in the camera, in order.
const cameraFilters = [
  PhotoFilter.none,
  PhotoFilter.glow,
  PhotoFilter.food,
  PhotoFilter.nature,
  PhotoFilter.vivid,
  PhotoFilter.warm,
  PhotoFilter.cool,
  PhotoFilter.mono,
  PhotoFilter.vintage,
];

String filterLabel(S s, PhotoFilter f) => switch (f) {
      PhotoFilter.none => s.fNone,
      PhotoFilter.glow => s.fGlow,
      PhotoFilter.food => s.fFood,
      PhotoFilter.nature => s.fNature,
      PhotoFilter.vivid => s.fVivid,
      PhotoFilter.warm => s.fWarm,
      PhotoFilter.cool => s.fCool,
      PhotoFilter.vintage => s.fVintage,
      PhotoFilter.mono => s.fMono,
      PhotoFilter.fade => s.fFade,
      PhotoFilter.drama => s.fDrama,
      PhotoFilter.rose => s.fRose,
    };

/// Default strength per filter (Glow's colors are best a little softer).
double defaultStrength(PhotoFilter f) => f == PhotoFilter.glow ? 0.6 : 0.85;

/// [child] with a filter's colors. Nothing is blurred: Glow's face
/// retouch is applied to the photo itself, on the face only.
Widget filteredView(PhotoFilter f, double strength, Widget child) =>
    f == PhotoFilter.none
        ? child
        : ColorFiltered(
            colorFilter:
                ColorFilter.matrix(PhotoFilters.blended(f, strength)),
            child: child,
          );

/// Professional camera: 4K capture (best available on older phones),
/// live filters with strength, flash, timer, grid, zoom and tap-to-focus.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  List<CameraDescription> _cameras = const [];
  int _index = 0;
  CameraController? _controller;
  String? _error;

  PhotoFilter _filter = PhotoFilter.none;
  double _strength = 0.85;
  FlashMode _flash = FlashMode.off;
  int _timer = 0; // seconds
  bool _grid = false;
  double _zoom = 1, _minZoom = 1, _maxZoom = 1, _baseZoom = 1;
  Offset? _focus;
  int? _countdown;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setup();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (state == AppLifecycleState.inactive) {
      _controller = null;
      c?.dispose();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && c == null &&
        _cameras.isNotEmpty) {
      _start(_cameras[_index]);
    }
  }

  Future<void> _setup() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _error = 'none');
        return;
      }
      _index = _cameras.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.back);
      if (_index < 0) _index = 0;
      await _start(_cameras[_index]);
    } catch (_) {
      if (mounted) setState(() => _error = 'denied');
    }
  }

  Future<void> _start(CameraDescription description) async {
    final old = _controller;
    _controller = null;
    await old?.dispose();
    // ultraHigh = 3840 x 2160 (4K), falling back to the best the phone has.
    final c = CameraController(
      description,
      ResolutionPreset.ultraHigh,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await c.initialize();
      await c.setFlashMode(_flash);
      _minZoom = await c.getMinZoomLevel();
      _maxZoom = await c.getMaxZoomLevel();
      _zoom = _minZoom;
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _controller = c;
        _error = null;
      });
    } on CameraException catch (e) {
      await c.dispose();
      if (mounted) {
        setState(() => _error =
            e.code.toLowerCase().contains('denied') ? 'denied' : 'failed');
      }
    }
  }

  String get _resolutionLabel {
    final size = _controller?.value.previewSize;
    if (size == null) return '';
    final long = size.longestSide;
    if (long >= 3840) return '4K';
    if (long >= 1920) return 'FHD';
    return 'HD';
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    _index = (_index + 1) % _cameras.length;
    await _start(_cameras[_index]);
  }

  Future<void> _cycleFlash() async {
    const order = [FlashMode.off, FlashMode.auto, FlashMode.always];
    final next = order[(order.indexOf(_flash) + 1) % order.length];
    try {
      await _controller?.setFlashMode(next);
      setState(() => _flash = next);
    } catch (_) {}
  }

  Future<void> _focusAt(TapUpDetails d, Size size) async {
    final c = _controller;
    if (c == null) return;
    final p = Offset(
      (d.localPosition.dx / size.width).clamp(0.0, 1.0),
      (d.localPosition.dy / size.height).clamp(0.0, 1.0),
    );
    setState(() => _focus = d.localPosition);
    try {
      await c.setFocusPoint(p);
      await c.setExposurePoint(p);
    } catch (_) {}
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _focus = null);
    });
  }

  Future<void> _capture() async {
    final c = _controller;
    if (c == null || _capturing) return;
    setState(() => _capturing = true);
    try {
      for (var t = _timer; t > 0; t--) {
        setState(() => _countdown = t);
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
      }
      setState(() => _countdown = null);
      final file = await c.takePicture();
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      final result = await Navigator.of(context).push<_ReviewResult>(
        MaterialPageRoute(
          builder: (_) => _ReviewScreen(
            bytes: bytes,
            filter: _filter,
            strength: _strength,
          ),
        ),
      );
      if (result != null && mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => EditorScreen(initialBackground: result.background),
        ));
      }
    } catch (_) {
      // Ignore a failed shot; the preview keeps running.
    } finally {
      if (mounted) {
        setState(() {
          _capturing = false;
          _countdown = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: s.flash,
                    onPressed: _cycleFlash,
                    icon: Icon(
                      switch (_flash) {
                        FlashMode.auto => Icons.flash_auto_rounded,
                        FlashMode.always => Icons.flash_on_rounded,
                        _ => Icons.flash_off_rounded,
                      },
                      color: Colors.white,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() =>
                        _timer = _timer == 0 ? 3 : (_timer == 3 ? 10 : 0)),
                    icon: Icon(Icons.timer_outlined,
                        color: _timer > 0 ? Colors.amber : Colors.white),
                    label: Text(_timer > 0 ? '${_timer}s' : '',
                        style: const TextStyle(color: Colors.amber)),
                  ),
                  IconButton(
                    tooltip: s.grid,
                    onPressed: () => setState(() => _grid = !_grid),
                    icon: Icon(Icons.grid_on_rounded,
                        color: _grid ? Colors.amber : Colors.white),
                  ),
                  if (_resolutionLabel.isNotEmpty)
                    Container(
                      margin: const EdgeInsetsDirectional.only(start: 6, end: 8),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white70),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(_resolutionLabel,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                    ),
                ],
              ),
            ),

            // Preview (9:16, cropped to fill).
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: LayoutBuilder(
                      builder: (context, box) {
                        if (c == null || !c.value.isInitialized) {
                          return _Placeholder(error: _error);
                        }
                        final preview = c.value.previewSize!;
                        return GestureDetector(
                          onTapUp: (d) => _focusAt(d, box.biggest),
                          onScaleStart: (_) => _baseZoom = _zoom,
                          onScaleUpdate: (d) {
                            final z = (_baseZoom * d.scale)
                                .clamp(_minZoom, _maxZoom.clamp(1.0, 10.0));
                            if ((z - _zoom).abs() > 0.01) {
                              _zoom = z;
                              c.setZoomLevel(z);
                              setState(() {});
                            }
                          },
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              filteredView(
                                _filter,
                                _strength,
                                FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    // Sensor sizes are landscape.
                                    width: preview.shortestSide,
                                    height: preview.longestSide,
                                    child: CameraPreview(c),
                                  ),
                                ),
                              ),
                              if (_grid)
                                const IgnorePointer(
                                    child: CustomPaint(painter: _GridPainter())),
                              if (_focus != null)
                                Positioned(
                                  left: _focus!.dx - 32,
                                  top: _focus!.dy - 32,
                                  child: Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Colors.amber, width: 1.5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              if (_filter == PhotoFilter.glow)
                                Positioned(
                                  top: 12,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                      child: _Pill('✨ ${s.beautyAfterShot}')),
                                ),
                              if (_zoom > _minZoom + 0.05)
                                Positioned(
                                  bottom: 12,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: _Pill(
                                        '${_zoom.toStringAsFixed(1)}x'),
                                  ),
                                ),
                              if (_countdown != null)
                                Center(
                                  child: Text('$_countdown',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 96,
                                          fontWeight: FontWeight.w800)),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

            // Strength.
            if (_filter != PhotoFilter.none)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(s.strength,
                        style: const TextStyle(color: Colors.white70)),
                    Expanded(
                      child: Slider(
                        value: _strength,
                        onChanged: (v) => setState(() => _strength = v),
                      ),
                    ),
                    SizedBox(
                      width: 42,
                      child: Text('${(_strength * 100).round()}%',
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),

            // Filters.
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final f in cameraFilters)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: ChoiceChip(
                        label: Text(filterLabel(s, f)),
                        selected: _filter == f,
                        onSelected: (_) => setState(() {
                          _filter = f;
                          _strength = defaultStrength(f);
                        }),
                      ),
                    ),
                ],
              ),
            ),

            // Shutter row.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48),
                  GestureDetector(
                    onTap: c == null ? null : _capture,
                    child: Container(
                      width: 78,
                      height: 78,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _capturing ? Colors.white54 : Colors.white,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _cameras.length < 2 ? null : _switchCamera,
                    icon: const Icon(Icons.cameraswitch_rounded,
                        color: Colors.white, size: 32),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ColoredBox(
      color: const Color(0xFF16161C),
      child: Center(
        child: error == null
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  error == 'none' ? s.cameraUnavailable : s.cameraDenied,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, height: 1.6),
                ),
              ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(text,
            textDirection: TextDirection.ltr,
            style: const TextStyle(color: Colors.white)),
      );
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white38
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final x = size.width * i / 3, y = size.height * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}

class _ReviewResult {
  const _ReviewResult(this.background);

  final StoryBackground background;
}

/// After the shot: tweak the filter, save the full-quality photo or turn it
/// into a story.
class _ReviewScreen extends StatefulWidget {
  const _ReviewScreen({
    required this.bytes,
    required this.filter,
    required this.strength,
  });

  final Uint8List bytes;
  final PhotoFilter filter;
  final double strength;

  @override
  State<_ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<_ReviewScreen> {
  late PhotoFilter _filter = widget.filter;
  late double _strength = widget.strength;
  bool _busy = false;

  /// The photo shown and used: the capture, or its face-retouched copy.
  late Uint8List _bytes = widget.bytes;

  /// Skin smoothing strength applied to [_bytes], if any.
  double? _beauty;
  bool _retouching = false;

  @override
  void initState() {
    super.initState();
    if (_filter == PhotoFilter.glow) _autoRetouch();
  }

  /// Glow smooths the skin automatically, at the strength chosen in the
  /// camera; photos without a face simply keep Glow's colors.
  Future<void> _autoRetouch() async {
    if (_beauty != null || _retouching) return;
    setState(() => _retouching = true);
    try {
      final strength = _strength;
      final out = await FaceBeauty.auto(widget.bytes, strength);
      if (mounted && _beauty == null) {
        setState(() {
          _bytes = out;
          _beauty = strength;
        });
      }
    } catch (_) {
      // No face (or unsupported): nothing to retouch.
    } finally {
      if (mounted) setState(() => _retouching = false);
    }
  }

  /// Adjust the smoothing, always starting from the original capture.
  Future<void> _openBeauty() async {
    final result = await Navigator.of(context).push<BeautyResult>(
      MaterialPageRoute(
        builder: (_) => BeautyScreen(
          imageBytes: widget.bytes,
          initial: _beauty ?? FaceBeauty.defaultStrength,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _bytes = result.bytes;
        _beauty = result.strength;
      });
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _save() async {
    final s = S.of(context);
    setState(() => _busy = true);
    try {
      if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
        if (mounted) _toast(s.saveFailed);
        return;
      }
      // No filter: save the (retouched) photo as is.
      final out = _filter == PhotoFilter.none
          ? _bytes
          : await ImageProcessing.applyLook(
              _bytes,
              PhotoFilters.blended(_filter, _strength),
            );
      await Gal.putImageBytes(out,
          name: 'StoryCraft_${DateTime.now().millisecondsSinceEpoch}');
      if (mounted) _toast(s.saved);
    } catch (_) {
      if (mounted) _toast(s.saveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _design() async {
    setState(() => _busy = true);
    try {
      final prepared = await ImageProcessing.prepareImport(_bytes);
      if (!mounted) return;
      // The filter stays live (non-destructive) in the editor.
      Navigator.pop(
        context,
        _ReviewResult(StoryBackground.image(prepared)
            .copyWith(filter: _filter, filterIntensity: _strength)),
      );
    } catch (_) {
      if (mounted) {
        _toast(S.of(context).processFailed);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: filteredView(
                      _filter,
                      _strength,
                      Image.memory(_bytes,
                          fit: BoxFit.contain,
                          cacheWidth: 1440,
                          gaplessPlayback: true),
                    ),
                  ),
                ),
              ),
            ),
            if (_filter != PhotoFilter.none)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(s.strength,
                        style: const TextStyle(color: Colors.white70)),
                    Expanded(
                      child: Slider(
                        value: _strength,
                        onChanged: (v) => setState(() => _strength = v),
                      ),
                    ),
                    SizedBox(
                      width: 42,
                      child: Text('${(_strength * 100).round()}%',
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final f in cameraFilters)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: ChoiceChip(
                        label: Text(filterLabel(s, f)),
                        selected: _filter == f,
                        onSelected: (_) {
                          setState(() {
                            _filter = f;
                            _strength = defaultStrength(f);
                          });
                          if (f == PhotoFilter.glow) _autoRetouch();
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: ActionChip(
                avatar: _retouching
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.face_retouching_natural_rounded),
                label: Text(_retouching
                    ? s.beautyWorking
                    : _beauty != null
                        ? '${s.beauty} ${(_beauty! * 100).round()}%'
                        : s.beauty),
                onPressed: _busy || _retouching ? null : _openBeauty,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
              child: Row(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.replay_rounded, color: Colors.white),
                    label: Text(s.retake,
                        style: const TextStyle(color: Colors.white)),
                  ),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy || _retouching ? null : _save,
                      icon: const Icon(Icons.download_rounded,
                          color: Colors.white),
                      label: FittedBox(
                        child: Text(s.saveFull,
                            style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy || _retouching ? null : _design,
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.edit_rounded),
                      label: FittedBox(child: Text(s.designStory)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
