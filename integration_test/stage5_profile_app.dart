// Profile-build benchmark. No production database and no image files are written.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:caca_palavra/core/theme/game_theme.dart';
import 'package:caca_palavra/core/feedback/game_feedback.dart';
import 'package:caca_palavra/features/game/data/game_data.dart';
import 'package:caca_palavra/features/game/domain/game_engine.dart';
import 'package:caca_palavra/features/game/presentation/game_controller.dart';
import 'package:caca_palavra/features/game/presentation/game_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final data = await GameData.load();
  final controller = GameController(
    GameEngine(levels: data.levels, lexicon: data.lexicon),
    feedbackOutput: AndroidFeedbackOutput(),
  );
  await controller.effects.prepare();
  final frames = <FrameTiming>[];
  void record(List<FrameTiming> timings) => frames.addAll(timings);
  WidgetsBinding.instance.addTimingsCallback(record);
  runApp(
    MaterialApp(
      theme: GameTheme.theme,
      home: GameScreen(controller: controller),
    ),
  );
  await Future<void>.delayed(const Duration(seconds: 2));
  frames.clear();
  // Enter real geometry, then keep moving within the same tile: only one entry
  // effect is allowed, while the connection painter updates each frame.
  final geometry = controller.geometry;
  if (geometry == null) return;
  final origin = geometry.centers.values.first;
  controller.down(1, origin);
  for (var i = 0; i < 240; i++) {
    controller.move(
      1,
      origin + Offset(math.sin(i * .12) * 15, math.cos(i * .12) * 15),
    );
    await Future<void>.delayed(const Duration(milliseconds: 16));
  }
  controller.cancelGesture();
  await Future<void>.delayed(const Duration(milliseconds: 500));
  WidgetsBinding.instance.removeTimingsCallback(record);
  double percentile(List<double> values, double q) {
    values.sort();
    return values.isEmpty ? 0 : values[((values.length - 1) * q).round()];
  }

  final build = frames
      .map((f) => f.buildDuration.inMicroseconds / 1000)
      .toList();
  final raster = frames
      .map((f) => f.rasterDuration.inMicroseconds / 1000)
      .toList();
  final result = {
    'mode': 'profile',
    'frames': frames.length,
    'moves': 240,
    'buildP95Ms': percentile(build, .95),
    'rasterP95Ms': percentile(raster, .95),
    'buildOver16_7ms': build.where((v) => v > 16.7).length,
    'rasterOver16_7ms': raster.where((v) => v > 16.7).length,
  };
  final output = File(
    path.join(await getDatabasesPath(), 'stage5_profile.json'),
  );
  await output.parent.create(recursive: true);
  await output.writeAsString(jsonEncode(result), flush: true);
  debugPrint('STAGE5_PROFILE ${jsonEncode(result)}');
}
