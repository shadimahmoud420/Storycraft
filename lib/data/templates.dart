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

/// Cartoon illustration centered at (x, y).
StoryLayer _a(String name, double x, double y, {double size = 130}) =>
    StoryLayer(
      id: 'a',
      kind: LayerKind.art,
      text: name,
      size: size,
      position: Offset(x, y),
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
const _white = 0xFFFFFFFF;

final storyTemplates = <StoryTemplate>[
  // Ramadan
  StoryTemplate(
    TemplateCategory.ramadan,
    const StoryBackground.gradient([Color(0xFF141E46), Color(0xFF3B1F6E)]),
    () => [
      _a('lantern_garland', 180, 150, size: 360),
      _a('crescent', 272, 250, size: 105),
      _t('رمضان كريم', 'Aref Ruqaa', 58, _gold, 335, shadow: true),
      _t('أعاده الله علينا وعليكم بالخير', 'Tajawal', 20, _white, 400),
      _a('mosque', 180, 470, size: 130),
    ],
  ),
  StoryTemplate(
    TemplateCategory.ramadan,
    const StoryBackground.gradient([Color(0xFFFFB25B), Color(0xFFE5566B)]),
    () => [
      _a('lantern', 300, 165, size: 70),
      _a('cannon', 110, 225, size: 150),
      _a('fasting_kid', 255, 250, size: 120),
      _t('حان وقت الإفطار', 'Lalezar', 44, _white, 350, shadow: true),
      _t('تقبّل الله صيامكم', 'Tajawal', 22, _white, 405),
      _a('dates', 180, 470, size: 110),
    ],
  ),
  // Eid
  StoryTemplate(
    TemplateCategory.eid,
    const StoryBackground.gradient([Color(0xFF6A11CB), Color(0xFF2575FC)]),
    () => [
      _a('bunting', 180, 125, size: 360),
      _a('balloons', 90, 245, size: 120),
      _a('gift', 280, 255, size: 100),
      _t('عيدكم مبارك', 'Lalezar', 58, _white, 345, shadow: true),
      _t('كل عام وأنتم بخير', 'Tajawal', 24, _white, 410),
      _a('sweets', 180, 475, size: 120),
    ],
  ),
  StoryTemplate(
    TemplateCategory.eid,
    const StoryBackground.solid(Color(0xFFFFF4E0)),
    () => [
      _a('fireworks', 180, 195, size: 160),
      _t('عيد سعيد', 'Aref Ruqaa', 62, 0xFF5B2A86, 325),
      _t('تقبّل الله منا ومنكم', 'Tajawal', 22, 0xFF7A3E12, 395),
      _a('sweets', 180, 470, size: 140),
    ],
  ),
  // Friday
  StoryTemplate(
    TemplateCategory.friday,
    const StoryBackground.gradient([Color(0xFF134E5E), Color(0xFF71B280)]),
    () => [
      _a('sparkles', 60, 140, size: 50),
      _a('mosque', 180, 215, size: 165),
      _t('جمعة مباركة', 'Aref Ruqaa', 56, _white, 345, shadow: true),
      _t('اللهم صلِّ وسلّم على نبينا محمد', 'Amiri', 22, _white, 410),
      _a('misbaha', 180, 480, size: 80),
    ],
  ),
  StoryTemplate(
    TemplateCategory.friday,
    const StoryBackground.solid(Color(0xFFF5F0E6)),
    () => [
      _a('dua_hands', 180, 205, size: 150),
      _t('جمعة طيبة', 'El Messiri', 46, 0xFF8B5E3C, 330),
      _t('لا تنسوا قراءة سورة الكهف', 'Tajawal', 22, 0xFF556B2F, 395),
      _a('misbaha', 180, 470, size: 90),
    ],
  ),
  // Good morning
  StoryTemplate(
    TemplateCategory.morning,
    const StoryBackground.gradient([Color(0xFFFFE259), Color(0xFFFFA751)]),
    () => [
      _a('sun', 180, 200, size: 150),
      _t('صباح الخير', 'Lalezar', 60, 0xFF7B3F00, 320),
      _t('ابدأ يومك بابتسامة وأمل جديد', 'Tajawal', 22, 0xFF5A3200, 385),
      _a('coffee', 115, 465, size: 100),
      _a('flowers', 255, 460, size: 100),
    ],
  ),
  StoryTemplate(
    TemplateCategory.morning,
    const StoryBackground.gradient([Color(0xFFA18CD1), Color(0xFFFBC2EB)]),
    () => [
      _a('sparkles', 60, 150, size: 50),
      _a('coffee', 180, 215, size: 150),
      _t('Good Morning', 'Pacifico', 48, _white, 335, shadow: true),
      _t('Make today amazing', 'Montserrat', 22, _white, 400),
      _a('flowers', 290, 470, size: 90),
    ],
  ),
  // Congrats
  StoryTemplate(
    TemplateCategory.congrats,
    const StoryBackground.gradient(
        [Color(0xFF3A1C71), Color(0xFFD76D77), Color(0xFFFFAF7B)]),
    () => [
      _a('popper', 95, 205, size: 120),
      _a('balloons', 270, 210, size: 120),
      _t('ألف مبروك', 'Lalezar', 62, _white, 335, shadow: true),
      _t('فرحتكم فرحتنا', 'Tajawal', 24, _white, 400),
      _a('cake', 180, 475, size: 110),
    ],
  ),
  StoryTemplate(
    TemplateCategory.congrats,
    const StoryBackground.solid(Color(0xFF111111)),
    () => [
      _a('sparkles', 70, 150, size: 50),
      _a('trophy', 180, 210, size: 140),
      _s(ShapeKind.label, _gold, 335, size: 230),
      _t('CONGRATS', 'Bebas Neue', 56, 0xFF111111, 335),
      _t('You did it!', 'Great Vibes', 44, _gold, 410),
      _a('sparkles', 290, 480, size: 50),
    ],
  ),
  // Graduation
  StoryTemplate(
    TemplateCategory.graduation,
    const StoryBackground.gradient([Color(0xFF000428), Color(0xFF004E92)]),
    () => [
      _a('graduate', 180, 215, size: 160),
      _t('مبروك التخرج', 'Reem Kufi', 48, _white, 345),
      _t('Class of 2026', 'Playfair Display', 26, _gold, 405),
      _a('sparkles', 70, 470, size: 50),
      _a('diploma', 275, 470, size: 100),
    ],
  ),
  StoryTemplate(
    TemplateCategory.graduation,
    const StoryBackground.solid(Color(0xFFFFFFFF)),
    () => [
      _a('grad_cap', 180, 200, size: 150),
      _t('تخرّجت!', 'Rakkas', 64, 0xFF1F3A5F, 320),
      _s(ShapeKind.line, 0xFFC8A27A, 370, size: 140),
      _t('والقادم أجمل بإذن الله', 'Tajawal', 22, 0xFF1F3A5F, 410),
      _a('diploma', 180, 480, size: 120),
    ],
  ),
];
