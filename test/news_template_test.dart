import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storycraft/data/fonts.dart';
import 'package:storycraft/models/story_layer.dart';
import 'package:storycraft/screens/news_screen.dart';
import 'package:storycraft/services/news_profile.dart';
import 'package:storycraft/widgets/news_card.dart';

void main() {
  test('profile survives JSON', () {
    const p = NewsProfile(
      name: 'سارة أحمد',
      handle: '@sara.news',
      signatureId: 'sig_1',
      accent: Color(0xFF1D4E89),
      design: NewsDesign.paper,
      showDateTime: false,
      location: 'وسط المدينة',
      tag: 'متابعة',
    );
    final back = NewsProfile.fromJson(p.toJson());
    expect(back.toJson(), p.toJson());
    expect(const NewsProfile().isSetUp, isFalse);
    expect(p.isSetUp, isTrue);
  });

  test('date line', () {
    expect(newsDateLine(DateTime(2026, 10, 2, 21, 45)),
        'الجمعة ٢ أكتوبر ٢٠٢٦ · ٩:٤٥ م');
    expect(newsDateLine(DateTime(2026, 10, 2, 0, 5)).endsWith('١٢:٠٥ ص'), isTrue);
  });

  test('long news gets a smaller font', () {
    const style = TextStyle(fontSize: 30, height: 1.5);
    const box = Size(300, 300);
    final short = fitFontSize('خبر قصير', style, box);
    final long = fitFontSize('خبر طويل جدًا ' * 30, style, box);
    expect(short, 40);
    expect(long, lessThan(short));
  });

  testWidgets('every design renders, with and without extras', (tester) async {
    final sig = StoryLayer(
        id: 's',
        kind: LayerKind.signature,
        text: 'سارة أحمد',
        font: StoryFonts.byFamily('Aref Ruqaa'),
        color: const Color(0xFFE9C46A));
    for (final d in NewsDesign.values) {
      for (final full in [true, false]) {
        await tester.pumpWidget(MaterialApp(
          home: Center(
            child: NewsCard(
              profile: NewsProfile(
                  name: full ? 'سارة أحمد' : '',
                  handle: full ? '@sara' : '',
                  design: d,
                  showDateTime: full),
              text: full ? 'خبر ' * 60 : '',
              date: DateTime(2026, 10, 2, 9),
              tag: full ? 'عاجل' : '',
              location: full ? 'وسط المدينة' : '',
              signature: full ? sig : null,
            ),
          ),
        ));
        expect(tester.takeException(), isNull, reason: '$d $full');
      }
    }
  });

  testWidgets('first visit opens the one-time setup', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('ar'),
      supportedLocales: [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: NewsScreen(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('إعداد القالب'), findsWidgets);
    await tester.enterText(
        find.widgetWithText(TextField, 'الاسم (المراسل أو الصفحة)'), 'سارة أحمد');
    await tester.pump();
    expect(NewsProfileStore.instance.value.name, 'سارة أحمد');
    expect(tester.takeException(), isNull);
  });
}
