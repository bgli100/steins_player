import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:steins_player/cutout.dart';

void main() {
  // A phone in landscape (HarmonyOS Mate 80 Pro Max measurements).
  const screen = Size(843.9, 391.1);

  tearDown(() => DisplayCutOut.rects = const []);

  test('no cut-out keeps the entry button in the bottom-right corner', () {
    expect(DisplayCutOut.blocksBottomRight(screen), isFalse);
  });

  test('a cut-out in the middle of the right edge keeps it bottom-right', () {
    // Xiaomi 17 Ultra: 48 dp wide, 22.7 dp tall, vertically centred.
    DisplayCutOut.rects = const [Rect.fromLTRB(795.9, 188.7, 843.9, 211.3)];
    expect(DisplayCutOut.blocksBottomRight(screen), isFalse);
  });

  test('a cut-out over the bottom-right corner moves the entry button', () {
    DisplayCutOut.rects = const [Rect.fromLTRB(795.9, 320, 843.9, 391.1)];
    expect(DisplayCutOut.blocksBottomRight(screen), isTrue);
  });

  test('a cut-out over the top-right corner keeps it bottom-right', () {
    DisplayCutOut.rects = const [Rect.fromLTRB(795.9, 0, 843.9, 40)];
    expect(DisplayCutOut.blocksBottomRight(screen), isFalse);
  });
}
