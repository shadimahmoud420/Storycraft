import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/locale_controller.dart';
import 'services/brand_kit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Stories are vertical; keep the editor portrait on every phone.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final locale = await LocaleController.load();
  await BrandKitStore.instance.load();
  runApp(StoryCraftApp(localeController: locale));
}
