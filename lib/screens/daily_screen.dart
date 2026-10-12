import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/date_text.dart';
import '../core/strings.dart';
import '../data/daily_texts.dart';
import '../data/formats.dart';
import '../services/app_settings.dart';
import '../services/daily_story.dart';
import '../services/story_exporter.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/story_view.dart';
import 'editor_screen.dart';

/// "Story of the day": a fresh, correctly dated design every day, with
/// endless alternative designs and texts, ready to share or edit.
class DailyScreen extends StatefulWidget {
  const DailyScreen({super.key});

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> {
  final _boundary = GlobalKey();
  late final _exporter = StoryExporter(_boundary);
  late DateTime _date = _today;
  int _variant = 0;
  int _shift = 0;
  DailyCategory? _category;
  bool _busy = false;

  static DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  bool get _isToday => _date == _today;

  DailyStory get _story => DailyStoryGenerator.build(
        _date,
        variant: _variant,
        textShift: _shift,
        category: _category,
        watermark: AppSettings.instance.value.showWatermark,
      );

  void _moveDay(int delta) {
    final next = _date.add(Duration(days: delta));
    final diff = next.difference(_today).inDays;
    if (diff < -7 || diff > 60) return;
    setState(() {
      _date = DateTime(next.year, next.month, next.day);
      _variant = 0;
      _shift = 0;
    });
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() => _run(() async {
        final s = S.of(context);
        final result = await _exporter.shareToInstagramStory();
        if (result == StoryShareOutcome.failed && mounted) {
          _toast(s.instagramMissing);
        }
      });

  Future<void> _save() => _run(() async {
        final s = S.of(context);
        final ok = await _exporter.saveToGallery();
        if (mounted) _toast(ok ? s.saved : s.saveFailed);
      });

  void _edit(DailyStory story) {
    // A story planned for another day keeps that day's date as fixed text.
    final layers = [
      for (final l in story.layers)
        _isToday || l.template == null
            ? l
            : (l.clone()..template = null),
    ];
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EditorScreen(
        initialBackground: story.background,
        initialLayers: layers,
        initialFormat: StoryFormat.story,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return ValueListenableBuilder<AppSettingsData>(
      valueListenable: AppSettings.instance,
      builder: (context, settings, child) {
        final story = _story;
        final info = story.info;
        return Scaffold(
          appBar: AppBar(
            title: Text(s.dailyStory),
            actions: [
              IconButton(
                tooltip: s.settings,
                onPressed: () => showSettingsSheet(context),
                icon: const Icon(Icons.notifications_none_rounded),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Day navigation.
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _moveDay(-1),
                      icon: const Icon(Icons.keyboard_arrow_right_rounded),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '${DateText.weekday(_date)} · ${DateText.greg(_date)}',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(DateText.hijri(_date),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _moveDay(1),
                      icon: const Icon(Icons.keyboard_arrow_left_rounded),
                    ),
                  ],
                ),
                if (!_isToday || info.title != null || info.tag != null)
                  Wrap(
                    spacing: 6,
                    children: [
                      if (!_isToday)
                        ActionChip(
                          avatar: const Icon(Icons.today_rounded, size: 18),
                          label: Text(s.backToToday),
                          onPressed: () => setState(() {
                            _date = _today;
                            _variant = 0;
                            _shift = 0;
                          }),
                        ),
                      if (info.title != null) Chip(label: Text(info.title!)),
                      if (info.tag != null) Chip(label: Text('🌙 ${info.tag!}')),
                    ],
                  ),
                const SizedBox(height: 6),

                // Preview (also the export source: 360x640 -> 1080x1920).
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 9 / 16,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(color: Color(0x40000000), blurRadius: 18, offset: Offset(0, 8)),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: FittedBox(
                            child: StoryClock(
                              date: _date,
                              child: RepaintBoundary(
                                key: _boundary,
                                child: SizedBox(
                                  width: AppConfig.canvasWidth,
                                  height: AppConfig.canvasHeight,
                                  child: Stack(
                                    clipBehavior: Clip.hardEdge,
                                    children: [
                                      Positioned.fill(
                                        child: StoryBackgroundView(
                                            background: story.background),
                                      ),
                                      for (final l in story.layers)
                                        PositionedLayer(
                                          layer: l,
                                          child: StoryLayerVisual(layer: l),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Category.
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      for (final (label, cat) in [
                        (s.auto, null),
                        (s.catDua, DailyCategory.dua),
                        (s.catDhikr, DailyCategory.dhikr),
                        (s.catAyah, DailyCategory.ayah),
                        (s.catWisdom, DailyCategory.wisdom),
                        (s.catSaying, DailyCategory.saying),
                        (s.catQuote, DailyCategory.quote),
                      ])
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 6),
                          child: ChoiceChip(
                            label: Text(label),
                            selected: _category == cat,
                            onSelected: (_) => setState(() {
                              _category = cat;
                              _shift = 0;
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Actions.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    spacing: 8,
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() => _variant++),
                          icon: const Icon(Icons.palette_rounded),
                          label: FittedBox(child: Text(s.anotherDesign)),
                        ),
                      ),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() => _shift++),
                          icon: const Icon(Icons.shuffle_rounded),
                          label: FittedBox(child: Text(s.anotherText)),
                        ),
                      ),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _edit(story),
                          icon: const Icon(Icons.edit_rounded),
                          label: FittedBox(child: Text(s.edit)),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(
                    spacing: 8,
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _busy ? null : _share,
                          icon: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.send_rounded),
                          label: Text(s.shareToStory),
                          style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(50)),
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: s.save,
                        onPressed: _busy ? null : _save,
                        icon: const Icon(Icons.download_rounded),
                        style: IconButton.styleFrom(
                            minimumSize: const Size(50, 50)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
