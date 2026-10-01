import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_composer/video_composer.dart';
import 'package:video_player/video_player.dart';

import '../core/strings.dart';
import '../models/lyrics.dart';
import '../services/lyric_video_draft.dart';
import '../services/lyric_video_exporter.dart';
import '../widgets/lyrics_painter.dart';

/// Text / highlight color pairs offered for the lyrics.
const lyricColors = <(Color, Color)>[
  (Colors.white, Color(0xFFFFD166)),
  (Colors.white, Color(0xFFFF6FB5)),
  (Color(0xFFFFE8A3), Colors.white),
  (Colors.white, Color(0xFF4DD8FF)),
  (Colors.white, Color(0xFF7CFFB2)),
  (Color(0xFF111111), Color(0xFFE63946)),
];

String lyricEffectLabel(S s, LyricEffect e) => switch (e) {
      LyricEffect.fade => s.lvFade,
      LyricEffect.karaoke => s.lvKaraoke,
      LyricEffect.wipe => s.lvWipe,
      LyricEffect.words => s.lvWords,
      LyricEffect.zoom => s.lvZoom,
      LyricEffect.slide => s.lvSlide,
      LyricEffect.soft => s.lvSoft,
    };

/// Fonts offered for lyrics: calligraphy first, then modern.
const lyricFonts = <(String, String)>[
  ('Aref Ruqaa', 'رقعة'),
  ('Katibeh', 'كاتبة'),
  ('Alkalami', 'القلمي'),
  ('Amiri', 'أميري'),
  ('Lateef', 'لطيف'),
  ('Rakkas', 'رقّاص'),
  ('Cairo', 'القاهرة'),
  ('Tajawal', 'تجوال'),
  ('Changa', 'تشانجا'),
  ('Almarai', 'المراعي'),
];

/// Ready-made looks (the credit line is kept when switching).
List<(String, LyricsStyle)> lyricPresets(S s) => [
      (s.lvCinematic, LyricsStyle.cinematic),
      (s.lvClassic, const LyricsStyle()),
      (
        s.lvSimple,
        const LyricsStyle(
            effect: LyricEffect.fade, box: true, glow: false, y: 0.78),
      ),
    ];

/// Song video: a silent video, a song from the user's files and its
/// lyrics, synced by tapping and animated with effects, exported as MP4.
class LyricVideoScreen extends StatefulWidget {
  const LyricVideoScreen({super.key});

  @override
  State<LyricVideoScreen> createState() => _LyricVideoScreenState();
}

class _LyricVideoScreenState extends State<LyricVideoScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  String? _videoPath;
  VideoInfo? _info;
  VideoPlayerController? _video;

  String? _audioPath;
  String? _audioName;
  AudioPlayer? _audio;
  int _audioLengthMs = 0;
  int _audioStartMs = 0;

  /// End of the chosen part of the song (null = as long as the video).
  int? _audioEndMs;

  List<LyricLine> _lines = [];
  LyricsStyle _style = LyricsStyle.cinematic;
  final _credit = TextEditingController();

  final _position = ValueNotifier<int>(0);
  late final Ticker _ticker = createTicker(_onTick);
  int _playFromMs = 0;
  bool _playing = false;

  /// Index of the next line to stamp while syncing, or null.
  int? _syncIndex;
  bool _busy = false;

  /// Language for automatic lyrics.
  String _locale = 'ar-SA';

  /// Length of the result: the video, cut to the chosen part of the song
  /// when that is shorter, and at most a minute.
  int get _durationMs {
    var d = math.min(_info?.durationMs ?? 0, LyricVideoExporter.maxDurationMs);
    final end = _audioEndMs;
    if (_audioPath != null && end != null) {
      d = math.min(d, math.max(1000, end - _audioStartMs));
    }
    return d;
  }

  // --- Draft (auto-save) -----------------------------------------------------

  Timer? _saveTimer;
  bool _restoring = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restore();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pause();
      _saveNow();
    }
  }

  /// Every change schedules a save shortly after.
  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _scheduleSave();
  }

  void _scheduleSave() {
    if (_restoring || _videoPath == null) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), _saveNow);
  }

  Future<void> _saveNow() async {
    _saveTimer?.cancel();
    if (_restoring || _videoPath == null) return;
    try {
      await LyricVideoDraft.save({
        'video': _videoPath,
        'audio': _audioPath,
        'audioName': _audioName,
        'audioStart': _audioStartMs,
        'audioEnd': _audioEndMs,
        'lines': [for (final l in _lines) l.toJson()],
        'style': _style.toJson(),
        'locale': _locale,
      });
    } catch (_) {}
  }

  Future<void> _restore() async {
    final j = await LyricVideoDraft.load();
    if (j == null || !mounted) {
      _restoring = false;
      return;
    }
    try {
      await _openVideo(j['video'] as String, keep: false);
      final audio = j['audio'] as String?;
      if (audio != null) {
        await _openSong(audio, j['audioName'] as String? ?? '', keep: false);
      }
      if (!mounted) return;
      final style = LyricsStyle.fromJson(
          (j['style'] as Map?)?.cast<String, Object?>() ?? const {});
      _credit.text = style.credit;
      setState(() {
        _audioStartMs = (j['audioStart'] as num?)?.toInt() ?? 0;
        _audioEndMs = (j['audioEnd'] as num?)?.toInt();
        _lines = [
          for (final l in (j['lines'] as List? ?? const []))
            LyricLine.fromJson((l as Map).cast<String, Object?>()),
        ];
        _style = style;
        _locale = j['locale'] as String? ?? _locale;
      });
      _toast(S.of(context).lvRestored);
    } catch (_) {
      // A broken draft: start fresh.
    } finally {
      _restoring = false;
    }
  }

  Future<void> _newProject() async {
    final s = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.lvNewProject),
        content: Text(s.lvNewProjectAsk),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.lvNewProject),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _pause();
    _saveTimer?.cancel();
    await LyricVideoDraft.clear();
    await _video?.dispose();
    await _audio?.dispose();
    _credit.clear();
    _position.value = 0;
    setState(() {
      _video = null;
      _videoPath = null;
      _info = null;
      _audio = null;
      _audioPath = null;
      _audioName = null;
      _audioStartMs = 0;
      _audioEndMs = null;
      _lines = [];
      _style = LyricsStyle.cinematic;
    });
  }

  List<LyricTiming> get _timings => Lyrics.timings(_lines, _durationMs);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveNow();
    _ticker.dispose();
    _video?.dispose();
    _audio?.dispose();
    _position.dispose();
    _credit.dispose();
    super.dispose();
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  // --- Media -----------------------------------------------------------------

  Future<void> _pickVideo() async {
    final s = S.of(context);
    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final info = await _openVideo(picked.path, keep: true);
      if (info.durationMs > LyricVideoExporter.maxDurationMs) _toast(s.lvTooLong);
    } catch (_) {
      _toast(s.lvFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Loads a video ([keep]: copy it into the draft first).
  Future<VideoInfo> _openVideo(String path, {required bool keep}) async {
    if (keep) path = await LyricVideoDraft.keepMedia(path, 'video');
    final info = await VideoComposer.probe(path);
    final controller = VideoPlayerController.file(File(path));
    await controller.initialize();
    await controller.setVolume(0);
    await _pause();
    await _video?.dispose();
    if (!mounted) {
      await controller.dispose();
      return info;
    }
    setState(() {
      _videoPath = path;
      _info = info;
      _video = controller;
    });
    _position.value = 0;
    return info;
  }

  Future<void> _pickSong() async {
    final s = S.of(context);
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'm4a', 'aac', 'wav'],
    );
    if (file == null || !mounted) return;
    setState(() => _busy = true);
    try {
      // Copy into the app (Android hands over content:// URIs).
      final tmp = await getTemporaryDirectory();
      final ext = file.extension ?? 'm4a';
      final path =
          '${tmp.path}/song_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await File(path).writeAsBytes(await file.readAsBytes());
      await _openSong(path, file.name, keep: true);
      File(path).delete().ignore();
      setState(() {
        _audioStartMs = 0;
        _audioEndMs = null;
      });
    } catch (_) {
      _toast(s.lvFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Loads a song ([keep]: copy it into the draft first).
  Future<void> _openSong(String path, String name, {required bool keep}) async {
    if (keep) path = await LyricVideoDraft.keepMedia(path, 'song');
    final player = AudioPlayer();
    final length = await player.setFilePath(path);
    await _pause();
    await _audio?.dispose();
    if (!mounted) {
      await player.dispose();
      return;
    }
    setState(() {
      _audio = player;
      _audioPath = path;
      _audioName = name;
      _audioLengthMs = length?.inMilliseconds ?? 0;
    });
  }

  Future<void> _removeSong() async {
    await _pause();
    await _audio?.dispose();
    LyricVideoDraft.removeMedia('song').ignore();
    setState(() {
      _audio = null;
      _audioPath = null;
      _audioName = null;
      _audioEndMs = null;
    });
  }

  // --- Playback (one clock drives video, song and lyrics) --------------------

  void _onTick(Duration elapsed) {
    final ms = _playFromMs + elapsed.inMilliseconds;
    if (ms >= _durationMs) {
      _pause(to: 0);
      return;
    }
    _position.value = ms;
  }

  Future<void> _play() async {
    final video = _video;
    if (video == null || _playing) return;
    if (_position.value >= _durationMs - 50) _position.value = 0;
    _playFromMs = _position.value;
    setState(() => _playing = true);
    await video.seekTo(Duration(milliseconds: _playFromMs));
    await _audio?.seek(Duration(milliseconds: _audioStartMs + _playFromMs));
    unawaited(video.play());
    unawaited(_audio?.play());
    _ticker.start();
  }

  Future<void> _pause({int? to}) async {
    if (_ticker.isActive) _ticker.stop();
    if (to != null) _position.value = to;
    if (!_playing) return;
    if (mounted) {
      setState(() {
        _playing = false;
        _syncIndex = null;
      });
    }
    await _video?.pause();
    await _audio?.pause();
    if (to != null) await _video?.seekTo(Duration(milliseconds: to));
  }

  Future<void> _seek(int ms) async {
    await _pause();
    _position.value = ms;
    await _video?.seekTo(Duration(milliseconds: ms));
  }

  // --- Lyrics ----------------------------------------------------------------

  Future<void> _editLyrics() async {
    final s = S.of(context);
    await _pause();
    if (!mounted) return;
    final controller =
        TextEditingController(text: _lines.map((l) => l.text).join('\n'));
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 0, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.lvWriteLyrics,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              autofocus: true,
              minLines: 6,
              maxLines: 12,
              decoration: InputDecoration(
                hintText: s.lvLyricsHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text(s.done),
            ),
          ],
        ),
      ),
    );
    if (text == null || !mounted) return;
    final parsed = Lyrics.parse(text);
    // Keep the sync when only the wording changed.
    if (parsed.length == _lines.length) {
      for (var i = 0; i < parsed.length; i++) {
        parsed[i]
          ..startMs = _lines[i].startMs
          ..endMs = _lines[i].endMs;
      }
    }
    setState(() => _lines = parsed);
  }

  /// Listens to the song (or the video's own sound). With lyrics already
  /// written, only times them (the words stay exactly as written);
  /// otherwise writes what it hears as timed captions.
  Future<void> _autoLyrics() async {
    final s = S.of(context);
    final source = _audioPath ?? _videoPath;
    if (source == null) return;
    await _pause();
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LinearProgressIndicator(),
              const SizedBox(height: 14),
              Text(s.lvListening, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
    String message;
    try {
      final words = await VideoComposer.transcribe(
        path: source,
        startMs: _audioPath != null ? _audioStartMs : 0,
        durationMs: _durationMs,
        locale: _locale,
      );
      if (_lines.isNotEmpty) {
        final timed = Lyrics.align(_lines, words);
        setState(() {});
        message = timed == 0
            ? s.lvAutoNone
            : s.lvAligned
                .replaceAll('{n}', '$timed')
                .replaceAll('{t}', '${_lines.length}');
      } else {
        final lines = Lyrics.fromWords(words);
        if (lines.isEmpty) {
          message = s.lvAutoNone;
        } else {
          setState(() => _lines = lines);
          message = s.lvAutoDone;
        }
      }
    } on ComposeException catch (e) {
      message = switch (e.message) {
        'unsupported' => s.lvAutoUnsupported,
        'denied' => s.lvAutoDenied,
        'no_speech' => s.lvAutoNone,
        _ => s.lvFailed,
      };
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    _toast(message);
  }

  Future<void> _startSync() async {
    if (_lines.isEmpty) return;
    await _pause(to: 0);
    for (final l in _lines) {
      l
        ..startMs = null
        ..endMs = null;
    }
    setState(() => _syncIndex = 0);
    await _play();
  }

  void _stampLine() {
    final i = _syncIndex;
    if (i == null || i >= _lines.length) return;
    _lines[i].startMs = _position.value;
    setState(() => _syncIndex = i + 1 < _lines.length ? i + 1 : null);
    if (i + 1 >= _lines.length) _toast(S.of(context).lvSynced);
  }

  // --- Export ----------------------------------------------------------------

  Future<void> _export() async {
    final s = S.of(context);
    final path = _videoPath, info = _info;
    if (path == null || info == null) return;
    await _pause();
    if (!mounted) return;
    final progress = ValueNotifier<double?>(0);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: ValueListenableBuilder<double?>(
            valueListenable: progress,
            builder: (context, p, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: p),
                const SizedBox(height: 14),
                Text(p == null ? s.lvComposing : s.lvPreparing),
              ],
            ),
          ),
        ),
      ),
    );
    String? output;
    try {
      output = await LyricVideoExporter.export(
        videoPath: path,
        info: info,
        durationMs: _durationMs,
        audioPath: _audioPath,
        audioStartMs: _audioStartMs,
        lines: _lines,
        style: _style,
        onProgress: (p) => progress.value = p >= 1 ? null : p,
      );
    } catch (_) {
      output = null;
    }
    if (!mounted) return;
    Navigator.of(context).pop(); // progress dialog
    if (output == null) {
      _toast(s.lvFailed);
      return;
    }
    await _showResult(output);
  }

  Future<void> _showResult(String output) async {
    final s = S.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.lvReady,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(this.context);
                try {
                  if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
                    throw StateError('denied');
                  }
                  await Gal.putVideo(output);
                  messenger.showSnackBar(SnackBar(content: Text(s.lvSaved)));
                } catch (_) {
                  messenger.showSnackBar(SnackBar(content: Text(s.saveFailed)));
                }
              },
              icon: const Icon(Icons.download_rounded),
              label: Text(s.save),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                final box = context.findRenderObject() as RenderBox?;
                SharePlus.instance.share(ShareParams(
                  files: [XFile(output, mimeType: 'video/mp4')],
                  sharePositionOrigin: box == null
                      ? null
                      : box.localToGlobal(Offset.zero) & box.size,
                ));
              },
              icon: const Icon(Icons.ios_share_rounded),
              label: Text(s.share),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI --------------------------------------------------------------------

  /// m:ss.d, for trimming.
  static String _clockFine(int ms) =>
      '${_clock(ms)}.${(ms % 1000) ~/ 100}';

  static String _clock(int ms) {
    final sec = ms ~/ 1000;
    return '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final video = _video;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.lvTitle),
        actions: [
          if (video != null)
            IconButton(
              tooltip: s.lvNewProject,
              onPressed: _busy ? null : _newProject,
              icon: const Icon(Icons.note_add_outlined),
            ),
          if (video != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: FilledButton.icon(
                onPressed: _busy ? null : _export,
                icon: const Icon(Icons.movie_creation_rounded),
                label: Text(s.lvExport),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: video == null ? _emptyState(s) : _editor(s, video),
      ),
    );
  }

  Widget _emptyState(S s) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.queue_music_rounded, size: 72),
              const SizedBox(height: 16),
              Text(s.lvPickVideoHint, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _busy ? null : _pickVideo,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.video_library_rounded),
                label: Text(s.lvPickVideo),
              ),
            ],
          ),
        ),
      );

  Widget _editor(S s, VideoPlayerController video) {
    final aspect = video.value.aspectRatio;
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Center(
              child: AspectRatio(
                aspectRatio: aspect,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: GestureDetector(
                    onTap: _playing ? _pause : _play,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        VideoPlayer(video),
                        LyricsOverlay(
                          lines: _lines,
                          timings: _timings,
                          style: _style,
                          positionMs: _position,
                        ),
                        if (!_playing)
                          const Center(
                            child: Icon(Icons.play_circle_fill_rounded,
                                size: 64, color: Colors.white70),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_syncIndex != null) _syncBar(s) else _timeline(),
        DefaultTabController(
          length: 3,
          child: Column(
            children: [
              TabBar(tabs: [
                Tab(text: s.lvSong),
                Tab(text: s.lvLyrics),
                Tab(text: s.lvLook),
              ]),
              SizedBox(
                height: 190,
                child: TabBarView(children: [
                  _songTab(s),
                  _lyricsTab(s),
                  _lookTab(s),
                ]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _timeline() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: ValueListenableBuilder<int>(
          valueListenable: _position,
          builder: (context, ms, _) => Row(
            children: [
              IconButton(
                onPressed: _playing ? _pause : _play,
                icon: Icon(_playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded),
              ),
              Expanded(
                child: Slider(
                  value: ms.clamp(0, _durationMs).toDouble(),
                  max: math.max(1, _durationMs).toDouble(),
                  onChanged: (v) => _seek(v.round()),
                ),
              ),
              Text('${_clock(ms)} / ${_clock(_durationMs)}',
                  textDirection: TextDirection.ltr),
            ],
          ),
        ),
      );

  Widget _syncBar(S s) {
    final i = _syncIndex!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _pause(),
            icon: const Icon(Icons.stop_rounded),
          ),
          Expanded(
            child: FilledButton(
              onPressed: _stampLine,
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              child: Text(
                '${s.lvNext}: ${_lines[i].text}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _songTab(S s) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _pickSong,
                  icon: const Icon(Icons.library_music_rounded),
                  label: Text(_audioName ?? s.lvPickSong,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
              if (_audioPath != null)
                IconButton(
                  tooltip: s.lvRemoveSong,
                  onPressed: _removeSong,
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
          if (_audioPath != null && _audioLengthMs > 1000) _songRange(s),
          const SizedBox(height: 6),
          Text(s.lvRights, style: Theme.of(context).textTheme.bodySmall),
        ],
      );

  /// Start and end of the part of the song to use.
  Widget _songRange(S s) {
    final total = _audioLengthMs.toDouble();
    final videoMs =
        math.min(_info?.durationMs ?? 0, LyricVideoExporter.maxDurationMs);
    final start = _audioStartMs.clamp(0, _audioLengthMs - 1000).toDouble();
    final end = (_audioEndMs ?? (_audioStartMs + videoMs))
        .clamp(start + 1000, total)
        .toDouble();
    void set(int a, int b) {
      _pause(to: 0);
      setState(() {
        _audioStartMs = a;
        _audioEndMs = b;
      });
    }

    Widget nudge(IconData icon, VoidCallback onTap) => IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: onTap,
          icon: Icon(icon, size: 18),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        Text(s.lvSongPart, style: Theme.of(context).textTheme.titleSmall),
        Directionality(
          textDirection: TextDirection.ltr,
          child: RangeSlider(
            values: RangeValues(start, end),
            max: total,
            onChanged: (v) {
              // At most a minute, at least a second.
              var a = v.start.round(), b = v.end.round();
              if (b - a > LyricVideoExporter.maxDurationMs) {
                if (a != start.round()) {
                  b = a + LyricVideoExporter.maxDurationMs;
                } else {
                  a = b - LyricVideoExporter.maxDurationMs;
                }
              }
              if (b - a < 1000) return;
              set(a, b);
            },
          ),
        ),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              nudge(Icons.remove_rounded,
                  () => set(math.max(0, start.round() - 500), end.round())),
              Text(_clockFine(start.round())),
              nudge(Icons.add_rounded, () {
                if (end - start > 1500) set(start.round() + 500, end.round());
              }),
              const Spacer(),
              Text('${s.lvPartLength} ${_clockFine((end - start).round())}'),
              const Spacer(),
              nudge(Icons.remove_rounded, () {
                if (end - start > 1500) set(start.round(), end.round() - 500);
              }),
              Text(_clockFine(end.round())),
              nudge(Icons.add_rounded,
                  () => set(start.round(), math.min(total.round(), end.round() + 500))),
            ],
          ),
        ),
        Text(s.lvSongPartHint, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _lyricsTab(S s) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        children: [
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(s.lvTemplates),
              for (final (label, preset) in lyricPresets(s))
                ActionChip(
                  avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
                  label: Text(label),
                  onPressed: () => setState(() =>
                      _style = preset.copyWith(credit: _style.credit)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _autoLyrics,
                  icon: const Icon(Icons.subtitles_rounded),
                  label: FittedBox(
                      child: Text(_lines.isEmpty ? s.lvAuto : s.lvAutoSync)),
                ),
              ),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: 'ar-SA', label: Text(s.lvLangAr)),
                  ButtonSegment(value: 'en-US', label: Text(s.lvLangEn)),
                ],
                selected: {_locale},
                onSelectionChanged: (v) => setState(() => _locale = v.first),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _editLyrics,
                  icon: const Icon(Icons.edit_note_rounded),
                  label: Text(s.lvWriteLyrics),
                ),
              ),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _lines.isEmpty ? null : _startSync,
                  icon: const Icon(Icons.touch_app_rounded),
                  label: FittedBox(child: Text(s.lvSync)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(_lines.isEmpty ? s.lvNoLyrics : s.lvSyncHint,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(s.lvTipPaste, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          TextField(
            controller: _credit,
            decoration: InputDecoration(
              isDense: true,
              labelText: s.lvCredit,
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) =>
                setState(() => _style = _style.copyWith(credit: v)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              for (final e in LyricEffect.values)
                ChoiceChip(
                  label: Text(lyricEffectLabel(s, e)),
                  selected: _style.effect == e,
                  onSelected: (_) =>
                      setState(() => _style = _style.copyWith(effect: e)),
                ),
            ],
          ),
        ],
      );

  Widget _lookTab(S s) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final (text, accent) in lyricColors)
                  GestureDetector(
                    onTap: () => setState(() => _style =
                        _style.copyWith(color: text, accent: accent)),
                    child: Container(
                      width: 36,
                      height: 36,
                      margin: const EdgeInsetsDirectional.only(end: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [text, accent]),
                        border: Border.all(
                          width: _style.color == text && _style.accent == accent
                              ? 3
                              : 1,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final (family, label) in lyricFonts)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: ChoiceChip(
                      label: Text(label, style: TextStyle(fontFamily: family)),
                      selected: _style.fontFamily == family,
                      onSelected: (_) => setState(() =>
                          _style = _style.copyWith(fontFamily: family)),
                    ),
                  ),
              ],
            ),
          ),
          Row(
            children: [
              SizedBox(width: 64, child: Text(s.lvPosition)),
              Expanded(
                child: Slider(
                  value: _style.y,
                  min: 0.1,
                  max: 0.9,
                  onChanged: (v) =>
                      setState(() => _style = _style.copyWith(y: v)),
                ),
              ),
            ],
          ),
          Row(
            children: [
              SizedBox(width: 64, child: Text(s.lvSize)),
              Expanded(
                child: Slider(
                  value: _style.size,
                  min: 16,
                  max: 44,
                  onChanged: (v) =>
                      setState(() => _style = _style.copyWith(size: v)),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: Text(s.lvBox),
                selected: _style.box,
                onSelected: (v) =>
                    setState(() => _style = _style.copyWith(box: v)),
              ),
              FilterChip(
                label: Text(s.lvGlow),
                selected: _style.glow,
                onSelected: (v) =>
                    setState(() => _style = _style.copyWith(glow: v)),
              ),
              FilterChip(
                label: Text(s.lvBold),
                selected: _style.bold,
                onSelected: (v) =>
                    setState(() => _style = _style.copyWith(bold: v)),
              ),
              FilterChip(
                label: Text(s.lvShade),
                selected: _style.shade,
                onSelected: (v) =>
                    setState(() => _style = _style.copyWith(shade: v)),
              ),
            ],
          ),
        ],
      );
}
