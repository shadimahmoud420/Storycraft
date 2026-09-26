import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/locale_controller.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../data/palettes.dart';
import '../models/story_background.dart';
import '../services/image_processing.dart';
import 'editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.localeController});

  final LocaleController localeController;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = false;

  Future<void> _startFromPhoto() async {
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
      _openEditor(StoryBackground.image(bytes));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(s.processFailed)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openEditor(StoryBackground bg, {bool openBackgroundSheet = false}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditorScreen(
          initialBackground: bg,
          openBackgroundSheet: openBackgroundSheet,
        ),
      ),
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
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton.icon(
                        onPressed: () => widget.localeController
                            .toggle(Localizations.localeOf(context)),
                        icon: const Icon(Icons.translate_rounded),
                        label: Text(s.language),
                      ),
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
                    const SizedBox(height: 32),
                    _StartCard(
                      icon: Icons.photo_library_rounded,
                      title: s.fromPhoto,
                      subtitle: s.fromPhotoHint,
                      decoration: const BoxDecoration(
                        gradient: AppTheme.brandGradient,
                      ),
                      onTap: _loading ? null : _startFromPhoto,
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
