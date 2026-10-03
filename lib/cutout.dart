import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The camera cut-out reported by the platform.
///
/// Only Android reports it as a rectangle; HarmonyOS does not report the punch
/// hole at all, in which case [rects] stays empty.
class DisplayCutOut {
  static const MethodChannel _channel = MethodChannel('lullaby/display_cutout');

  /// Cut-out rectangles in logical pixels, relative to the app window.
  static List<Rect> rects = const [];

  /// Whether a cut-out overlaps [region].
  static bool overlaps(Rect region) =>
      rects.any((rect) => rect.overlaps(region));

  /// Whether a cut-out sits over the bottom-right corner of [screen], where the
  /// about entry button is placed.
  static bool blocksBottomRight(Size screen, {double zone = 96}) => overlaps(
    Rect.fromLTRB(
      screen.width - zone,
      screen.height - zone,
      screen.width,
      screen.height,
    ),
  );

  /// Re-reads the cut-out from the platform. Cheap enough to be called
  /// whenever the window metrics change.
  static Future<void> refresh() async {
    if (Platform.isWindows) {
      rects = const [];
      return;
    }
    try {
      final result = await _channel.invokeListMethod<List<dynamic>>(
        'getCutoutRects',
      );
      rects = [
        for (final rect in result ?? const <List<dynamic>>[])
          if (rect.length == 4)
            Rect.fromLTRB(
              (rect[0] as num).toDouble(),
              (rect[1] as num).toDouble(),
              (rect[2] as num).toDouble(),
              (rect[3] as num).toDouble(),
            ),
      ];
      if (kDebugMode) debugPrint('Display cut-out: $rects');
    } on PlatformException catch (error) {
      debugPrint('Display cut-out query failed: $error');
      rects = const [];
    } on MissingPluginException {
      rects = const [];
    }
  }
}
