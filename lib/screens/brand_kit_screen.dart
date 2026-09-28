import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/strings.dart';
import '../data/fonts.dart';
import '../services/brand_kit.dart';
import '../widgets/color_picker.dart';

/// Logo, brand colors and favorite font, saved on the device.
class BrandKitScreen extends StatelessWidget {
  const BrandKitScreen({super.key});

  BrandKitStore get _store => BrandKitStore.instance;

  Future<void> _pickLogo(BuildContext context) async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    try {
      final logo = await BrandKitStore.prepareLogo(await picked.readAsBytes());
      await _store.update(_store.value.copyWith(logo: logo));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(s.processFailed)));
    }
  }

  Future<void> _addColor(BuildContext context) async {
    final c = await showCustomColorDialog(context, const Color(0xFF5B31DC));
    if (c == null) return;
    final colors = [..._store.value.colors];
    if (!colors.contains(c)) colors.add(c);
    await _store.update(_store.value.copyWith(colors: colors));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(s.brandKit)),
      body: ValueListenableBuilder(
        valueListenable: _store,
        builder: (context, kit, _) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(s.brandKitHint,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
                const SizedBox(height: 24),

                // Logo
                Text(s.logo, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: kit.logo == null
                          ? Icon(Icons.image_outlined,
                              size: 40,
                              color: theme.colorScheme.onSurfaceVariant)
                          : Image.memory(kit.logo!, fit: BoxFit.contain),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () => _pickLogo(context),
                            icon: const Icon(Icons.upload_rounded),
                            label: Text(s.chooseLogo),
                          ),
                          if (kit.logo != null)
                            TextButton.icon(
                              onPressed: () => _store.update(
                                  kit.copyWith(clearLogo: true)),
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: Text(s.removeLogo),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Colors
                Text(s.brandColors, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final c in kit.colors)
                      InputChip(
                        avatar: CircleAvatar(backgroundColor: c),
                        label: Text(
                          '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
                        ),
                        onDeleted: () => _store.update(kit.copyWith(
                          colors: kit.colors.where((x) => x != c).toList(),
                        )),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.add_rounded),
                      label: Text(s.color),
                      onPressed: () => _addColor(context),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Favorite font
                Text(s.favoriteFont, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(s.none),
                      selected: kit.fontFamily == null,
                      onSelected: (_) =>
                          _store.update(kit.copyWith(clearFont: true)),
                    ),
                    for (final f in StoryFonts.all)
                      ChoiceChip(
                        label: Text(
                          f.displayName,
                          style: f.style(const TextStyle(fontSize: 16)),
                        ),
                        selected: kit.fontFamily == f.family,
                        onSelected: (_) =>
                            _store.update(kit.copyWith(fontFamily: f.family)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
