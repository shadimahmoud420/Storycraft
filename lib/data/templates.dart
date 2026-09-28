import 'package:flutter/material.dart';

import '../models/story_background.dart';
import '../models/story_layer.dart';
import 'fonts.dart';

enum TemplateCategory { ramadan, eid, friday, morning, congrats, graduation }

/// A ready-made design: background + layers, opened in the editor as a
/// fully editable story.
class StoryTemplate {
  const StoryTemplate(this.category, this.background, this._layers);

  final TemplateCategory category;
  final StoryBackground background;
  final List<StoryLayer> Function() _layers;

  /// Fresh, independent layers every time (templates are never mutated).
  List<StoryLayer> buildLayers() => _layers();
}

StoryLayer _t(
  String text,
  String font,
  double size,
  int color,
  double y, {
  TextHighlight highlight = TextHighlight.none,
  bool shadow = false,
}) =>
    StoryLayer(
      id: 't',
      text: text,
      font: StoryFonts.byFamily(font),
      fontSize: size,
      color: Color(color),
      position: Offset(180, y),
      highlight: highlight,
      shadow: shadow,
    );

StoryLayer _e(String emoji, double y, {double size = 84}) => StoryLayer(
      id: 'e',
      kind: LayerKind.emoji,
      text: emoji,
      fontSize: size,
      position: Offset(180, y),
    );

StoryLayer _s(ShapeKind shape, int color, double y, {double size = 180}) =>
    StoryLayer(
      id: 's',
      kind: LayerKind.shape,
      shape: shape,
      color: Color(color),
      size: size,
      position: Offset(180, y),
    );

const _gold = 0xFFF2C94C;

final storyTemplates = <StoryTemplate>[
  // Ramadan
  StoryTemplate(
    TemplateCategory.ramadan,
    const StoryBackground.gradient([Color(0xFF0B1437), Color(0xFF1F3A6E)]),
    () => [
      _e('🌙', 200, size: 90),
      _t('رمضان كريم', 'Aref Ruqaa', 58, _gold, 300),
      _s(ShapeKind.line, _gold, 360, size: 120),
      _t('أعاده الله علينا وعليكم\nبالخير واليمن والبركات', 'Tajawal', 21,
          0xFFFFFFFF, 420),
    ],
  ),
  StoryTemplate(
    TemplateCategory.ramadan,
    const StoryBackground.gradient([Color(0xFF2B1B4A), Color(0xFF5B2A86)]),
    () => [
      _s(ShapeKind.roundedFrame, _gold, 330, size: 270),
      _e('🏮', 215, size: 64),
      _t('مبارك عليكم الشهر', 'El Messiri', 30, 0xFFFFFFFF, 320),
      _t('اللهم بلّغنا رمضان', 'Amiri', 26, _gold, 400),
    ],
  ),
  // Eid
  StoryTemplate(
    TemplateCategory.eid,
    const StoryBackground.gradient([Color(0xFFF6D365), Color(0xFFFDA085)]),
    () => [
      _e('🎉', 200),
      _t('عيدكم مبارك', 'Lalezar', 58, 0xFF5B1A1A, 300),
      _t('كل عام وأنتم بخير', 'Tajawal', 26, 0xFF5B1A1A, 380),
    ],
  ),
  StoryTemplate(
    TemplateCategory.eid,
    const StoryBackground.solid(Color(0xFF0F3D3E)),
    () => [
      _s(ShapeKind.circleFrame, _gold, 310, size: 230),
      _t('عيد سعيد', 'Aref Ruqaa', 54, _gold, 305),
      _t('تقبّل الله منا ومنكم', 'Tajawal', 22, 0xFFFFFFFF, 470),
    ],
  ),
  // Friday
  StoryTemplate(
    TemplateCategory.friday,
    const StoryBackground.gradient([Color(0xFF134E5E), Color(0xFF71B280)]),
    () => [
      _e('🤍', 190, size: 64),
      _t('جمعة مباركة', 'Aref Ruqaa', 58, 0xFFFFFFFF, 285),
      _t('اللهم صلِّ وسلّم على نبينا محمد', 'Amiri', 24, 0xFFFFFFFF, 380),
    ],
  ),
  StoryTemplate(
    TemplateCategory.friday,
    const StoryBackground.solid(Color(0xFFF5F0E6)),
    () => [
      _s(ShapeKind.rectFrame, 0xFF8B5E3C, 320, size: 260),
      _t('جمعة طيبة', 'El Messiri', 46, 0xFF8B5E3C, 290),
      _t('لا تنسوا قراءة سورة الكهف', 'Tajawal', 22, 0xFF556B2F, 370),
    ],
  ),
  // Good morning
  StoryTemplate(
    TemplateCategory.morning,
    const StoryBackground.gradient([Color(0xFFFFE259), Color(0xFFFFA751)]),
    () => [
      _e('☀️', 195, size: 90),
      _t('صباح الخير', 'Lalezar', 60, 0xFF7B3F00, 300),
      _t('ابدأ يومك بابتسامة وأمل جديد', 'Tajawal', 24, 0xFF5A3200, 380),
    ],
  ),
  StoryTemplate(
    TemplateCategory.morning,
    const StoryBackground.gradient([Color(0xFFA18CD1), Color(0xFFFBC2EB)]),
    () => [
      _e('☕', 200, size: 80),
      _t('Good Morning', 'Pacifico', 50, 0xFFFFFFFF, 295, shadow: true),
      _t('Make today amazing', 'Montserrat', 22, 0xFFFFFFFF, 375),
    ],
  ),
  // Congrats
  StoryTemplate(
    TemplateCategory.congrats,
    const StoryBackground.gradient(
        [Color(0xFF3A1C71), Color(0xFFD76D77), Color(0xFFFFAF7B)]),
    () => [
      _e('🎊', 200),
      _t('ألف مبروك', 'Lalezar', 62, 0xFFFFFFFF, 300, shadow: true),
      _t('فرحتكم فرحتنا', 'Tajawal', 26, 0xFFFFFFFF, 380),
    ],
  ),
  StoryTemplate(
    TemplateCategory.congrats,
    const StoryBackground.solid(Color(0xFF111111)),
    () => [
      _s(ShapeKind.label, _gold, 300, size: 230),
      _t('CONGRATS', 'Bebas Neue', 56, 0xFF111111, 300),
      _t('You did it!', 'Great Vibes', 44, _gold, 385),
    ],
  ),
  // Graduation
  StoryTemplate(
    TemplateCategory.graduation,
    const StoryBackground.gradient([Color(0xFF000428), Color(0xFF004E92)]),
    () => [
      _e('🎓', 200, size: 96),
      _t('مبروك التخرج', 'Reem Kufi', 50, 0xFFFFFFFF, 305),
      _t('Class of 2026', 'Playfair Display', 28, _gold, 375),
    ],
  ),
  StoryTemplate(
    TemplateCategory.graduation,
    const StoryBackground.solid(Color(0xFFFFFFFF)),
    () => [
      _e('🎓', 200, size: 84),
      _t('تخرّجت!', 'Rakkas', 64, 0xFF1F3A5F, 300),
      _s(ShapeKind.line, 0xFFC8A27A, 360, size: 140),
      _t('والقادم أجمل بإذن الله', 'Tajawal', 24, 0xFF1F3A5F, 405),
    ],
  ),
];
