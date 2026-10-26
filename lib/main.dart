import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'pt-br — referência lexical',
    ], await rootBundle.loadString('assets/data/LICENSE-fserb.txt'));
  });
  runApp(const WordGameApp());
}
