import 'package:flutter_test/flutter_test.dart';
import 'package:caca_palavra/features/game/presentation/wheel_gesture.dart';

void main() {
  test(
    'geometry uses uniform circle, independent IDs and >=48px touch targets',
    () {
      final geometry = WheelGeometry(224, ['A1', 'C', 'A2', 'O']);
      expect(geometry.tileRadius * 2, greaterThanOrEqualTo(48));
      expect(geometry.hit(geometry.centers['A1']!), 'A1');
      expect(geometry.centers['A1'], isNot(geometry.centers['A2']));
      expect(geometry.hit(const Offset(112, 112)), isNull);
    },
  );

  test(
    'undo, selected non-previous tile, repeated move and distinct A IDs',
    () {
      final geo = WheelGeometry(300, ['A1', 'C', 'A2', 'O']);
      final gesture = WheelGesture();
      gesture.down(1, geo.centers['A1']!, geo);
      for (final id in ['C', 'A2', 'O']) {
        gesture.move(1, geo.centers[id]!, geo);
      }
      expect(gesture.selected, ['A1', 'C', 'A2', 'O']);
      gesture.move(1, geo.centers['O']!, geo);
      expect(gesture.selected.length, 4);
      gesture.move(1, geo.centers['A1']!, geo);
      expect(gesture.selected.length, 4);
      gesture.move(1, geo.centers['O']!, geo);
      gesture.move(1, geo.centers['A2']!, geo);
      expect(gesture.selected, ['A1', 'C', 'A2']);
      gesture.move(1, geo.centers['C']!, geo);
      expect(gesture.selected, ['A1', 'C']);
      gesture.move(1, geo.centers['A1']!, geo);
      expect(gesture.selected, ['A1']);
      expect(gesture.up(1), ['A1']);
      expect(gesture.up(1), isNull);
    },
  );

  test('a fast segment detects intermediate entries in traversal order', () {
    final geo = WheelGeometry(300, ['G', 'A', 'T', 'O']);
    final gesture = WheelGesture();
    gesture.down(1, geo.centers['G']!, geo);
    gesture.move(1, geo.centers['O']! + const Offset(-80, 0), geo);
    // Outside-to-outside across O, center and A must encounter both O and A.
    gesture.move(1, geo.centers['A']! + const Offset(80, 0), geo);
    expect(gesture.selected, ['G', 'O', 'A']);
  });

  test('secondary pointer, outside down, release outside and cancellation', () {
    final geo = WheelGeometry(300, ['G', 'A', 'T', 'O']);
    final gesture = WheelGesture();
    expect(gesture.down(1, const Offset(150, 150), geo), isFalse);
    gesture.down(1, geo.centers['G']!, geo);
    expect(gesture.down(2, geo.centers['O']!, geo), isFalse);
    expect(gesture.move(2, geo.centers['T']!, geo), isFalse);
    expect(gesture.up(2), isNull);
    gesture.move(1, geo.centers['A']!, geo);
    gesture.move(1, const Offset(500, 500), geo);
    expect(gesture.up(1), ['G', 'A']);
    gesture.down(1, geo.centers['G']!, geo);
    expect(gesture.cancel(), isTrue);
    expect(gesture.up(1), isNull);
  });
}
