import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/date_text.dart';
import '../models/story_layer.dart';
import '../services/news_profile.dart';
import 'signature_view.dart';

/// Design space of a news card (a 9:16 story, exported at 3x).
const newsCardSize = Size(360, 640);

/// Labels offered above the news.
const newsTags = ['عاجل', 'خبر', 'متابعة', 'ميداني', 'تنويه', 'تحديث'];

/// "الخميس ٢ أكتوبر ٢٠٢٦ · ٩:٤٥ م"
String newsDateLine(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  final time = DateText.digits('$h:$m');
  return '${DateText.weekday(d)} ${DateText.greg(d)} · $time ${d.hour < 12 ? 'ص' : 'م'}';
}

/// Largest font size (between [min] and [max]) at which [text] fits in
/// [box]. Public for tests.
double fitFontSize(String text, TextStyle style, Size box,
    {double min = 16, double max = 40}) {
  for (var size = max; size > min; size -= 1) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style.copyWith(fontSize: size)),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.right,
    )..layout(maxWidth: box.width);
    if (tp.height <= box.height) return size;
  }
  return min;
}

/// A finished news post: the user's fixed identity (name, handle,
/// signature, logo, colors) around the news text, with date and place.
class NewsCard extends StatelessWidget {
  const NewsCard({
    super.key,
    required this.profile,
    required this.text,
    required this.date,
    this.tag = '',
    this.location = '',
    this.photo,
    this.signature,
  });

  final NewsProfile profile;
  final String text;
  final DateTime date;
  final String tag;
  final String location;
  final Uint8List? photo;
  final StoryLayer? signature;

  bool get _paper => profile.design == NewsDesign.paper;
  Color get _ink => _paper ? const Color(0xFF16181D) : Colors.white;
  Color get _muted => _paper ? const Color(0xFF5A5F69) : Colors.white70;

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: newsCardSize,
      child: Material(
        type: MaterialType.transparency,
        textStyle: const TextStyle(
            fontFamily: 'Cairo', decoration: TextDecoration.none),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: ClipRect(
            child: Stack(
              children: [
                Positioned.fill(child: _background()),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(26, 0, 26, 26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _header(),
                        Expanded(child: _body()),
                        _footer(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _background() {
    switch (profile.design) {
      case NewsDesign.breaking:
        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0B1220), Color(0xFF14213D), Color(0xFF0B1220)],
            ),
          ),
          child: CustomPaint(painter: _LinesPainter(profile.accent)),
        );
      case NewsDesign.field:
        return Stack(
          fit: StackFit.expand,
          children: [
            if (photo != null)
              Image.memory(photo!, fit: BoxFit.cover, gaplessPlayback: true)
            else
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2B2D31), Color(0xFF111214)],
                  ),
                ),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x66000000),
                    Color(0x00000000),
                    Color(0xB3000000),
                    Color(0xF0000000),
                  ],
                  stops: [0, 0.22, 0.5, 1],
                ),
              ),
            ),
          ],
        );
      case NewsDesign.paper:
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                profile.accent,
                profile.accent,
                const Color(0xFFF7F4EE),
                const Color(0xFFF7F4EE)
              ],
              stops: const [0, 118 / 640, 118 / 640, 1],
            ),
          ),
        );
    }
  }

  Widget _header() {
    final logo = profile.logo;
    return SizedBox(
      height: 118,
      child: Row(
        children: [
          if (tag.isNotEmpty) _tagBadge(),
          const Spacer(),
          if (logo != null)
            Container(
              width: 46,
              height: 46,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Image.memory(logo, fit: BoxFit.cover),
            ),
        ],
      ),
    );
  }

  Widget _tagBadge() {
    final onAccent = _paper ? Colors.white : Colors.white;
    final bg = _paper ? Colors.white.withValues(alpha: 0.18) : profile.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: onAccent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(tag,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: onAccent,
                  height: 1.2)),
        ],
      ),
    );
  }

  TextAlign get _textAlign => switch (profile.align) {
        NewsAlign.right => TextAlign.right,
        NewsAlign.center => TextAlign.center,
        NewsAlign.left => TextAlign.left,
        NewsAlign.justify => TextAlign.justify,
      };

  Widget _body() {
    final field = profile.design == NewsDesign.field;
    final style = TextStyle(
      fontFamily: 'Cairo',
      fontWeight: profile.bold ? FontWeight.w700 : FontWeight.w500,
      height: 1.55,
      color: _ink,
      shadows: field
          ? const [Shadow(color: Color(0x99000000), blurRadius: 8)]
          : null,
    );
    final news = text.trim().isEmpty ? '…' : text.trim();
    // The accent bar follows the text's alignment.
    final barAlign = switch (profile.align) {
      NewsAlign.center => Alignment.center,
      NewsAlign.left => Alignment.centerLeft,
      _ => Alignment.centerRight,
    };
    final y = profile.textY ?? (field ? 1.0 : 0.5);
    return LayoutBuilder(
      builder: (context, box) {
        // Room left for the bar and the place and date lines.
        final meta = (location.trim().isNotEmpty ? 26.0 : 0) +
            (profile.showDateTime ? 26.0 : 0) +
            (field ? 0 : 23) +
            18;
        final area = Size(box.maxWidth, box.maxHeight - meta - 24);
        final base = field ? 34.0 : 38.0;
        final size = fitFontSize(news, style, area,
            min: 12, max: base * profile.textScale);
        return Align(
          alignment: Alignment(0, y * 2 - 1),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: box.maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!field)
                  Align(
                    alignment: barAlign,
                    child: Container(
                      width: 54,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: profile.accent,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                Flexible(
                  child: Text(news,
                      textAlign: _textAlign,
                      overflow: TextOverflow.fade,
                      style: style.copyWith(fontSize: size)),
                ),
                const SizedBox(height: 16),
                if (location.trim().isNotEmpty)
                  _metaLine(Icons.location_on_rounded, location.trim()),
                if (profile.showDateTime)
                  _metaLine(Icons.schedule_rounded, newsDateLine(date)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _metaLine(IconData icon, String value) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          mainAxisAlignment: switch (profile.align) {
            NewsAlign.center => MainAxisAlignment.center,
            NewsAlign.left => MainAxisAlignment.end,
            _ => MainAxisAlignment.start,
          },
          children: [
            Icon(icon, size: 16, color: profile.accent),
            const SizedBox(width: 6),
            Flexible(
              child: Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      color: _muted,
                      height: 1.3)),
            ),
          ],
        ),
      );

  Widget _footer() {
    var sig = signature;
    if (sig != null && _paper && sig.color.computeLuminance() > 0.4) {
      // A light signature would vanish on paper: ink it dark.
      sig = sig.clone()..color = const Color(0xFF16181D);
    }
    final hasName = profile.name.trim().isNotEmpty;
    final hasHandle = profile.handle.trim().isNotEmpty;
    if (sig == null && !hasName && !hasHandle) return const SizedBox();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 1,
          margin: const EdgeInsets.only(bottom: 12),
          color: _muted.withValues(alpha: 0.35),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasName)
                    Text(profile.name.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                            height: 1.3)),
                  if (hasHandle)
                    Text(profile.handle.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            color: profile.accent,
                            height: 1.3)),
                ],
              ),
            ),
            if (sig != null)
              SizedBox(
                width: 150,
                height: 64,
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: AlignmentDirectional.centerEnd,
                  child: SignatureView(layer: sig),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Faint diagonal lines and an accent glow for the "breaking" design.
class _LinesPainter extends CustomPainter {
  _LinesPainter(this.accent);

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [accent.withValues(alpha: 0.35), accent.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(
          center: Offset(size.width, 0), radius: size.width * 0.9));
    canvas.drawRect(Offset.zero & size, glow);
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    for (var x = -size.height; x < size.width; x += 18) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), line);
    }
    // Accent strip at the bottom edge.
    canvas.drawRect(Rect.fromLTWH(0, size.height - 6, size.width, 6),
        Paint()..color = accent);
  }

  @override
  bool shouldRepaint(_LinesPainter old) => old.accent != accent;
}
