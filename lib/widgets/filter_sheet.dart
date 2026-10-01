import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../data/filters.dart';
import '../state/editor_controller.dart';

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

/// Filter thumbnails of the current photo + intensity slider. Changes
/// apply live; the whole session is one undo step.
Future<void> showFilterSheet(BuildContext context, EditorController c) {
  c.checkpoint();
  return showModalBottomSheet<void>(
    context: context,
    barrierColor: Colors.transparent,
    builder: (context) => ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final s = S.of(context);
        final bg = c.background;
        final bytes = bg.imageBytes;
        if (bytes == null) return const SizedBox.shrink();
        final thumb = MemoryImage(bytes);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 116,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: PhotoFilter.values.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final f = PhotoFilter.values[i];
                    final selected = f == bg.filter;
                    return GestureDetector(
                      onTap: () => c.setFilter(
                        f,
                        f == bg.filter ? bg.filterIntensity : 1,
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 86,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: ColorFiltered(
                                colorFilter: ColorFilter.matrix(
                                    PhotoFilters.matrixOf(f)),
                                child: Image(
                                  image: ResizeImage(thumb, width: 160),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(filterLabel(s, f),
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (bg.filter != PhotoFilter.none)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(s.intensity),
                      Expanded(
                        child: Slider(
                          value: bg.filterIntensity,
                          onChanged: (v) => c.setFilter(bg.filter, v),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text('${(bg.filterIntensity * 100).round()}%'),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    ),
  );
}
