import 'dart:io' show Platform, exit;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' hide Colors, showDialog, ButtonStyle;
import 'package:system_theme/system_theme.dart';
import 'package:media_kit/media_kit.dart';                      // Provides [Player], [Media], [Playlist] etc.
import 'package:media_kit_video/media_kit_video.dart';          // Provides [VideoController] & [Video] etc.
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await windowManager.ensureInitialized();

  if (Platform.isWindows) {
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 720),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
      await windowManager.setAspectRatio(16 / 9);
      await windowManager.setMinimumSize(const Size(640, 360));
    });
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return FluentApp(
      title: 'Steins Player',
      theme: FluentThemeData(
        brightness: Brightness.dark,
        accentColor: AccentColor.swatch({
          'darkest': SystemTheme.accentColor.darkest,
          'darker': SystemTheme.accentColor.darker,
          'dark': SystemTheme.accentColor.dark,
          'normal': SystemTheme.accentColor.accent,
          'light': SystemTheme.accentColor.light,
          'lighter': SystemTheme.accentColor.lighter,
          'lightest': SystemTheme.accentColor.lightest,
        }),
      ),
      home: const MyHomePage(type: "anon"),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.type});

  final String type;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  // Create a [Player] to control playback.
  late final player = Player();
  // Create a [VideoController] to handle video output from [Player].
  late final controller = VideoController(player);

  late final ValueNotifier<String> selectedSpeedNotifier;
  final List<String> speedOptions = ['0.5x', '1.0x', '1.5x', '2.0x'];
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    selectedSpeedNotifier = ValueNotifier(speedOptions[1]);
    player.open(Media('asset:///res/${widget.type}/segments/1.mp4'));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    selectedSpeedNotifier.dispose();
    player.dispose();
    super.dispose();
  }

  AccentColor getAccentColor() {
    switch (widget.type) {
      case "anon":
        return Colors.magenta;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.width * 9.0 / 16.0,
          // Use [Video] widget to display video output.
          child: MaterialDesktopVideoControlsTheme(
            normal: MaterialDesktopVideoControlsThemeData(
              // Modify theme options:
              seekBarThumbColor: getAccentColor().light,
              seekBarPositionColor: getAccentColor().lighter,
              toggleFullscreenOnDoublePress: false,
              
              // Modify top button bar:
              topButtonBar: [
                MaterialDesktopCustomButton(
                  onPressed: () {
                    debugPrint('Return button pressed. TODO: return to home page.');
                  },
                  icon: const Icon(Icons.west),
                ),
                Expanded(
                  child: DragToMoveArea(
                    child: Container(
                      color: Colors.transparent,
                    ),
                  ),
                ),
                MaterialDesktopCustomButton(
                  onPressed: () {
                    exit(0);
                  },
                  icon: const Icon(Icons.close),
                ),
              ],
              // Modify bottom button bar:
              bottomButtonBar: [
                MaterialDesktopPlayOrPauseButton(
                  iconColor: getAccentColor().lighter,
                ),
                MaterialDesktopPositionIndicator(),
                Spacer(),
                MaterialDesktopCustomButton(
                  icon: ValueListenableBuilder<String>(
                    valueListenable: selectedSpeedNotifier,
                    builder: (context, speed, child) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            height: 24.0,
                            alignment: Alignment.topCenter,
                            child: Text(
                              speed,
                              style: TextStyle(
                                color: getAccentColor().lighter,
                                fontSize: 14.0,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  iconSize: 24.0,
                  onPressed: () {
                    final currentIndex =
                        speedOptions.indexOf(selectedSpeedNotifier.value);
                    final nextIndex = (currentIndex + 1) % speedOptions.length;
                    selectedSpeedNotifier.value = speedOptions[nextIndex];
                    player.setRate(double.parse(
                      selectedSpeedNotifier.value.replaceAll('x', ''),
                    ));
                  },
                ),
                MaterialDesktopVolumeButton(),
              ],
            ),
            fullscreen: const MaterialDesktopVideoControlsThemeData(),
            child: Scaffold(
              body: Video(
                wakelock: false,
                controller: controller,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
