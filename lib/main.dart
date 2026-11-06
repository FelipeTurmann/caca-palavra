import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'app.dart';

Future<void> main() => runWordGame(const WordGameApp());

Future<void> runWordGame(WordGameApp app) async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'pt-br — referência lexical',
    ], await rootBundle.loadString('assets/data/LICENSE-fserb.txt'));
    yield LicenseEntryWithLineBreaks(
      ['PortiLexicon-UD — léxico morfológico'],
      await rootBundle.loadString(
        'tool/content/catalog-v3/LICENSE-PortiLexicon-UD.txt',
      ),
    );
  });
  runApp(app);
}
