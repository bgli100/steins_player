import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:system_theme/system_theme.dart';
import 'package:window_manager/window_manager.dart';

class Utils {
  static AccentColor systemAccentColor() {
    if (Platform.isWindows) {
      return AccentColor.swatch({
        'darkest': SystemTheme.accentColor.darkest,
        'darker': SystemTheme.accentColor.darker,
        'dark': SystemTheme.accentColor.dark,
        'normal': SystemTheme.accentColor.accent,
        'light': SystemTheme.accentColor.light,
        'lighter': SystemTheme.accentColor.lighter,
        'lightest': SystemTheme.accentColor.lightest,
      });
    }
    return Colors.blue;
  }

  static void exitApp() {
    if (Platform.isWindows) {
      exit(0);
    } else {
      SystemNavigator.pop();
    }
  }

  /// `window_manager` implements desktop platforms only, so drag-to-move is a
  /// no-op elsewhere.
  static Widget dragToMoveArea({required Widget child}) {
    if (Platform.isWindows) {
      return DragToMoveArea(child: child);
    }
    return child;
  }

  /// Insets of the system UI (status bar, display cutout, gesture bar) that
  /// content must avoid on mobile. Desktops have none.
  static EdgeInsets systemInsets(BuildContext context) {
    if (Platform.isWindows) {
      return EdgeInsets.zero;
    }
    return MediaQuery.viewPaddingOf(context);
  }

  /// Background videos fill the whole screen on mobile for immersion. The
  /// Windows window is 16:9 like the videos, so `contain` keeps it unchanged.
  static BoxFit get backgroundVideoFit =>
      Platform.isWindows ? BoxFit.contain : BoxFit.cover;

  /// `media_kit` resolves `asset://` URIs itself, but its OHOS path resolution
  /// is broken, so the asset is unpacked from the bundle to a local file there.
  static Future<String> mediaUri(String key) async {
    if (Platform.operatingSystem != 'ohos') {
      return 'asset:///$key';
    }
    final directory = await getTemporaryDirectory();
    final file = File(
      p.join(directory.path, 'flutter_media', key.replaceAll('/', '_')),
    );
    final data = await rootBundle.load(key);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    return file.path;
  }

  static AccentColor getAccentColorForType(String type) {
    switch (type) {
      case "anon":
        return AccentColor.lerp(
          Colors.red,
          AccentColor.swatch(const <String, Color>{
            'darkest': Colors.white,
            'darker': Colors.white,
            'dark': Colors.white,
            'normal': Colors.white,
            'light': Colors.white,
            'lighter': Colors.white,
            'lightest': Colors.white,
          }),
          0.5,
        );
      case "soyo":
        return Colors.orange;
      case "sakiko":
        return Colors.blue;
      case "tomori":
        return AccentColor.swatch(const <String, Color>{
          'darkest': Color(0xFF11100F),
          'darker': Color(0xFF201F1E),
          'dark': Color(0xFF323130),
          'normal': Color(0xFF605E5C),
          'light': Color(0xFF979593),
          'lighter': Color(0xFFBEBBB8),
          'lightest': Color(0xFFE1DFDD),
        });
      case "mutsumi":
      default:
        return Colors.green;
    }
  }

  static Widget buildTopButtonBar(
    BuildContext context, {
    required bool showBack,
  }) {
    final insets = systemInsets(context);
    return Padding(
      padding: EdgeInsets.only(
        left: insets.left,
        top: insets.top,
        right: insets.right,
      ),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        decoration: BoxDecoration(color: Colors.transparent),
        foregroundDecoration: BoxDecoration(color: Colors.transparent),
        child: Row(
          children: [
            if (showBack)
              IconButton(
                icon: const Icon(Icons.west, color: Colors.white),
                style: ButtonStyle(
                  iconSize: WidgetStatePropertyAll<double>(28.0),
                ),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            Expanded(
              child: dragToMoveArea(
                child: Container(color: Colors.transparent),
              ),
            ),
            if (Platform.isWindows)
              IconButton(
                icon: const Icon(Icons.close),
                style: ButtonStyle(
                  iconSize: WidgetStatePropertyAll<double>(28.0),
                ),
                onPressed: () => exitApp(),
              ),
          ],
        ),
      ),
    );
  }
}
