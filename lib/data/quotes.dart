import 'daily_texts.dart';

enum QuoteCategory {
  adhkar, dua, ayah, sayings, wisdom, motivation, morning, english,
}

/// A library text as one insertable phrase: the reference or the author
/// goes on its own line under the text.
String _phrase(DailyText t) {
  final src = t.source;
  if (src == null) return t.text;
  return src.startsWith('—')
      ? '${t.text}\n${src.substring(1).trim()}'
      : '${t.text}\n[ $src ]';
}

List<String> _merge(List<String> own, List<DailyText> library) =>
    {...own, ...library.map(_phrase)}.toList();

/// Everything offered by the "Quotes" button: the short ready phrases
/// below plus the full daily-story library (prayers, verses, sayings…).
final quotes = <QuoteCategory, List<String>>{
  QuoteCategory.adhkar: _merge(_phrases[QuoteCategory.adhkar]!, DailyTexts.dhikr),
  QuoteCategory.dua: [for (final t in DailyTexts.dua) _phrase(t)],
  QuoteCategory.ayah: [for (final t in DailyTexts.ayah) _phrase(t)],
  QuoteCategory.sayings: [for (final t in DailyTexts.saying) _phrase(t)],
  QuoteCategory.wisdom: _merge(_phrases[QuoteCategory.wisdom]!, DailyTexts.wisdom),
  QuoteCategory.motivation:
      _merge(_phrases[QuoteCategory.motivation]!, DailyTexts.quote),
  QuoteCategory.morning: _phrases[QuoteCategory.morning]!,
  QuoteCategory.english: _phrases[QuoteCategory.english]!,
};

/// Short ready-to-use phrases. Quran verses are quoted exactly with
/// diacritics.
const _phrases = <QuoteCategory, List<String>>{
  QuoteCategory.adhkar: [
    'سبحان الله وبحمده، سبحان الله العظيم',
    'لا إله إلا الله وحده لا شريك له',
    'اللهم صلِّ وسلّم على نبينا محمد',
    'أستغفر الله العظيم وأتوب إليه',
    'لا حول ولا قوة إلا بالله',
    'حسبنا الله ونعم الوكيل',
    'إِنَّ مَعَ الْعُسْرِ يُسْرًا',
    'وَقُل رَّبِّ زِدْنِي عِلْمًا',
    'فَاذْكُرُونِي أَذْكُرْكُمْ',
    'رَبِّ اشْرَحْ لِي صَدْرِي',
  ],
  QuoteCategory.morning: [
    'صباح الخير والأمل',
    'صباحكم سعادة لا تنتهي',
    'صباح الورد والياسمين',
    'ابدأ يومك بابتسامة',
    'صباح مليء بالتفاؤل',
    'صباحٌ جميل لقلوب جميلة',
  ],
  QuoteCategory.wisdom: [
    'من جدّ وجد، ومن زرع حصد',
    'الصبر مفتاح الفرج',
    'خير الكلام ما قلّ ودلّ',
    'القناعة كنز لا يفنى',
    'في التأني السلامة وفي العجلة الندامة',
    'رُبّ أخٍ لك لم تلده أمك',
    'العلم نور',
  ],
  QuoteCategory.motivation: [
    'لا تتوقف حتى تفخر بنفسك',
    'كل خطوة صغيرة تقرّبك من حلمك',
    'النجاح رحلة وليس محطة',
    'ثق بنفسك، فأنت أقوى مما تظن',
    'اليوم بداية جديدة',
    'اصنع فرصتك بنفسك',
  ],
  QuoteCategory.english: [
    'Good vibes only',
    'Dream big, work hard',
    'Every day is a fresh start',
    'Be the energy you want to attract',
    'Stay humble, work hard, be kind',
    'Create your own sunshine',
    'Small steps every day',
  ],
};

/// Emoji stickers (rendered in full color by the platform font).
const stickerEmoji = [
  '❤️', '🤍', '💜', '💛', '🔥', '✨', '⭐', '🌟', '🌙', '☀️',
  '🌸', '🌹', '🌷', '🍃', '🌿', '🎉', '🎊', '🎁', '🎂', '🎓',
  '☕', '📍', '📸', '🎵', '💐', '👑', '💎', '🕌', '🏮', '🤲',
  '😍', '🥰', '😂', '😎', '🙏', '👏', '💯', '✅', '👇', '👉',
];

/// Monochrome symbols that follow the selected layer color.
const stickerSymbols = [
  '★', '☆', '♥', '♡', '✦', '✧', '❝', '❞', '→', '←',
  '↑', '↓', '✓', '✿', '❀', '☾', '☀', '✈', '♪', '∞',
  '●', '◆', '▲', '※',
];
