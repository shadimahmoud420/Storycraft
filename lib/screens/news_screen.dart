import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/strings.dart';
import '../models/story_layer.dart';
import '../services/image_processing.dart';
import '../services/news_profile.dart';
import '../services/signature_store.dart';
import '../services/story_exporter.dart';
import '../widgets/news_card.dart';
import '../widgets/signature_view.dart';
import 'signature_screen.dart';

/// Accent colors offered for the news template.
const newsAccents = [
  Color(0xFFD62828),
  Color(0xFFE85D04),
  Color(0xFFC9A227),
  Color(0xFF2A9D8F),
  Color(0xFF1D4E89),
  Color(0xFF6A4C93),
  Color(0xFF111111),
];

/// News template: the identity (name, signature, logo, colors) is set
/// once; each post only needs its text, then it is exported.
class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final _boundary = GlobalKey();
  late final _exporter = StoryExporter(_boundary);
  final _text = TextEditingController();
  late final _location =
      TextEditingController(text: NewsProfileStore.instance.value.location);
  Uint8List? _photo;
  bool _busy = false;

  NewsProfile get _profile => NewsProfileStore.instance.value;

  @override
  void initState() {
    super.initState();
    if (!_profile.isSetUp) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openSetup();
      });
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _location.dispose();
    super.dispose();
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  StoryLayer? _signature(NewsProfile p) {
    final id = p.signatureId;
    if (id == null) return null;
    return SignatureStore.instance.value.where((s) => s.id == id).firstOrNull;
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 2000, maxHeight: 2000);
    if (picked == null || !mounted) return;
    try {
      final bytes =
          await ImageProcessing.prepareImport(await picked.readAsBytes());
      if (!mounted) return;
      setState(() => _photo = bytes);
      // A photo only shows in the on-site design.
      if (_profile.design != NewsDesign.field) {
        await NewsProfileStore.instance
            .save(_profile.copyWith(design: NewsDesign.field));
      }
    } catch (_) {
      if (mounted) _toast(S.of(context).processFailed);
    }
  }

  /// Remembers the place for next time.
  void _rememberPlace() {
    final place = _location.text.trim();
    if (place != _profile.location) {
      NewsProfileStore.instance.save(_profile.copyWith(location: place));
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    _rememberPlace();
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareStory() => _run(() async {
        final s = S.of(context);
        final r = await _exporter.shareToInstagramStory();
        if (r == StoryShareOutcome.failed && mounted) _toast(s.instagramMissing);
      });

  Future<void> _save() => _run(() async {
        final s = S.of(context);
        final ok = await _exporter.saveToGallery();
        if (mounted) _toast(ok ? s.saved : s.saveFailed);
      });

  Future<void> _shareSheet() => _run(() async {
        await _exporter.shareViaSheet();
      });

  void _clear() => setState(() {
        _text.clear();
        _photo = null;
      });

  Future<void> _openSetup() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => const _SetupSheet(),
    );
    if (mounted) setState(() {});
  }

  /// Size, alignment and place of the news text (kept for next time).
  Future<void> _openFormat() async {
    FocusScope.of(context).unfocus();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      barrierColor: Colors.black12,
      builder: (_) => const _FormatSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ValueListenableBuilder<NewsProfile>(
      valueListenable: NewsProfileStore.instance,
      builder: (context, profile, _) => Scaffold(
        appBar: AppBar(
          title: Text(s.nwTitle),
          actions: [
            IconButton(
              tooltip: s.nwClear,
              onPressed: _clear,
              icon: const Icon(Icons.note_add_outlined),
            ),
            IconButton(
              tooltip: s.nwSetup,
              onPressed: _openSetup,
              icon: const Icon(Icons.tune_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 9 / 16,
                      child: GestureDetector(
                        onTap: _openSetup,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: FittedBox(
                            child: RepaintBoundary(
                              key: _boundary,
                              child: NewsCard(
                                profile: profile,
                                text: _text.text,
                                date: DateTime.now(),
                                tag: profile.tag,
                                location: _location.text,
                                photo: _photo,
                                signature: _signature(profile),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final tag in ['', ...newsTags])
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 6),
                        child: ChoiceChip(
                          label: Text(tag.isEmpty ? '—' : tag),
                          selected: profile.tag == tag,
                          onSelected: (_) => NewsProfileStore.instance
                              .save(profile.copyWith(tag: tag)),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: TextField(
                  controller: _text,
                  minLines: 2,
                  maxLines: 4,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    hintText: s.nwText,
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: IconButton(
                      tooltip: s.nwFormat,
                      onPressed: _openFormat,
                      icon: const Icon(Icons.format_size_rounded),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _location,
                        decoration: InputDecoration(
                          hintText: s.nwLocation,
                          prefixIcon: const Icon(Icons.location_on_outlined),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: _photo == null ? s.nwPhoto : s.nwRemovePhoto,
                      onPressed: _photo == null
                          ? _pickPhoto
                          : () => setState(() => _photo = null),
                      icon: Icon(_photo == null
                          ? Icons.add_photo_alternate_outlined
                          : Icons.hide_image_outlined),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy || _text.text.trim().isEmpty
                            ? null
                            : _shareStory,
                        icon: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded),
                        label: Text(s.shareToStory),
                        style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(50)),
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: s.save,
                      onPressed: _busy || _text.text.trim().isEmpty
                          ? null
                          : _save,
                      icon: const Icon(Icons.download_rounded),
                      style: IconButton.styleFrom(
                          minimumSize: const Size(50, 50)),
                    ),
                    IconButton.filledTonal(
                      tooltip: s.share,
                      onPressed: _busy || _text.text.trim().isEmpty
                          ? null
                          : _shareSheet,
                      icon: const Icon(Icons.ios_share_rounded),
                      style: IconButton.styleFrom(
                          minimumSize: const Size(50, 50)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// News text formatting; every change shows at once on the card above.
class _FormatSheet extends StatelessWidget {
  const _FormatSheet();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final store = NewsProfileStore.instance;
    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text(t, style: theme.textTheme.titleSmall),
        );
    return ValueListenableBuilder<NewsProfile>(
      valueListenable: store,
      builder: (context, p, _) {
        void set(NewsProfile n) => store.save(n);
        final auto = p.textY == null;
        final y = p.textY ?? (p.design == NewsDesign.field ? 1.0 : 0.5);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              label(s.nwSize),
              Row(
                children: [
                  const Icon(Icons.text_decrease_rounded, size: 18),
                  Expanded(
                    child: Slider(
                      value: p.textScale,
                      min: 0.6,
                      max: 1.5,
                      divisions: 18,
                      onChanged: (v) => set(p.copyWith(textScale: v)),
                    ),
                  ),
                  const Icon(Icons.text_increase_rounded, size: 22),
                ],
              ),
              label(s.nwAlign),
              SegmentedButton<NewsAlign>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                      value: NewsAlign.right,
                      icon: Icon(Icons.format_align_right_rounded)),
                  ButtonSegment(
                      value: NewsAlign.center,
                      icon: Icon(Icons.format_align_center_rounded)),
                  ButtonSegment(
                      value: NewsAlign.left,
                      icon: Icon(Icons.format_align_left_rounded)),
                  ButtonSegment(
                      value: NewsAlign.justify,
                      icon: Icon(Icons.format_align_justify_rounded)),
                ],
                selected: {p.align},
                onSelectionChanged: (v) => set(p.copyWith(align: v.first)),
              ),
              label(s.nwPlace),
              Row(
                children: [
                  Text(s.nwTop, style: theme.textTheme.bodySmall),
                  Expanded(
                    child: Slider(
                      value: y,
                      divisions: 20,
                      onChanged: (v) => set(p.copyWith(textY: v)),
                    ),
                  ),
                  Text(s.nwBottom, style: theme.textTheme.bodySmall),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text(s.nwPlaceAuto),
                    selected: auto,
                    onSelected: (_) => set(p.copyWith(clearTextY: true)),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.nwBold),
                value: p.bold,
                onChanged: (v) => set(p.copyWith(bold: v)),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The one-time setup: name, handle, signature, logo, color and design.
class _SetupSheet extends StatefulWidget {
  const _SetupSheet();

  @override
  State<_SetupSheet> createState() => _SetupSheetState();
}

class _SetupSheetState extends State<_SetupSheet> {
  late NewsProfile _p = NewsProfileStore.instance.value;
  late final _name = TextEditingController(text: _p.name);
  late final _handle = TextEditingController(text: _p.handle);

  @override
  void dispose() {
    _name.dispose();
    _handle.dispose();
    super.dispose();
  }

  void _set(NewsProfile p) {
    setState(() => _p = p);
    NewsProfileStore.instance.save(p);
  }

  Future<void> _newSignature() async {
    final sig = await Navigator.of(context).push<StoryLayer>(
      MaterialPageRoute(builder: (_) => const SignatureScreen()),
    );
    if (sig == null || !mounted) return;
    // A new signature is stored under a fresh id: it is the newest one.
    final saved = SignatureStore.instance.value;
    final id = saved.any((s) => s.id == sig.id) ? sig.id : saved.firstOrNull?.id;
    if (id != null) _set(_p.copyWith(signatureId: id));
  }

  Future<void> _pickLogo() async {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 600, maxHeight: 600);
    if (picked == null || !mounted) return;
    _set(_p.copyWith(logo: await picked.readAsBytes()));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(t, style: theme.textTheme.titleSmall),
        );
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.nwSetup, style: theme.textTheme.titleLarge),
            Text(s.nwSetupHint, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: InputDecoration(
                  labelText: s.nwName, border: const OutlineInputBorder()),
              onChanged: (v) => _set(_p.copyWith(name: v)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _handle,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                  labelText: s.nwHandle,
                  hintText: '@',
                  border: const OutlineInputBorder()),
              onChanged: (v) => _set(_p.copyWith(handle: v)),
            ),
            label(s.nwSignature),
            ValueListenableBuilder<List<StoryLayer>>(
              valueListenable: SignatureStore.instance,
              builder: (context, sigs, _) => SizedBox(
                height: 74,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _Choice(
                      selected: _p.signatureId == null,
                      onTap: () => _set(_p.copyWith(clearSignature: true)),
                      child: Text(s.nwNoSignature,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12)),
                    ),
                    for (final sig in sigs)
                      _Choice(
                        selected: _p.signatureId == sig.id,
                        dark: true,
                        onTap: () => _set(_p.copyWith(signatureId: sig.id)),
                        child: FittedBox(child: SignatureView(layer: sig)),
                      ),
                    _Choice(
                      selected: false,
                      onTap: _newSignature,
                      child: FittedBox(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.draw_rounded),
                            Text(s.nwNewSignature,
                                style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            label(s.nwLogo),
            Row(
              spacing: 8,
              children: [
                if (_p.logo != null)
                  CircleAvatar(
                      radius: 22, backgroundImage: MemoryImage(_p.logo!)),
                OutlinedButton.icon(
                  onPressed: _pickLogo,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(s.nwPickLogo),
                ),
                if (_p.logo != null)
                  TextButton(
                    onPressed: () => _set(_p.copyWith(clearLogo: true)),
                    child: Text(s.nwRemoveLogo),
                  ),
              ],
            ),
            label(s.nwDesign),
            SegmentedButton<NewsDesign>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                    value: NewsDesign.breaking, label: Text(s.nwBreaking)),
                ButtonSegment(value: NewsDesign.field, label: Text(s.nwField)),
                ButtonSegment(value: NewsDesign.paper, label: Text(s.nwPaper)),
              ],
              selected: {_p.design},
              onSelectionChanged: (v) => _set(_p.copyWith(design: v.first)),
            ),
            label(s.nwColor),
            Wrap(
              spacing: 10,
              children: [
                for (final c in newsAccents)
                  GestureDetector(
                    onTap: () => _set(_p.copyWith(accent: c)),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _p.accent == c
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.nwShowDate),
              value: _p.showDateTime,
              onChanged: (v) => _set(_p.copyWith(showDateTime: v)),
            ),
            const SizedBox(height: 6),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(s.done),
            ),
          ],
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.selected,
    required this.onTap,
    required this.child,
    this.dark = false,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  /// Dark tile (signatures are often light colored).
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        margin: const EdgeInsetsDirectional.only(end: 8),
        padding: const EdgeInsets.all(8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF1E2230) : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? scheme.primary : Colors.transparent,
            width: 3,
          ),
        ),
        child: child,
      ),
    );
  }
}
