import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../data/templates.dart';
import '../widgets/story_view.dart';

/// Grid of ready-made designs. Pops with the chosen template.
class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  TemplateCategory? _category;

  String _label(S s, TemplateCategory c) => switch (c) {
        TemplateCategory.ramadan => s.ramadan,
        TemplateCategory.eid => s.eid,
        TemplateCategory.friday => s.friday,
        TemplateCategory.morning => s.morning,
        TemplateCategory.congrats => s.congrats,
        TemplateCategory.graduation => s.graduation,
      };

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final items = storyTemplates
        .where((t) => _category == null || t.category == _category)
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(s.templates)),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    label: Text(s.all),
                    selected: _category == null,
                    onSelected: (_) => setState(() => _category = null),
                  ),
                ),
                for (final c in TemplateCategory.values)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text(_label(s, c)),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              // 2 columns on phones, more on wide screens.
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                childAspectRatio: 9 / 16,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final t = items[i];
                return GestureDetector(
                  onTap: () => Navigator.pop(context, t),
                  child: Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(14),
                    clipBehavior: Clip.antiAlias,
                    child: StoryPreview(
                      background: t.background,
                      layers: t.buildLayers(),
                      borderRadius: 14,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
