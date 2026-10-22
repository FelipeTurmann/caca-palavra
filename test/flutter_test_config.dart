import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Exercise the bundled production font, including Portuguese glyph metrics.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await (FontLoader(
    'Nunito',
  )..addFont(rootBundle.load('assets/fonts/Nunito.ttf'))).load();
  await testMain();
}
