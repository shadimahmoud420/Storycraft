import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../models/story_layer.dart';
import '../state/editor_controller.dart';
import 'story_view.dart';

/// Layers panel: the stack from top to bottom. Drag to reorder, tap to
/// select, eye to hide; the selected layer gets opacity and quick
/// forward/backward buttons. The canvas stays visible above it.
Future<void> showLayersSheet(BuildContext context, EditorController c) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    barrierColor: Colors.transparent,
    builder: (context) => ListenableBuilder(
      listenable: c,
      builder: (context, _) => _LayersPanel(c),
    ),
  );
}

class _LayersPanel extends StatelessWidget {
  const _LayersPanel(this.c);

  final EditorController c;

  String _title(S s, StoryLayer l) => switch (l.kind) {
        LayerKind.text => l.text.replaceAll('\n', ' '),
        LayerKind.signature => '${s.signature} · ${l.text}',
        LayerKind.emoji => '${s.layerEmoji} ${l.text}',
        LayerKind.shape => s.layerShape,
        LayerKind.image => s.addPhoto,
        LayerKind.art => s.layerArt,
        LayerKind.ornament => s.layerOrnament,
        LayerKind.watermark => 'StoryCraft',
      };

  IconData _icon(StoryLayer l) => switch (l.kind) {
        LayerKind.text => Icons.text_fields_rounded,
        LayerKind.signature => Icons.draw_rounded,
        LayerKind.emoji => Icons.emoji_emotions_rounded,
        LayerKind.shape => Icons.crop_square_rounded,
        LayerKind.image => Icons.image_rounded,
        LayerKind.art => Icons.auto_awesome_rounded,
        LayerKind.ornament => Icons.texture_rounded,
        LayerKind.watermark => Icons.verified_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    // Top of the stack first, like every design app.
    final layers = c.layers.reversed.toList();
    final n = layers.length;
    final sel = c.selected;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.layers_rounded),
                const SizedBox(width: 8),
                Text(s.layers, style: theme.textTheme.titleMedium),
                const Spacer(),
                if (n > 1)
                  Text(s.dragToReorder, style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            if (n == 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(s.noLayers, textAlign: TextAlign.center),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.34,
                ),
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  buildDefaultDragHandles: false,
                  itemCount: n,
                  onReorderItem: (from, to) {
                    // Displayed index i ↔ stack index n-1-i.
                    c.moveLayer(layers[from].id, n - 1 - to);
                  },
                  itemBuilder: (context, i) {
                    final l = layers[i];
                    final selected = l.id == c.selectedId;
                    return Padding(
                      key: ValueKey(l.id),
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Material(
                        color: selected
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: l.hidden ? null : () => c.select(l.id),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            child: Row(
                              children: [
                                ReorderableDragStartListener(
                                  index: i,
                                  child: const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Icon(Icons.drag_indicator_rounded),
                                  ),
                                ),
                                _Thumb(layer: l),
                                const SizedBox(width: 10),
                                Icon(_icon(l), size: 18),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _title(s, l),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: l.hidden
                                          ? theme.disabledColor
                                          : null,
                                    ),
                                  ),
                                ),
                                if (l.opacity < 1)
                                  Text('${(l.opacity * 100).round()}%',
                                      style: theme.textTheme.bodySmall),
                                IconButton(
                                  tooltip: s.lock,
                                  icon: Icon(l.locked
                                      ? Icons.lock_rounded
                                      : Icons.lock_open_rounded),
                                  onPressed: () => c.toggleLocked(l.id),
                                ),
                                IconButton(
                                  icon: Icon(l.hidden
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded),
                                  onPressed: () => c.toggleHidden(l.id),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // The background is always the bottom layer.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 34,
                    height: 44,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: StoryBackgroundView(background: c.background),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.wallpaper_rounded, size: 18),
                  const SizedBox(width: 6),
                  Text(s.background),
                  const Spacer(),
                  const Icon(Icons.lock_rounded, size: 16),
                ],
              ),
            ),

            // Selected layer: order and opacity.
            if (sel != null) ...[
              const SizedBox(height: 10),
              Row(
                spacing: 6,
                children: [
                  _OrderButton(Icons.vertical_align_top_rounded, s.toFront,
                      () => c.bringToFront(sel.id)),
                  _OrderButton(Icons.arrow_upward_rounded, s.forward,
                      () => c.bringForward(sel.id)),
                  _OrderButton(Icons.arrow_downward_rounded, s.backward,
                      () => c.sendBackward(sel.id)),
                  _OrderButton(Icons.vertical_align_bottom_rounded, s.toBack,
                      () => c.sendToBack(sel.id)),
                ],
              ),
              Row(
                children: [
                  Text(s.opacity, style: theme.textTheme.titleSmall),
                  Expanded(
                    child: Slider(
                      value: sel.opacity,
                      min: 0.05,
                      max: 1,
                      onChangeStart: (_) => c.checkpoint(),
                      onChanged: (v) => c.updateLayer(
                          sel.id, (l) => l.opacity = v,
                          record: false),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '${(sel.opacity * 100).round()}%',
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.layer});

  final StoryLayer layer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A33),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IgnorePointer(
        child: FittedBox(
          child: Opacity(
            opacity: layer.hidden ? 0.35 : 1,
            child: StoryLayerVisual(layer: layer),
          ),
        ),
      ),
    );
  }
}

class _OrderButton extends StatelessWidget {
  const _OrderButton(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 8),
          minimumSize: const Size(0, 52),
        ),
        onPressed: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 2),
            FittedBox(child: Text(label)),
          ],
        ),
      ),
    );
  }
}
