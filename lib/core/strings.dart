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
