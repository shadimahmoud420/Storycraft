# دليل StoryCraft الكامل: من التشغيل إلى النشر في المتاجر

هذا الدليل يغطي كل الخطوات بالترتيب. الخطوات المشتركة أولاً، ثم Google Play، ثم App Store.

---

## 0) ما تحتاجه قبل البدء

| الأداة / الحساب | لماذا | التكلفة |
|---|---|---|
| Flutter SDK (الإصدار المستقر) | بناء التطبيق | مجاني |
| Android Studio | Android SDK ومحاكي أندرويد | مجاني |
| حساب Google Play Console | النشر على Google Play | 25$ مرة واحدة |
| حساب Apple Developer Program | النشر على App Store | 99$ سنوياً |
| جهاز Mac مع Xcode **أو** حساب Codemagic | بناء نسخة iOS | Codemagic فيه خطة مجانية محدودة الدقائق |
| تطبيق على Meta for Developers | معرّف App ID للمشاركة المباشرة في قصة إنستغرام | مجاني |

تحقق من البيئة بتشغيل:
```bash
flutter doctor
```

---

## 1) التشغيل لأول مرة

```bash
cd storycraft
# غيّر ORG إلى نطاقك العكسي؛ المعرّف النهائي سيكون <ORG>.storycraft
ORG=com.yourname bash tool/setup.sh
flutter run
```

السكربت `tool/setup.sh` يقوم بما يلي:
1. ينشئ مجلدي `android/` و `ios/` بأمر `flutter create`، مع الاحتفاظ بملف `AndroidManifest.xml` الموجود في المشروع.
2. يضبط الإعدادات الأصلية عبر `tool/configure_platforms.py`:
   - في iOS: اسم التطبيق، ونصوص أذونات الصور والكاميرا، والوضع العمودي فقط، و iPhone فقط (فلا تُطلب لقطات iPad)، وخيار `ITSAppUsesNonExemptEncryption = NO`.
   - في Android: توقيع نسخة الإصدار من ملف `key.properties`.
3. يثبّت الحزم، ثم ينشئ أيقونات التطبيق وشاشة البداية.

> **مهم:** معرّف التطبيق (Bundle ID / Application ID) لا يمكن تغييره بعد أول رفع، لذلك اختره قبل تشغيل السكربت.
> إذا غيّرت `ORG` فعدّل أيضاً `bundle_identifier` في ملف `codemagic.yaml`.

بعد نجاح الإعداد، احفظ مجلدي `android/` و `ios/` في git (أمر commit)، لأنهما أصبحا جزءاً من المشروع.

### الاختبارات
```bash
flutter analyze
flutter test
```

---

## 2) تفعيل المشاركة المباشرة في قصة إنستغرام

تشترط إنستغرام معرّف تطبيق من Meta (Facebook App ID) عند المشاركة المباشرة في القصة.

1. ادخل إلى https://developers.facebook.com ثم **My Apps** ثم **Create App**.
2. اختر نوع تطبيق بسيط (مثل Other ثم Consumer)، وسمّه StoryCraft.
3. انسخ الرقم الظاهر في **App ID**.
4. ضعه في `lib/core/config.dart`:
   ```dart
   static const facebookAppId = '123456789012345';
   ```

قبل إضافة المعرّف يعمل زر «مشاركة في قصة إنستغرام» عبر قائمة المشاركة العامة في النظام، ويستطيع المستخدم اختيار إنستغرام منها يدوياً.

---

## 3) اختبار شامل قبل النشر (Checklist)

- [ ] جرّب على شاشة صغيرة (iPhone SE أو أندرويد بعرض 360dp) وعلى شاشة كبيرة (Pro Max).
- [ ] جرّب واجهة التطبيق باللغتين العربية والإنجليزية.
- [ ] جرّب ميزتي «ألوان طبيعية» و«تحسين ذكي» على صورة داكنة، وصورة لونها يميل إلى الأصفر، وصورة صغيرة.
- [ ] جرّب الحفظ في الصور، ثم المشاركة في إنستغرام، ثم المشاركة العامة.
- [ ] جرّب رفض إذن الصور ثم التأكد أن التطبيق لا يتعطل.
- [ ] شغّل نسخة الإصدار: `flutter run --release`.

---

## 4) Google Play

### 4.1 مفتاح التوقيع (مرة واحدة فقط، واحتفظ به بأمان)
```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA \
  -keysize 2048 -validity 10000 -alias upload
```
انسخ `android/key.properties.example` إلى `android/key.properties` واملأ القيم.
**لا ترفع هذا الملف ولا ملف `.jks` إلى git.** الملف `.gitignore` يستثنيهما مسبقاً.

### 4.2 بناء الحزمة
```bash
flutter build appbundle --release
# الناتج: build/app/outputs/bundle/release/app-release.aab
```

### 4.3 Play Console
1. **Create app**: الاسم `StoryCraft: Story Designer`، اللغة الافتراضية العربية، النوع App، والتطبيق مجاني.
2. **App content** (محتوى التطبيق):
   - **Privacy policy**: ارفع `docs/privacy-policy.html` على رابط عام (مثل GitHub Pages)، ثم ضع الرابط هنا وفي `AppConfig.privacyPolicyUrl`.
   - **Data safety**: التطبيق لا يجمع أي بيانات ولا يشاركها. الصور تُعالج على الجهاز فقط.
   - **Ads**: لا يوجد.
   - **Content rating**: أجب على الاستبيان، والفئة Utility/Productivity، والنتيجة المتوقعة Everyone أو 3+.
   - **Target audience**: 13+.
3. **Store listing**: انسخ النصوص من `docs/STORE_LISTING.md`، وارفع الأيقونة `assets/icon/icon.png` بعد تصغيرها إلى 512×512، وصورة Feature graphic بمقاس 1024×500، ومن 2 إلى 8 لقطات شاشة.
4. **Testing**:
   - الحسابات الشخصية الجديدة مطالَبة بـ **Closed testing** مع **12 مختبراً على الأقل لمدة 14 يوماً متواصلة** قبل السماح بالنشر للجميع.
   - ارفع ملف `.aab` في Closed testing، وأضف قائمة بريد المختبرين، ثم شارك معهم رابط الاشتراك.
5. بعد مرور 14 يوماً: **Apply for production**، ثم **Production** ثم **Create release**، وارفع الحزمة ثم **Send for review**.

### 4.4 التحديثات
زِد رقم البناء في `pubspec.yaml` مع كل رفع جديد، مثلاً `version: 1.0.1+2`.

---

## 5) App Store (iOS)

### 5.1 التسجيل
1. اشترك في Apple Developer Program: https://developer.apple.com/programs
2. في **Certificates, Identifiers & Profiles** ثم **Identifiers**: أنشئ App ID بالمعرّف نفسه (مثل `com.yourname.storycraft`).
3. في App Store Connect: **My Apps** ثم **+** ثم **New App**:
   - الاسم: `StoryCraft: Story Designer`. إذا كان الاسم محجوزاً فجرّب `StoryCraft – Story Maker`.
   - Primary language: Arabic، و SKU: `storycraft-001`.

### 5.2 البناء على جهاز Mac
```bash
cd ios && pod install && cd ..
open ios/Runner.xcworkspace
```
في Xcode: **Runner** ثم **Signing & Capabilities** ثم اختر **Team** وفعّل **Automatically manage signing**.

```bash
flutter build ipa --release
```
بعد ذلك ارفع الملف `build/ios/ipa/*.ipa` باستخدام تطبيق **Transporter** من Mac App Store، أو عبر Xcode من **Window** ثم **Organizer** ثم **Distribute App**.

### 5.3 بدون جهاز Mac (Codemagic)
1. أنشئ حساباً على https://codemagic.io واربط مستودع git.
2. في App Store Connect: **Users and Access** ثم **Integrations** ثم **App Store Connect API**، وأنشئ مفتاحاً بصلاحية App Manager. نزّل ملف `.p8`.
3. في Codemagic: **Team settings** ثم **Integrations** ثم **Developer Portal**، وأضف المفتاح باسم `StoryCraft ASC`.
4. في `codemagic.yaml`: ضع قيمة `APP_STORE_APPLE_ID`، وحدّث `bundle_identifier`.
5. شغّل workflow **ios-release**، وسيصل البناء إلى TestFlight تلقائياً.

### 5.4 صفحة التطبيق في App Store Connect
- **App Privacy**: اختر **Data Not Collected**.
- **Age rating**: أجب على الاستبيان، والنتيجة المتوقعة 4+.
- **Screenshots**: لقطات iPhone بمقاس 6.9 بوصة (1320×2868) إلزامية، ويمكن إضافة مقاس 6.5 بوصة (1284×2778).
- **Category**: Photo & Video، والفئة الثانوية Graphics & Design.
- **App Review Information**: التطبيق لا يحتاج تسجيل دخول. اكتب ملاحظة للمراجع:
  > StoryCraft is a story design tool. All photo processing (color balance and enhancement) runs on-device. The "Share to Instagram Story" button uses Meta's official Sharing to Stories API.
- اختر البناء من TestFlight ثم **Add for Review** ثم **Submit**.

---

## 6) أسباب الرفض الشائعة وطريقة تجنبها

| السبب | ما فعلناه |
|---|---|
| استخدام علامة Instagram في الاسم أو الأيقونة | الاسم StoryCraft، والأيقونة بألوان مختلفة عن هوية إنستغرام. لا تضع كلمة "Instagram" في اسم التطبيق. يمكن ذكرها في الوصف بصيغة "for Instagram Stories" فقط. |
| غياب نصوص أذونات الصور | يضيفها `configure_platforms.py` تلقائياً. |
| وصف "ذكاء اصطناعي" مبالغ فيه | الوصف يستخدم عبارة "تحسين ذكي". التحسين خوارزمي ويعمل على الجهاز. لا تَعِد بميزات غير موجودة. |
| غياب سياسة الخصوصية | موجودة في `docs/privacy-policy.html`. ارفعها وضع رابطها. |
| تطبيق "بسيط جداً" (Guideline 4.2) | يحتوي التطبيق على محرر نصوص متعدد الطبقات، وخطوط، وتدرجات، ومعالجة صور، ومشاركة. قدّم لقطات شاشة تُظهر هذه الميزات. |
