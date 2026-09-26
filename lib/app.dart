import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/config.dart';
import 'core/locale_controller.dart';
import 'core/theme.dart';
import 'screens/home_screen.dart';

class StoryCraftApp extends StatelessWidget {
  const StoryCraftApp({super.key, required this.localeController});

  final LocaleController localeController;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: localeController,
      builder: (context, locale, _) => MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(Brightness.light),
        darkTheme: AppTheme.build(Brightness.dark),
        locale: locale,
        supportedLocales: LocaleController.supported,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // Device languages other than Arabic/English get English.
        localeResolutionCallback: (device, supported) =>
            device?.languageCode == 'ar' ? const Locale('ar') : const Locale('en'),
        builder: (context, child) {
          // Respect accessibility text size but keep layouts intact.
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              textScaler: media.textScaler.clamp(maxScaleFactor: 1.3),
            ),
            child: child!,
          );
        },
        home: HomeScreen(localeController: localeController),
      ),
    );
  }
}
