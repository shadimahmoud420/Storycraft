import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/locale_controller.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../data/palettes.dart';
import '../data/formats.dart';
import '../state/editor_controller.dart';
import '../data/templates.dart';
import '../models/story_background.dart';
import '../models/story_layer.dart';
import '../services/draft_store.dart';
import '../services/image_processing.dart';
import 'brand_kit_screen.dart';
import 'signature_screen.dart';
import 'editor_screen.dart';
import 'templates_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.localeController});

  final LocaleController localeController;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = false;

  Future<void> _startFromPhoto({List<StoryLayer> layers = const []}) async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 95, // also converts HEIC to JPEG on iOS
    );
    if (picked == null) return;
    setState(() => _loading = true);
    try {
      final bytes = await ImageProcessing.prepareImport(
        await picked.readAsBytes(),
      );
      if (!mounted) return;
      _openEditor(StoryBackground.image(bytes), layers: layers);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(s.processFailed)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openEditor(
    StoryBackground bg, {
    List<StoryLayer> layers = const [],
    StoryFormat format = StoryFormat.story,
    String? draftId,
    bool openBackgroundSheet = false,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditorScreen(
          initialBackground: bg,
          initialLayers: layers,
          initialFormat: format,
          draftId: draftId,
          openBackgroundSheet: openBackgroundSheet,
        ),
      ),
    );
  }

  Future<void> _openTemplates() async {
    final template = await Navigator.of(context).push<StoryTemplate>(
      MaterialPageRoute(builder: (_) => const TemplatesScreen()),
    );
    if (template == null || !mounted) return;
    _openEditor(template.background, layers: template.buildLayers());
  }

  /// Signature flow: pick or create a signature, then choose where to
  /// place it (photo, gradient or classic color).
  Future<void> _openSignature() async {
    final s = S.of(context);
    final sig = await Navigator.of(context).push<StoryLayer>(
      MaterialPageRoute(builder: (_) => const SignatureScreen()),
    );
    if (sig == null || !mounted) return;
    final choice = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(s.placeOn,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: Text(s.onPhoto),
              onTap: () => Navigator.pop(context, 0),
            ),
            ListTile(
              leading: const Icon(Icons.gradient_rounded),
              title: Text(s.onGradient),
              onTap: () => Navigator.pop(context, 1),
            ),
            ListTile(
              leading: const Icon(Icons.format_color_fill_rounded),
              title: Text(s.onClassic),
              onTap: () => Navigator.pop(context, 2),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    // Light ink (white/gold) goes on dark backgrounds and vice versa.
    final lightInk = sig.fill != TextFill.solid ||
        sig.color.computeLuminance() > 0.5;
    final placed = sig.copyWith(
      id: sig.id,
      position: EditorController.signatureSpot(sig.text, StoryFormat.story),
    );
    switch (choice) {
      case 0:
        await _startFromPhoto(layers: [placed]);
      case 1:
        _openEditor(
          StoryBackground.gradient(
              lightInk ? Palettes.gradients[6] : Palettes.gradients[3]),
          layers: [placed],
          openBackgroundSheet: true,
        );
      default:
        _openEditor(
          StoryBackground.solid(
              lightInk ? const Color(0xFF1C1C1E) : const Color(0xFFF5F0E6)),
          layers: [placed],
          openBackgroundSheet: true,
        );
    }
  }

  Future<void> _openDraft(String id) async {
    final draft = await DraftStore.instance.load(id);
    if (draft == null || !mounted) return;
    _openEditor(
      draft.background,
      layers: draft.layers,
      format: draft.format,
      draftId: id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                // Comfortable width on large phones, foldables and tablets.
                constraints: const BoxConstraints(maxWidth: 520),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const BrandKitScreen()),
                          ),
                          icon: const Icon(Icons.storefront_rounded),
                          label: Text(s.brandKit),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => widget.localeController
                              .toggle(Localizations.localeOf(context)),
                          icon: const Icon(Icons.translate_rounded),
                          label: Text(s.language),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const _Logo(),
                    const SizedBox(height: 16),
                    Text(
                      s.appName,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      s.tagline,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _DraftsRow(onOpen: _openDraft),
                    _StartCard(
                      icon: Icons.dashboard_customize_rounded,
                      title: s.templates,
                      subtitle: s.templatesHint,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFF7971E), Color(0xFFE8505B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      onTap: _openTemplates,
                    ),
                    const SizedBox(height: 14),
                    _StartCard(
                      icon: Icons.draw_rounded,
                      title: s.signature,
                      subtitle: s.signatureHint,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF232526), Color(0xFF5B4A2E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      onTap: _openSignature,
                    ),
                    const SizedBox(height: 14),
                    _StartCard(
                      icon: Icons.photo_library_rounded,
                      title: s.fromPhoto,
                      subtitle: s.fromPhotoHint,
                      decoration: const BoxDecoration(
                        gradient: AppTheme.brandGradient,
                      ),
                      onTap: _loading ? null : () => _startFromPhoto(),
                    ),
                    const SizedBox(height: 14),
                    _StartCard(
                      icon: Icons.format_color_fill_rounded,
                      title: s.fromColor,
                      subtitle: s.fromColorHint,
                      decoration: const BoxDecoration(color: Color(0xFF1F3A5F)),
                      onTap: () => _openEditor(
                        const StoryBackground.solid(Color(0xFFF5F0E6)),
                        openBackgroundSheet: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _StartCard(
                      icon: Icons.gradient_rounded,
                      title: s.fromGradient,
                      subtitle: s.fromGradientHint,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: Palettes.gradients[1],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      onTap: () => _openEditor(
                        StoryBackground.gradient(Palettes.gradients.first),
                        openBackgroundSheet: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_loading)
            ColoredBox(
              color: Colors.black45,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(s.processing),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          gradient: AppTheme.brandGradient,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: AppTheme.brand.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const Icon(Icons.auto_awesome_rounded,
            color: Colors.white, size: 44),
      ),
    );
  }
}

class _StartCard extends StatelessWidget {
  const _StartCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.decoration,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final BoxDecoration decoration;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: decoration,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: text.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                      Text(subtitle,
                          style: text.bodyMedium
                              ?.copyWith(color: Colors.white70)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.white70, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal list of saved drafts (hidden when there are none).
class _DraftsRow extends StatelessWidget {
  const _DraftsRow({required this.onOpen});

  final ValueChanged<String> onOpen;

  Future<void> _confirmDelete(BuildContext context, String id) async {
    final s = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.deleteDraft),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (ok == true) await DraftStore.instance.delete(id);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ValueListenableBuilder<int>(
      valueListenable: DraftStore.instance.revision,
      builder: (context, revision, _) => FutureBuilder<List<DraftSummary>>(
        key: ValueKey(revision),
        future: DraftStore.instance.list(),
        builder: (context, snap) {
          final drafts = snap.data ?? const <DraftSummary>[];
          if (drafts.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.drafts, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SizedBox(
                  height: 142,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: drafts.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      final d = drafts[i];
                      return GestureDetector(
                        onTap: () => onOpen(d.id),
                        onLongPress: () => _confirmDelete(context, d.id),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 80,
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            child: d.thumbnail == null
                                ? const Icon(Icons.image_outlined)
                                : Image.memory(d.thumbnail!, fit: BoxFit.cover),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
