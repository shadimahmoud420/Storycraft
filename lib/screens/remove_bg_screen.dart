import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../services/background_remover.dart';

enum _Mode { auto, color }

/// Background removal studio. Two modes:
/// - auto: on-device subject segmentation (people, pets, objects);
/// - color: removes a plain background color and keeps the drawing
///   (signatures, logos, sketches), optionally recoloring it.
/// Pops with the final [Cutout], or null.
class RemoveBgScreen extends StatefulWidget {
  const RemoveBgScreen({super.key, required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<RemoveBgScreen> createState() => _RemoveBgScreenState();
}

class _RemoveBgScreenState extends State<RemoveBgScreen> {
  static const _gold = 0xFFD4AF37;

  _Mode? _mode;
  Cutout? _preview;
  Cutout? _autoResult;
  CutoutError? _error;
  bool _working = true;
  int _job = 0;

  double _tolerance = 0.12;
  bool _edgesOnly = false;
  int? _recolor;
  int _view = 0; // preview backdrop: 0 checker, 1 dark, 2 light

  @override
  void initState() {
    super.initState();
    // Scans and drawings on a flat background start in color mode.
    hasPlainBackground(widget.imageBytes)
        .catchError((_) => false)
        .then((plain) {
      if (!mounted) return;
      _mode = plain ? _Mode.color : _Mode.auto;
      _run();
    });
  }

  ColorKeyOptions _options({required int maxEdge}) => ColorKeyOptions(
        tolerance: _tolerance,
        edgesOnly: _edgesOnly,
        recolor: _recolor,
        maxEdge: maxEdge,
      );

  Future<void> _run() async {
    final job = ++_job;
    setState(() {
      _working = true;
      _error = null;
    });
    Cutout? result;
    CutoutError? error;
    try {
      if (_mode == _Mode.auto) {
        result = _autoResult ??=
            await BackgroundRemover.cutout(widget.imageBytes);
      } else {
        // Quick, smaller preview; full resolution on apply.
        result = await removeColorBackground(
            widget.imageBytes, _options(maxEdge: 900));
      }
    } on CutoutException catch (e) {
      error = e.error;
    } catch (_) {
      error = CutoutError.failed;
    }
    if (!mounted || job != _job) return;
    setState(() {
      _working = false;
      _preview = error == null ? result : null;
      _error = error;
    });
  }

  Future<void> _apply() async {
    if (_mode == _Mode.auto) {
      Navigator.pop(context, _autoResult);
      return;
    }
    setState(() => _working = true);
    try {
      final full = await removeColorBackground(
          widget.imageBytes, _options(maxEdge: 2000));
      if (mounted) Navigator.pop(context, full);
    } catch (_) {
      if (mounted) {
        setState(() {
          _working = false;
          _error = CutoutError.failed;
        });
      }
    }
  }

  String _errorText(S s, CutoutError e) => switch (e) {
        CutoutError.unsupported => '${s.removeBgUnsupported}\n${s.tryColorMode}',
        CutoutError.preparing => s.removeBgPreparing,
        CutoutError.noSubject => _mode == _Mode.auto
            ? '${s.removeBgNoSubject}\n${s.tryColorMode}'
            : s.removeBgNoSubject,
        CutoutError.failed => s.processFailed,
      };

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final backdrop = switch (_view) {
      1 => const Color(0xFF16161C),
      2 => const Color(0xFFF5F2EC),
      _ => null,
    };

    return Scaffold(
      appBar: AppBar(title: Text(s.removeBg)),
      body: SafeArea(
        child: Column(
          children: [
            // Preview.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      backdrop == null
                          ? const CustomPaint(painter: CheckerPainter())
                          : ColoredBox(color: backdrop),
                      if (_preview != null)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Image.memory(
                            _preview!.png,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          ),
                        ),
                      if (_error != null)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xCC000000),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                _errorText(s, _error!),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white, height: 1.5),
                              ),
                            ),
                          ),
                        ),
                      if (_working)
                        const Center(child: CircularProgressIndicator()),
                      PositionedDirectional(
                        top: 8,
                        end: 8,
                        child: _BackdropToggle(
                          value: _view,
                          onChanged: (v) => setState(() => _view = v),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Mode.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<_Mode>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: _Mode.auto,
                    icon: const Icon(Icons.person_rounded),
                    label: _ModeLabel(s.cutAuto, s.cutAutoHint),
                  ),
                  ButtonSegment(
                    value: _Mode.color,
                    icon: const Icon(Icons.draw_rounded),
                    label: _ModeLabel(s.cutColor, s.cutColorHint),
                  ),
                ],
                selected: {if (_mode != null) _mode!},
                emptySelectionAllowed: true,
                onSelectionChanged: (v) {
                  if (v.isEmpty || v.first == _mode) return;
                  _mode = v.first;
                  _run();
                },
              ),
            ),

            // Color-mode settings.
            if (_mode == _Mode.color)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(s.cutStrength, style: theme.textTheme.titleSmall),
                        Expanded(
                          child: Slider(
                            value: _tolerance,
                            min: 0.03,
                            max: 0.45,
                            onChanged: (v) => setState(() => _tolerance = v),
                            onChangeEnd: (_) => _run(),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(s.inkColor, style: theme.textTheme.titleSmall),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              spacing: 6,
                              children: [
                                for (final (label, value) in [
                                  (s.original, null),
                                  (s.white, 0xFFFFFFFF),
                                  (s.black, 0xFF000000),
                                  (s.fillGold, _gold),
                                ])
                                  ChoiceChip(
                                    avatar: value == null
                                        ? null
                                        : CircleAvatar(
                                            backgroundColor: Color(value)),
                                    label: Text(label),
                                    selected: _recolor == value,
                                    onSelected: (_) {
                                      _recolor = value;
                                      _run();
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(s.cutEdgesOnly),
                      subtitle: Text(s.cutEdgesOnlyHint),
                      value: _edgesOnly,
                      onChanged: (v) {
                        _edgesOnly = v;
                        _run();
                      },
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton.icon(
                onPressed: _preview == null || _working ? null : _apply,
                icon: const Icon(Icons.check_rounded),
                label: Text(s.apply),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeLabel extends StatelessWidget {
  const _ModeLabel(this.title, this.hint);

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title),
        Text(hint, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _BackdropToggle extends StatelessWidget {
  const _BackdropToggle({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget dot(int v, Widget child) => GestureDetector(
          onTap: () => onChanged(v),
          child: Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: v == value ? const Color(0xFF7B4DFF) : Colors.white,
                width: v == value ? 3 : 1.5,
              ),
            ),
            child: ClipOval(child: child),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0x66000000),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          dot(0, const CustomPaint(painter: CheckerPainter(cell: 6))),
          dot(1, const ColoredBox(color: Color(0xFF16161C))),
          dot(2, const ColoredBox(color: Color(0xFFF5F2EC))),
        ],
      ),
    );
  }
}

/// Grey/white checkerboard: the usual "transparent" backdrop.
class CheckerPainter extends CustomPainter {
  const CheckerPainter({this.cell = 14});

  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final grey = Paint()..color = const Color(0xFFDADADA);
    for (var y = 0.0; y < size.height; y += cell) {
      for (var x = ((y / cell).round().isOdd ? cell : 0.0);
          x < size.width;
          x += cell * 2) {
        canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), grey);
      }
    }
  }

  @override
  bool shouldRepaint(CheckerPainter old) => old.cell != cell;
}
