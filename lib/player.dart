import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show Icons, Scaffold;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key, required this.type});

  final String type;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with WidgetsBindingObserver {
  late final player = Player();
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
        return AccentColor.lerp(
          Colors.red,
          AccentColor.swatch(const <String, Color>{
            'darkest': Colors.white,
            'darker':  Colors.white,
            'dark':  Colors.white,
            'normal':  Colors.white,
            'light':  Colors.white,
            'lighter':  Colors.white,
            'lightest':  Colors.white,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.width * 9.0 / 16.0,
          child: MaterialDesktopVideoControlsTheme(
            normal: MaterialDesktopVideoControlsThemeData(
              seekBarThumbColor: getAccentColor().light,
              seekBarPositionColor: getAccentColor().lighter,
              toggleFullscreenOnDoublePress: false,
              topButtonBar: [
                MaterialDesktopCustomButton(
                  onPressed: () => Navigator.of(context).pop(),
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
                  onPressed: () => exit(0),
                  icon: const Icon(Icons.close),
                ),
              ],
              bottomButtonBar: [
                MaterialDesktopPlayOrPauseButton(
                  iconColor: getAccentColor().lighter,
                ),
                MaterialDesktopPositionIndicator(),
                Spacer(),
                MaterialDesktopCustomButton(
                  icon: const Icon(Icons.file_download_outlined),
                  iconSize: 24.0,
                  onPressed: () {
                    debugPrint('save');
                  },
                ),
                MaterialDesktopCustomButton(
                  icon: const Icon(Icons.file_upload_outlined),
                  iconSize: 24.0,
                  onPressed: () {
                    debugPrint('load');
                  },
                ),
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