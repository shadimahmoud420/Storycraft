enum QuoteCategory { adhkar, morning, wisdom, motivation, english }

/// Ready-to-use phrases. Quran verses are quoted exactly with diacritics.
const quotes = <QuoteCategory, List<String>>{
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
