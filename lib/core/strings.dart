import 'package:flutter/widgets.dart';

/// Lightweight Arabic / English strings. Arabic switches the whole UI to RTL
/// automatically through [Localizations].
class S {
  S._(this._lang);

  final String _lang;

  static S of(BuildContext context) =>
      S._(Localizations.localeOf(context).languageCode);

  bool get isArabic => _lang == 'ar';

  String _t(String key) => (_values[_lang] ?? _values['en']!)[key] ?? key;

  String get appName => _t('appName');
  String get tagline => _t('tagline');
  String get fromPhoto => _t('fromPhoto');
  String get fromPhotoHint => _t('fromPhotoHint');
  String get fromColor => _t('fromColor');
  String get fromColorHint => _t('fromColorHint');
  String get fromGradient => _t('fromGradient');
  String get fromGradientHint => _t('fromGradientHint');
  String get language => _t('language');
  String get privacyPolicy => _t('privacyPolicy');
  String get text => _t('text');
  String get background => _t('background');
  String get natural => _t('natural');
  String get enhance => _t('enhance');
  String get fit => _t('fit');
  String get original => _t('original');
  String get share => _t('share');
  String get save => _t('save');
  String get saved => _t('saved');
  String get done => _t('done');
  String get cancel => _t('cancel');
  String get delete => _t('delete');
  String get duplicate => _t('duplicate');
  String get typeHere => _t('typeHere');
  String get arabicFonts => _t('arabicFonts');
  String get englishFonts => _t('englishFonts');
  String get color => _t('color');
  String get size => _t('size');
  String get highlight => _t('highlight');
  String get shadow => _t('shadow');
  String get classic => _t('classic');
  String get gradients => _t('gradients');
  String get photo => _t('photo');
  String get changePhoto => _t('changePhoto');
  String get processing => _t('processing');
  String get naturalDone => _t('naturalDone');
  String get enhanceDone => _t('enhanceDone');
  String get processFailed => _t('processFailed');
  String get shareToStory => _t('shareToStory');
  String get shareOther => _t('shareOther');
  String get instagramMissing => _t('instagramMissing');
  String get discardTitle => _t('discardTitle');
  String get discardBody => _t('discardBody');
  String get discard => _t('discard');
  String get tapToAddText => _t('tapToAddText');
  String get saveFailed => _t('saveFailed');
  String get angle => _t('angle');
  String get removeBg => _t('removeBg');
  String get removeBgDone => _t('removeBgDone');
  String get removeBgNoSubject => _t('removeBgNoSubject');
  String get removeBgUnsupported => _t('removeBgUnsupported');
  String get removeBgPreparing => _t('removeBgPreparing');
  String get removingBg => _t('removingBg');
  String get addPhoto => _t('addPhoto');
  String get dailyStory => _t('dailyStory');
  String get dailyHint => _t('dailyHint');
  String get anotherDesign => _t('anotherDesign');
  String get anotherText => _t('anotherText');
  String get edit => _t('edit');
  String get auto => _t('auto');
  String get catDua => _t('catDua');
  String get catDhikr => _t('catDhikr');
  String get catAyah => _t('catAyah');
  String get catWisdom => _t('catWisdom');
  String get catQuote => _t('catQuote');
  String get catSaying => _t('catSaying');
  String get fGlow => _t('fGlow');
  String get fFood => _t('fFood');
  String get fNature => _t('fNature');
  String get camera => _t('camera');
  String get cameraHint => _t('cameraHint');
  String get cameraDenied => _t('cameraDenied');
  String get cameraUnavailable => _t('cameraUnavailable');
  String get retake => _t('retake');
  String get saveFull => _t('saveFull');
  String get lvTitle => _t('lvTitle');
  String get lvHint => _t('lvHint');
  String get lvPickVideo => _t('lvPickVideo');
  String get lvPickVideoHint => _t('lvPickVideoHint');
  String get lvSong => _t('lvSong');
  String get lvPickSong => _t('lvPickSong');
  String get lvSongStart => _t('lvSongStart');
  String get lvRights => _t('lvRights');
  String get lvRemoveSong => _t('lvRemoveSong');
  String get lvLyrics => _t('lvLyrics');
  String get lvWriteLyrics => _t('lvWriteLyrics');
  String get lvLyricsHint => _t('lvLyricsHint');
  String get lvSync => _t('lvSync');
  String get lvSyncHint => _t('lvSyncHint');
  String get lvNext => _t('lvNext');
  String get lvSynced => _t('lvSynced');
  String get lvNoLyrics => _t('lvNoLyrics');
  String get lvEffect => _t('lvEffect');
  String get lvLook => _t('lvLook');
  String get lvFade => _t('lvFade');
  String get lvKaraoke => _t('lvKaraoke');
  String get lvWipe => _t('lvWipe');
  String get lvWords => _t('lvWords');
  String get lvZoom => _t('lvZoom');
  String get lvSlide => _t('lvSlide');
  String get lvBox => _t('lvBox');
  String get lvGlow => _t('lvGlow');
  String get lvPosition => _t('lvPosition');
  String get lvSize => _t('lvSize');
  String get lvExport => _t('lvExport');
  String get lvPreparing => _t('lvPreparing');
  String get lvComposing => _t('lvComposing');
  String get lvReady => _t('lvReady');
  String get lvSaved => _t('lvSaved');
  String get lvFailed => _t('lvFailed');
  String get lvTooLong => _t('lvTooLong');
  String get lvSongPart => _t('lvSongPart');
  String get lvSongPartHint => _t('lvSongPartHint');
  String get lvPartLength => _t('lvPartLength');
  String get lvRestored => _t('lvRestored');
  String get lvNewProject => _t('lvNewProject');
  String get lvNewProjectAsk => _t('lvNewProjectAsk');
  String get lvAutosave => _t('lvAutosave');
  String get lvAutoSync => _t('lvAutoSync');
  String get lvAligned => _t('lvAligned');
  String get lvTipPaste => _t('lvTipPaste');
  String get lvAuto => _t('lvAuto');
  String get lvListening => _t('lvListening');
  String get lvAutoDone => _t('lvAutoDone');
  String get lvAutoNone => _t('lvAutoNone');
  String get lvAutoDenied => _t('lvAutoDenied');
  String get lvAutoUnsupported => _t('lvAutoUnsupported');
  String get lvLangAr => _t('lvLangAr');
  String get lvLangEn => _t('lvLangEn');
  String get lvSoft => _t('lvSoft');
  String get lvTemplates => _t('lvTemplates');
  String get lvCinematic => _t('lvCinematic');
  String get lvClassic => _t('lvClassic');
  String get lvSimple => _t('lvSimple');
  String get lvCredit => _t('lvCredit');
  String get lvBold => _t('lvBold');
  String get lvShade => _t('lvShade');
  String get designStory => _t('designStory');
  String get strength => _t('strength');
  String get timer => _t('timer');
  String get grid => _t('grid');
  String get flash => _t('flash');
  String get quotesDua => _t('quotesDua');
  String get quotesAyah => _t('quotesAyah');
  String get today => _t('today');
  String get backToToday => _t('backToToday');
  String get settings => _t('settings');
  String get watermarkSetting => _t('watermarkSetting');
  String get watermarkHint => _t('watermarkHint');
  String get hideWatermark => _t('hideWatermark');
  String get hideWatermarkHint => _t('hideWatermarkHint');
  String get hide => _t('hide');
  String get hijriAdjust => _t('hijriAdjust');
  String get hijriAdjustHint => _t('hijriAdjustHint');
  String get reminder => _t('reminder');
  String get reminderHint => _t('reminderHint');
  String get reminderTime => _t('reminderTime');
  String get reminderTitle => _t('reminderTitle');
  String get reminderDenied => _t('reminderDenied');
  String get layerOrnament => _t('layerOrnament');
  String get lock => _t('lock');
  String get cutAuto => _t('cutAuto');
  String get cutAutoHint => _t('cutAutoHint');
  String get cutColor => _t('cutColor');
  String get cutColorHint => _t('cutColorHint');
  String get cutStrength => _t('cutStrength');
  String get cutEdgesOnly => _t('cutEdgesOnly');
  String get cutEdgesOnlyHint => _t('cutEdgesOnlyHint');
  String get inkColor => _t('inkColor');
  String get white => _t('white');
  String get black => _t('black');
  String get apply => _t('apply');
  String get tryColorMode => _t('tryColorMode');
  String get layers => _t('layers');
  String get opacity => _t('opacity');
  String get toFront => _t('toFront');
  String get forward => _t('forward');
  String get backward => _t('backward');
  String get toBack => _t('toBack');
  String get layerEmoji => _t('layerEmoji');
  String get layerShape => _t('layerShape');
  String get layerArt => _t('layerArt');
  String get noLayers => _t('noLayers');
  String get dragToReorder => _t('dragToReorder');

  String get templates => _t('templates');
  String get templatesHint => _t('templatesHint');
  String get drafts => _t('drafts');
  String get deleteDraft => _t('deleteDraft');
  String get draftSaved => _t('draftSaved');
  String get quotes => _t('quotes');
  String get stickers => _t('stickers');
  String get emoji => _t('emoji');
  String get symbols => _t('symbols');
  String get shapes => _t('shapes');
  String get brandKit => _t('brandKit');
  String get brandKitHint => _t('brandKitHint');
  String get logo => _t('logo');
  String get addLogo => _t('addLogo');
  String get chooseLogo => _t('chooseLogo');
  String get removeLogo => _t('removeLogo');
  String get brandColors => _t('brandColors');
  String get favoriteFont => _t('favoriteFont');
  String get none => _t('none');
  String get setUpBrandKit => _t('setUpBrandKit');
  String get useAsBackground => _t('useAsBackground');
  String get undo => _t('undo');
  String get redo => _t('redo');
  String get dim => _t('dim');
  String get all => _t('all');
  String get ramadan => _t('ramadan');
  String get eid => _t('eid');
  String get friday => _t('friday');
  String get morning => _t('morning');
  String get congrats => _t('congrats');
  String get graduation => _t('graduation');
  String get adhkar => _t('adhkar');
  String get wisdom => _t('wisdom');
  String get motivation => _t('motivation');
  String get english => _t('english');
  String get photoHint => _t('photoHint');
  String get style => _t('style');
  String get illustrations => _t('illustrations');

  String get fontTab => _t('fontTab');
  String get effects => _t('effects');
  String get curveTab => _t('curveTab');
  String get fillSolid => _t('fillSolid');
  String get fillGradient => _t('fillGradient');
  String get fillGold => _t('fillGold');
  String get fillSilver => _t('fillSilver');
  String get fillRose => _t('fillRose');
  String get secondColor => _t('secondColor');
  String get outline => _t('outline');
  String get letterSpacing => _t('letterSpacing');
  String get lineHeight => _t('lineHeight');
  String get straight => _t('straight');
  String get curveHint => _t('curveHint');
  String get catModern => _t('catModern');
  String get catKufi => _t('catKufi');
  String get catNaskh => _t('catNaskh');
  String get catCalligraphy => _t('catCalligraphy');
  String get catDisplay => _t('catDisplay');
  String get catSans => _t('catSans');
  String get catSerif => _t('catSerif');
  String get catScript => _t('catScript');
  String get catHand => _t('catHand');

  String get filters => _t('filters');
  String get intensity => _t('intensity');
  String get fNone => _t('fNone');
  String get fVivid => _t('fVivid');
  String get fWarm => _t('fWarm');
  String get fCool => _t('fCool');
  String get fVintage => _t('fVintage');
  String get fMono => _t('fMono');
  String get fFade => _t('fFade');
  String get fDrama => _t('fDrama');
  String get fRose => _t('fRose');
  String get format => _t('format');
  String get fmtStory => _t('fmtStory');
  String get fmtPortrait => _t('fmtPortrait');
  String get fmtSquare => _t('fmtSquare');
  String get fmtWide => _t('fmtWide');
  String get fmtStoryHint => _t('fmtStoryHint');
  String get fmtPortraitHint => _t('fmtPortraitHint');
  String get fmtSquareHint => _t('fmtSquareHint');
  String get fmtWideHint => _t('fmtWideHint');

  String get signature => _t('signature');
  String get signatureHint => _t('signatureHint');
  String get yourName => _t('yourName');
  String get chooseStyle => _t('chooseStyle');
  String get saveSignature => _t('saveSignature');
  String get savedSignatures => _t('savedSignatures');
  String get newSignature => _t('newSignature');
  String get placeOn => _t('placeOn');
  String get onPhoto => _t('onPhoto');
  String get onGradient => _t('onGradient');
  String get onClassic => _t('onClassic');
  String get signatureSaved => _t('signatureSaved');
  String get deleteSignature => _t('deleteSignature');
  String get noSignatures => _t('noSignatures');
  String get useSignature => _t('useSignature');
  String get sigSwash => _t('sigSwash');
  String get sigPlain => _t('sigPlain');
  String get sigUnderline => _t('sigUnderline');
  String get sigSeal => _t('sigSeal');
  String get sigMonogram => _t('sigMonogram');
  String get sigFramed => _t('sigFramed');

  String get sigOrnate => _t('sigOrnate');
  String get sigLaurel => _t('sigLaurel');
  String get sigRoyal => _t('sigRoyal');
  String get sigArabesque => _t('sigArabesque');
  String get sigDivider => _t('sigDivider');
  String get sigSparkle => _t('sigSparkle');
  String get rotation => _t('rotation');
  String get scaleLabel => _t('scaleLabel');
  String get rotateResize => _t('rotateResize');
  String get reset => _t('reset');

  static const _values = <String, Map<String, String>>{
    'ar': {
      'appName': 'StoryCraft',
      'tagline': 'صمّم قصتك بلمسة احترافية',
      'fromPhoto': 'من صورة',
      'fromPhotoHint': 'ارفع صورة وحسّنها بضغطة زر',
      'fromColor': 'لون كلاسيكي',
      'fromColorHint': 'خلفية بلون واحد أنيق',
      'fromGradient': 'تدرّج لوني',
      'fromGradientHint': 'تدرّجات جاهزة أو من اختيارك',
      'language': 'English',
      'privacyPolicy': 'سياسة الخصوصية',
      'text': 'نص',
      'background': 'الخلفية',
      'natural': 'ألوان طبيعية',
      'enhance': 'تحسين ذكي',
      'fit': 'ملاءمة',
      'original': 'الأصل',
      'share': 'مشاركة',
      'save': 'حفظ',
      'saved': 'تم الحفظ في الصور',
      'done': 'تم',
      'cancel': 'إلغاء',
      'delete': 'حذف',
      'duplicate': 'تكرار',
      'typeHere': 'اكتب هنا…',
      'arabicFonts': 'عربي',
      'englishFonts': 'English',
      'color': 'اللون',
      'size': 'الحجم',
      'highlight': 'خلفية النص',
      'shadow': 'ظل',
      'classic': 'كلاسيك',
      'gradients': 'تدرّجات',
      'photo': 'صورة',
      'changePhoto': 'تغيير الصورة',
      'processing': 'جاري المعالجة…',
      'naturalDone': 'تم ضبط الألوان',
      'enhanceDone': 'تم تحسين الصورة',
      'processFailed': 'تعذّرت معالجة الصورة',
      'shareToStory': 'مشاركة في قصة إنستغرام',
      'shareOther': 'مشاركة عبر تطبيق آخر',
      'instagramMissing': 'تطبيق إنستغرام غير متوفر، استخدم المشاركة العامة',
      'discardTitle': 'الخروج من التصميم؟',
      'discardBody': 'ستفقد التعديلات غير المحفوظة.',
      'discard': 'خروج',
      'tapToAddText': 'اضغط «نص» لإضافة كتابة',
      'saveFailed': 'تعذّر الحفظ، تحقق من صلاحية الصور',
      'angle': 'الاتجاه',
      'removeBg': 'إزالة الخلفية',
      'removeBgDone': 'تم التفريغ ✨ غيّر الخلفية من «الخلفية»',
      'removeBgNoSubject': 'لم أجد شخصًا أو عنصرًا واضحًا في الصورة',
      'removeBgUnsupported': 'إزالة الخلفية غير مدعومة على هذا الجهاز',
      'removeBgPreparing': 'يتم تجهيز أداة التفريغ لأول مرة… حاول بعد دقيقة',
      'removingBg': 'جارٍ تفريغ الصورة…',
      'addPhoto': 'صورة',
      'dailyStory': 'ستوري اليوم',
      'dailyHint': 'تصميم جديد كل يوم بتاريخ اليوم',
      'anotherDesign': 'تصميم آخر',
      'anotherText': 'نص آخر',
      'edit': 'تعديل',
      'auto': 'تلقائي',
      'catDua': 'دعاء',
      'catDhikr': 'ذكر',
      'catAyah': 'آية',
      'catWisdom': 'حكمة',
      'catQuote': 'اقتباس',
      'catSaying': 'أقوال الحكماء',
      'fGlow': 'Glow',
      'fFood': 'طعام',
      'fNature': 'طبيعة',
      'camera': 'الكاميرا',
      'cameraHint': 'تصوير 4K بفلاتر مباشرة',
      'cameraDenied': 'اسمح للتطبيق باستخدام الكاميرا من إعدادات الجوال',
      'cameraUnavailable': 'لا توجد كاميرا متاحة على هذا الجهاز',
      'retake': 'إعادة',
      'saveFull': 'حفظ بالجودة الكاملة',
      'lvTitle': 'فيديو بأغنية',
      'lvHint': 'فيديو بدون صوت + أغنيتك + كلماتها بمؤثرات',
      'lvPickVideo': 'اختر فيديو',
      'lvPickVideoHint': 'سيُحذف صوت الفيديو الأصلي، ثم تضيف أغنيتك وكلماتها',
      'lvSong': 'الأغنية',
      'lvPickSong': 'اختر ملفًا صوتيًا',
      'lvSongStart': 'بداية المقطع',
      'lvRights': 'استخدم مقاطع تملك حق استخدامها. يمكنك أيضًا التصدير بدون أغنية ثم إضافتها من ملصق الموسيقى في إنستغرام.',
      'lvRemoveSong': 'إزالة الأغنية',
      'lvLyrics': 'الكلمات',
      'lvWriteLyrics': 'كتابة الكلمات',
      'lvLyricsHint': 'اكتب أو الصق الكلمات، كل سطر في سطر',
      'lvSync': 'مزامنة مع الأغنية',
      'lvSyncHint': 'اضغط «التالي» لحظة بداية كل سطر',
      'lvNext': 'التالي',
      'lvSynced': 'تمت المزامنة ✓',
      'lvNoLyrics': 'لم تُكتب كلمات بعد',
      'lvEffect': 'المؤثر',
      'lvLook': 'الشكل',
      'lvFade': 'ظهور',
      'lvKaraoke': 'كاريوكي',
      'lvWipe': 'كتابة',
      'lvWords': 'كلمة كلمة',
      'lvZoom': 'تكبير',
      'lvSlide': 'انزلاق',
      'lvBox': 'خلفية للنص',
      'lvGlow': 'توهج',
      'lvPosition': 'الموضع',
      'lvSize': 'الحجم',
      'lvExport': 'تصدير الفيديو',
      'lvPreparing': 'تجهيز الكلمات…',
      'lvComposing': 'دمج الفيديو والأغنية…',
      'lvReady': 'الفيديو جاهز 🎬',
      'lvSaved': 'تم حفظ الفيديو في المعرض',
      'lvFailed': 'تعذّر تصدير الفيديو',
      'lvTooLong': 'سيُستخدم أول ٦٠ ثانية من الفيديو',
      'lvSongPart': 'المقطع المختار',
      'lvSongPartHint': 'اسحب الطرفين لاختيار بداية ونهاية المقطع من الأغنية',
      'lvPartLength': 'المدة',
      'lvRestored': 'تم استرجاع مشروعك المحفوظ',
      'lvNewProject': 'مشروع جديد',
      'lvNewProjectAsk': 'سيتم حذف المشروع الحالي والبدء من جديد. متابعة؟',
      'lvAutosave': 'يُحفظ مشروعك تلقائيًا',
      'lvAutoSync': 'مزامنة تلقائية للكلمات',
      'lvAligned': 'تمت مزامنة {n} من {t} سطر تلقائيًا ✓',
      'lvTipPaste': 'للحصول على كلمات صحيحة ١٠٠٪: الصق كلمات الأغنية أولًا من «كتابة الكلمات»، ثم اضغط المزامنة التلقائية ليضبط التطبيق توقيتها فقط.',
      'lvAuto': 'كتابة تلقائية من الأغنية',
      'lvListening': 'جارٍ الاستماع للأغنية وكتابة الكلمات…',
      'lvAutoDone': 'تمت كتابة الكلمات ✓ راجعها وعدّل أي خطأ',
      'lvAutoNone': 'لم يُتعرّف على كلمات واضحة في هذا المقطع',
      'lvAutoDenied': 'اسمح للتطبيق بالتعرف على الكلام من الإعدادات',
      'lvAutoUnsupported': 'الكتابة التلقائية متاحة حاليًا على iPhone فقط',
      'lvLangAr': 'عربي',
      'lvLangEn': 'إنجليزي',
      'lvSoft': 'ناعم',
      'lvTemplates': 'قوالب جاهزة',
      'lvCinematic': 'سينمائي',
      'lvClassic': 'كاريوكي ذهبي',
      'lvSimple': 'بسيط بخلفية',
      'lvCredit': 'سطر صغير تحت الكلمات (الأغنية · الفنان)',
      'lvBold': 'عريض',
      'lvShade': 'تظليل سينمائي',
      'designStory': 'صمّم ستوري',
      'strength': 'الدرجة',
      'timer': 'المؤقت',
      'grid': 'الشبكة',
      'flash': 'الفلاش',
      'quotesDua': 'أدعية',
      'quotesAyah': 'آيات',
      'today': 'اليوم',
      'backToToday': 'العودة لليوم',
      'settings': 'الإعدادات',
      'watermarkSetting': 'توقيع التطبيق على التصاميم',
      'watermarkHint': 'علامة StoryCraft صغيرة أسفل التصميم',
      'hideWatermark': 'إخفاء توقيع التطبيق من التصاميم؟',
      'hideWatermarkHint': 'يمكنك إعادته من الإعدادات في الشاشة الرئيسية',
      'hide': 'إخفاء',
      'hijriAdjust': 'تعديل التاريخ الهجري',
      'hijriAdjustHint': 'حسب رؤية الهلال في بلدك',
      'reminder': 'تذكير ستوري اليوم',
      'reminderHint': 'إشعار يومي عندما يجهز تصميم اليوم',
      'reminderTime': 'وقت التذكير',
      'reminderTitle': 'ستوري اليوم جاهز 🌸',
      'reminderDenied': 'لم يُسمح بالإشعارات. فعّلها من إعدادات الجوال',
      'layerOrnament': 'زخرفة',
      'lock': 'قفل',
      'cutAuto': 'تلقائي',
      'cutAutoHint': 'أشخاص وعناصر',
      'cutColor': 'لون الخلفية',
      'cutColorHint': 'توقيع، شعار، رسم',
      'cutStrength': 'قوة الإزالة',
      'cutEdgesOnly': 'من الأطراف فقط',
      'cutEdgesOnlyHint': 'يُبقي الأجزاء الداخلية التي بلون الخلفية',
      'inkColor': 'لون الرسم',
      'white': 'أبيض',
      'black': 'أسود',
      'apply': 'تطبيق',
      'tryColorMode': 'للتوقيع والرسم جرّب «لون الخلفية»',
      'layers': 'الطبقات',
      'opacity': 'الشفافية',
      'toFront': 'للأعلى',
      'forward': 'تقديم',
      'backward': 'تأخير',
      'toBack': 'للأسفل',
      'layerEmoji': 'إيموجي',
      'layerShape': 'شكل',
      'layerArt': 'ملصق',
      'noLayers': 'لا توجد طبقات بعد — أضف نصًا أو صورة',
      'dragToReorder': 'اسحب المقبض لتغيير الترتيب',
      'sigOrnate': 'مزخرف',
      'sigLaurel': 'إكليل غار',
      'sigRoyal': 'ملكي',
      'sigArabesque': 'إطار عربي',
      'sigDivider': 'فاصل مزخرف',
      'sigSparkle': 'لمعات',
      'rotation': 'الدوران',
      'scaleLabel': 'الحجم',
      'rotateResize': 'الدوران والحجم',
      'reset': 'إعادة الضبط',
      'signature': 'توقيعي',
      'signatureHint': 'صمّم توقيعك مرة واحدة وضعه على أي صورة',
      'yourName': 'اكتب اسمك',
      'chooseStyle': 'اختر شكل التوقيع',
      'saveSignature': 'حفظ التوقيع',
      'savedSignatures': 'تواقيعي المحفوظة',
      'newSignature': 'توقيع جديد',
      'placeOn': 'أين تريد وضع توقيعك؟',
      'onPhoto': 'على صورة',
      'onGradient': 'على تدرّج لوني',
      'onClassic': 'على لون كلاسيكي',
      'signatureSaved': 'تم حفظ التوقيع',
      'deleteSignature': 'حذف التوقيع؟',
      'noSignatures': 'لا توجد تواقيع محفوظة بعد',
      'useSignature': 'استخدم هذا التوقيع',
      'sigSwash': 'انسيابي',
      'sigPlain': 'بسيط',
      'sigUnderline': 'خط سفلي',
      'sigSeal': 'ختم',
      'sigMonogram': 'الحرف الأول',
      'sigFramed': 'بين خطين',
      'filters': 'فلاتر',
      'intensity': 'الشدة',
      'fNone': 'بدون',
      'fVivid': 'حيوي',
      'fWarm': 'دافئ',
      'fCool': 'بارد',
      'fVintage': 'قديم',
      'fMono': 'أبيض وأسود',
      'fFade': 'باهت',
      'fDrama': 'درامي',
      'fRose': 'وردي',
      'format': 'المقاس',
      'fmtStory': 'قصة 9:16',
      'fmtPortrait': 'منشور 4:5',
      'fmtSquare': 'مربع 1:1',
      'fmtWide': 'عريض 16:9',
      'fmtStoryHint': 'إنستغرام، سناب شات، تيك توك، حالة واتساب',
      'fmtPortraitHint': 'منشور إنستغرام وفيسبوك',
      'fmtSquareHint': 'منشور مربع لكل المنصات',
      'fmtWideHint': 'يوتيوب وتويتر (إكس) والعروض',
      'fontTab': 'الخط',
      'effects': 'التأثيرات',
      'curveTab': 'الانحناء',
      'fillSolid': 'لون واحد',
      'fillGradient': 'تدرّج',
      'fillGold': 'ذهبي',
      'fillSilver': 'فضي',
      'fillRose': 'وردي ذهبي',
      'secondColor': 'اللون الثاني',
      'outline': 'حدود الحروف',
      'letterSpacing': 'تباعد الحروف',
      'lineHeight': 'تباعد الأسطر',
      'straight': 'مستقيم',
      'curveHint': 'اسحب لليسار أو اليمين لثني النص على شكل قوس',
      'catModern': 'عصري',
      'catKufi': 'كوفي',
      'catNaskh': 'نسخ',
      'catCalligraphy': 'مخطوط',
      'catDisplay': 'عناوين',
      'catSans': 'بسيط',
      'catSerif': 'كلاسيكي',
      'catScript': 'مزخرف',
      'catHand': 'يدوي',
      'templates': 'قوالب جاهزة',
      'templatesHint': 'تصاميم للمناسبات بضغطة واحدة',
      'drafts': 'مسوداتي',
      'deleteDraft': 'حذف المسودة؟',
      'draftSaved': 'حُفظ التصميم في مسوداتك',
      'quotes': 'عبارات',
      'stickers': 'ملصقات',
      'emoji': 'إيموجي',
      'symbols': 'رموز',
      'shapes': 'أشكال',
      'brandKit': 'هويتي',
      'brandKitHint': 'شعارك وألوانك وخطك المفضل في كل تصميم',
      'logo': 'الشعار',
      'addLogo': 'أضف الشعار',
      'chooseLogo': 'اختر صورة الشعار',
      'removeLogo': 'إزالة الشعار',
      'brandColors': 'ألوان الهوية',
      'favoriteFont': 'الخط المفضل',
      'none': 'بدون',
      'setUpBrandKit': 'أعدّ هويتك التجارية',
      'useAsBackground': 'استخدم كخلفية',
      'undo': 'تراجع',
      'redo': 'إعادة',
      'dim': 'تعتيم',
      'all': 'الكل',
      'ramadan': 'رمضان',
      'eid': 'العيد',
      'friday': 'الجمعة',
      'morning': 'صباح الخير',
      'congrats': 'تهنئة',
      'graduation': 'تخرج',
      'adhkar': 'أذكار',
      'wisdom': 'حكم',
      'motivation': 'تحفيز',
      'english': 'English',
      'photoHint': 'اسحب الصورة لتحريكها وكبّرها بإصبعين',
      'style': 'التنسيق',
      'illustrations': 'رسومات',
    },
    'en': {
      'appName': 'StoryCraft',
      'tagline': 'Design stunning stories in seconds',
      'fromPhoto': 'From photo',
      'fromPhotoHint': 'Upload & enhance with one tap',
      'fromColor': 'Classic color',
      'fromColorHint': 'A clean solid background',
      'fromGradient': 'Gradient',
      'fromGradientHint': 'Ready-made or your own blend',
      'language': 'العربية',
      'privacyPolicy': 'Privacy policy',
      'text': 'Text',
      'background': 'Background',
      'natural': 'Natural',
      'enhance': 'Enhance',
      'fit': 'Fit',
      'original': 'Original',
      'share': 'Share',
      'save': 'Save',
      'saved': 'Saved to Photos',
      'done': 'Done',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'duplicate': 'Duplicate',
      'typeHere': 'Type here…',
      'arabicFonts': 'عربي',
      'englishFonts': 'English',
      'color': 'Color',
      'size': 'Size',
      'highlight': 'Highlight',
      'shadow': 'Shadow',
      'classic': 'Classic',
      'gradients': 'Gradients',
      'photo': 'Photo',
      'changePhoto': 'Change photo',
      'processing': 'Processing…',
      'naturalDone': 'Colors balanced',
      'enhanceDone': 'Photo enhanced',
      'processFailed': 'Could not process the photo',
      'shareToStory': 'Share to Instagram Story',
      'shareOther': 'Share via another app',
      'instagramMissing': 'Instagram is not available, use the share sheet',
      'discardTitle': 'Leave this design?',
      'discardBody': 'Unsaved changes will be lost.',
      'discard': 'Leave',
      'tapToAddText': 'Tap “Text” to start writing',
      'saveFailed': 'Could not save. Check Photos permission',
      'angle': 'Direction',
      'removeBg': 'Remove BG',
      'removeBgDone': 'Background removed ✨ Change it from “Background”',
      'removeBgNoSubject': 'No clear person or object found in the photo',
      'removeBgUnsupported': 'Background removal is not supported on this device',
      'removeBgPreparing': 'Preparing the cutout tool for first use… try again in a minute',
      'removingBg': 'Removing background…',
      'addPhoto': 'Photo',
      'dailyStory': 'Story of the Day',
      'dailyHint': 'A new design every day, dated today',
      'anotherDesign': 'Another design',
      'anotherText': 'Another text',
      'edit': 'Edit',
      'auto': 'Auto',
      'catDua': 'Prayer',
      'catDhikr': 'Dhikr',
      'catAyah': 'Verse',
      'catWisdom': 'Wisdom',
      'catQuote': 'Quote',
      'catSaying': 'Sayings',
      'fGlow': 'Glow',
      'fFood': 'Food',
      'fNature': 'Nature',
      'camera': 'Camera',
      'cameraHint': '4K shots with live filters',
      'cameraDenied': 'Allow camera access in your phone settings',
      'cameraUnavailable': 'No camera available on this device',
      'retake': 'Retake',
      'saveFull': 'Save full quality',
      'lvTitle': 'Song video',
      'lvHint': 'Silent video + your song + animated lyrics',
      'lvPickVideo': 'Pick a video',
      'lvPickVideoHint': 'The video’s own sound is removed; then add your song and its lyrics',
      'lvSong': 'Song',
      'lvPickSong': 'Choose an audio file',
      'lvSongStart': 'Start at',
      'lvRights': 'Use audio you have the right to use. You can also export without a song and add it with Instagram’s music sticker.',
      'lvRemoveSong': 'Remove song',
      'lvLyrics': 'Lyrics',
      'lvWriteLyrics': 'Write lyrics',
      'lvLyricsHint': 'Type or paste the lyrics, one per line',
      'lvSync': 'Sync with the song',
      'lvSyncHint': 'Tap “Next” the moment each line starts',
      'lvNext': 'Next',
      'lvSynced': 'Synced ✓',
      'lvNoLyrics': 'No lyrics yet',
      'lvEffect': 'Effect',
      'lvLook': 'Look',
      'lvFade': 'Fade',
      'lvKaraoke': 'Karaoke',
      'lvWipe': 'Write-on',
      'lvWords': 'Word by word',
      'lvZoom': 'Pop',
      'lvSlide': 'Slide',
      'lvBox': 'Text box',
      'lvGlow': 'Glow',
      'lvPosition': 'Position',
      'lvSize': 'Size',
      'lvExport': 'Export video',
      'lvPreparing': 'Preparing the lyrics…',
      'lvComposing': 'Merging video and song…',
      'lvReady': 'Your video is ready 🎬',
      'lvSaved': 'Video saved to your gallery',
      'lvFailed': 'Could not export the video',
      'lvTooLong': 'The first 60 seconds will be used',
      'lvSongPart': 'Selected part',
      'lvSongPartHint': 'Drag both ends to choose where the part starts and ends',
      'lvPartLength': 'Length',
      'lvRestored': 'Your saved project was restored',
      'lvNewProject': 'New project',
      'lvNewProjectAsk': 'The current project will be deleted to start over. Continue?',
      'lvAutosave': 'Your project is saved automatically',
      'lvAutoSync': 'Sync my lyrics automatically',
      'lvAligned': '{n} of {t} lines synced automatically ✓',
      'lvTipPaste': 'For 100% correct lyrics: paste the song’s lyrics first in “Write lyrics”, then tap automatic sync — the app only times them.',
      'lvAuto': 'Write from the song automatically',
      'lvListening': 'Listening and writing the lyrics…',
      'lvAutoDone': 'Lyrics written ✓ review and fix any mistakes',
      'lvAutoNone': 'No clear words were recognized in this part',
      'lvAutoDenied': 'Allow speech recognition for StoryCraft in Settings',
      'lvAutoUnsupported': 'Automatic lyrics are available on iPhone for now',
      'lvLangAr': 'Arabic',
      'lvLangEn': 'English',
      'lvSoft': 'Soft focus',
      'lvTemplates': 'Presets',
      'lvCinematic': 'Cinematic',
      'lvClassic': 'Gold karaoke',
      'lvSimple': 'Simple box',
      'lvCredit': 'Small line under the lyrics (song · artist)',
      'lvBold': 'Bold',
      'lvShade': 'Cinematic shade',
      'designStory': 'Design a story',
      'strength': 'Strength',
      'timer': 'Timer',
      'grid': 'Grid',
      'flash': 'Flash',
      'quotesDua': 'Prayers',
      'quotesAyah': 'Verses',
      'today': 'Today',
      'backToToday': 'Back to today',
      'settings': 'Settings',
      'watermarkSetting': 'App mark on designs',
      'watermarkHint': 'A small StoryCraft mark at the bottom',
      'hideWatermark': 'Hide the app mark from designs?',
      'hideWatermarkHint': 'You can turn it back on in Settings on the home screen',
      'hide': 'Hide',
      'hijriAdjust': 'Hijri date adjustment',
      'hijriAdjustHint': 'To match the moon sighting in your country',
      'reminder': 'Story of the day reminder',
      'reminderHint': 'A daily notification when today’s design is ready',
      'reminderTime': 'Reminder time',
      'reminderTitle': 'Your story of the day is ready 🌸',
      'reminderDenied': 'Notifications are off. Enable them in your phone settings',
      'layerOrnament': 'Ornament',
      'lock': 'Lock',
      'cutAuto': 'Auto',
      'cutAutoHint': 'People & objects',
      'cutColor': 'Background color',
      'cutColorHint': 'Signature, logo, drawing',
      'cutStrength': 'Strength',
      'cutEdgesOnly': 'From the edges only',
      'cutEdgesOnlyHint': 'Keeps inner parts that share the background color',
      'inkColor': 'Drawing color',
      'white': 'White',
      'black': 'Black',
      'apply': 'Apply',
      'tryColorMode': 'For signatures and drawings, try “Background color”',
      'layers': 'Layers',
      'opacity': 'Opacity',
      'toFront': 'To front',
      'forward': 'Forward',
      'backward': 'Backward',
      'toBack': 'To back',
      'layerEmoji': 'Emoji',
      'layerShape': 'Shape',
      'layerArt': 'Sticker',
      'noLayers': 'No layers yet — add text or a photo',
      'dragToReorder': 'Drag the handle to reorder',
      'sigOrnate': 'Ornate',
      'sigLaurel': 'Laurel',
      'sigRoyal': 'Royal',
      'sigArabesque': 'Arabesque',
      'sigDivider': 'Divider',
      'sigSparkle': 'Sparkle',
      'rotation': 'Rotation',
      'scaleLabel': 'Scale',
      'rotateResize': 'Rotate & size',
      'reset': 'Reset',
      'signature': 'Signature',
      'signatureHint': 'Design your signature once, add it to any photo',
      'yourName': 'Type your name',
      'chooseStyle': 'Pick a signature style',
      'saveSignature': 'Save signature',
      'savedSignatures': 'My signatures',
      'newSignature': 'New signature',
      'placeOn': 'Where do you want your signature?',
      'onPhoto': 'On a photo',
      'onGradient': 'On a gradient',
      'onClassic': 'On a classic color',
      'signatureSaved': 'Signature saved',
      'deleteSignature': 'Delete this signature?',
      'noSignatures': 'No saved signatures yet',
      'useSignature': 'Use this signature',
      'sigSwash': 'Swash',
      'sigPlain': 'Plain',
      'sigUnderline': 'Underline',
      'sigSeal': 'Seal',
      'sigMonogram': 'Monogram',
      'sigFramed': 'Framed',
      'filters': 'Filters',
      'intensity': 'Intensity',
      'fNone': 'None',
      'fVivid': 'Vivid',
      'fWarm': 'Warm',
      'fCool': 'Cool',
      'fVintage': 'Vintage',
      'fMono': 'Mono',
      'fFade': 'Fade',
      'fDrama': 'Drama',
      'fRose': 'Rose',
      'format': 'Size',
      'fmtStory': 'Story 9:16',
      'fmtPortrait': 'Post 4:5',
      'fmtSquare': 'Square 1:1',
      'fmtWide': 'Wide 16:9',
      'fmtStoryHint': 'Instagram, Snapchat, TikTok, WhatsApp status',
      'fmtPortraitHint': 'Instagram & Facebook post',
      'fmtSquareHint': 'Square post for any platform',
      'fmtWideHint': 'YouTube, X and presentations',
      'fontTab': 'Font',
      'effects': 'Effects',
      'curveTab': 'Curve',
      'fillSolid': 'Solid',
      'fillGradient': 'Gradient',
      'fillGold': 'Gold',
      'fillSilver': 'Silver',
      'fillRose': 'Rose gold',
      'secondColor': 'Second color',
      'outline': 'Outline',
      'letterSpacing': 'Letter spacing',
      'lineHeight': 'Line height',
      'straight': 'Straight',
      'curveHint': 'Slide to bend the text into an arc',
      'catModern': 'Modern',
      'catKufi': 'Kufi',
      'catNaskh': 'Naskh',
      'catCalligraphy': 'Calligraphy',
      'catDisplay': 'Display',
      'catSans': 'Sans',
      'catSerif': 'Serif',
      'catScript': 'Script',
      'catHand': 'Handwritten',
      'templates': 'Templates',
      'templatesHint': 'One-tap designs for every occasion',
      'drafts': 'My drafts',
      'deleteDraft': 'Delete this draft?',
      'draftSaved': 'Saved to your drafts',
      'quotes': 'Quotes',
      'stickers': 'Stickers',
      'emoji': 'Emoji',
      'symbols': 'Symbols',
      'shapes': 'Shapes',
      'brandKit': 'Brand kit',
      'brandKitHint': 'Your logo, colors and font in every design',
      'logo': 'Logo',
      'addLogo': 'Add logo',
      'chooseLogo': 'Choose logo image',
      'removeLogo': 'Remove logo',
      'brandColors': 'Brand colors',
      'favoriteFont': 'Favorite font',
      'none': 'None',
      'setUpBrandKit': 'Set up your brand kit',
      'useAsBackground': 'Use as background',
      'undo': 'Undo',
      'redo': 'Redo',
      'dim': 'Dim',
      'all': 'All',
      'ramadan': 'Ramadan',
      'eid': 'Eid',
      'friday': 'Friday',
      'morning': 'Good morning',
      'congrats': 'Congrats',
      'graduation': 'Graduation',
      'adhkar': 'Adhkar',
      'wisdom': 'Wisdom',
      'motivation': 'Motivation',
      'english': 'English',
      'photoHint': 'Drag to move the photo, pinch to zoom',
      'style': 'Style',
      'illustrations': 'Art',
    },
  };
}
