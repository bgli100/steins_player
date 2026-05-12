import 'dart:async';
import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show Icons, Scaffold;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:file_selector/file_selector.dart';
import 'package:window_manager/window_manager.dart';

import 'utils.dart';
import 'steins.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key, required this.type});

  final String type;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with WidgetsBindingObserver {
  late final player = Player();
  late final controller = VideoController(player);
  late final StreamSubscription<bool> _completedSubscription;
  late final Steins steins;
  late int pos;
  late String title;
  TextStyle get textStyle => TextStyle(
    color: getAccentColor().lighter,
    fontSize: 14,
    fontFamily: "Microsoft YaHei UI",
  );

  late Map<String, String> _currentChoiceOptions = {};
  bool _showChoiceOverlay = false;

  late final ValueNotifier<String> selectedSpeedNotifier;
  late final ValueNotifier<bool> fullyLoadedNotifier = ValueNotifier(false);
  final List<String> speedOptions = ['0.5x', '1.0x', '1.5x', '2.0x'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    selectedSpeedNotifier = ValueNotifier(speedOptions[1]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initPlayer();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    selectedSpeedNotifier.dispose();
    fullyLoadedNotifier.dispose();
    _completedSubscription.cancel();
    player.dispose();
    super.dispose();
  }

  AccentColor getAccentColor() {
    return Utils.getAccentColorForType(widget.type);
  }

  Future<void> _initPlayer() async {
    steins = await Steins.create(widget.type);
    final state = steins.proceed(null);
    _updateState(state);
    await player.open(Media('asset:///res/${widget.type}/segments/$pos.mp4'));
    _completedSubscription = player.stream.completed.listen((completed) {
      if (completed) {
        _onVideoCompleted();
      }
    });

    setState(() {
      fullyLoadedNotifier.value = true;
    });
  }

  void _updateState(Map<String, dynamic> state) {
    final choices = <String, String>{};
    for (final entry in state.entries) {
      if (entry.key != 'pos' && entry.key != 'title' && entry.value != null) {
        choices[entry.key] = entry.value.toString();
      }
    }

    pos = state['pos'] ?? 1;
    title = state['title'] ?? '';

    debugPrint('pos: $pos, title: "$title", choices: $choices');

    setState(() {
      _currentChoiceOptions = choices;
      _showChoiceOverlay = false;
    });
  }

  Future<void> _onChoiceSelected(String letter) async {
    setState(() {
      _showChoiceOverlay = false;
    });
    await _proceedAndLoad(letter);
  }

  Future<void> _proceedAndLoad(String? actionLetter) async {
    debugPrint('selected action: $actionLetter');
    final state = steins.proceed(actionLetter);
    _updateState(state);
    await player.open(Media('asset:///res/${widget.type}/segments/$pos.mp4'));
  }

  String _defaultSaveFileName() {
    final safeTitle = title.isEmpty
        ? 'state'
        : title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final timestamp = DateTime.now().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '',
    );
    return '${widget.type}-$timestamp-$safeTitle.json';
  }

  Future<void> _saveGame() async {
    final suggestedName = _defaultSaveFileName();
    await player.pause();
    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: [
        XTypeGroup(label: 'JSON', extensions: ['json']),
      ],
    );
    if (location == null) {
      return;
    }
    await steins.save(location.path);
    debugPrint('Saved game to: ${location.path}');
  }

  Future<void> _loadGame() async {
    final files = await openFiles(
      acceptedTypeGroups: [
        XTypeGroup(label: 'JSON', extensions: ['json']),
      ],
    );
    if (files.isEmpty) {
      return;
    }
    final file = files.first;
    final state = await steins.load(file.path);
    if (state == null) {
      debugPrint('Failed to load game: ${file.path}');
      return;
    }
    _updateState(state);
    await player.open(Media('asset:///res/${widget.type}/segments/$pos.mp4'));
    debugPrint('Loaded game from: ${file.path}');
  }

  void _onVideoCompleted() {
    if (_currentChoiceOptions.isNotEmpty) {
      setState(() {
        _showChoiceOverlay = true;
      });
    } else {
      _proceedAndLoad(null);
    }
  }

  List<Widget> _buildVisibleVarButtons() {
    final visible = steins.visiableVars();
    debugPrint('visible vars: $visible');
    return visible.entries.map((entry) {
      final name = entry.value['name']?.toString() ?? entry.key;
      final value = entry.value['value']?.toString() ?? '';
      return MaterialDesktopCustomButton(
        onPressed: () {},
        iconSize: 1.0,
        icon: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(name, textAlign: TextAlign.center, style: textStyle),
            Text(value, textAlign: TextAlign.center, style: textStyle),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildChoiceOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: .25),
        child: Column(
          children: [
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              decoration: BoxDecoration(color: Colors.transparent),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.west, color: getAccentColor().lighter),
                    style: ButtonStyle(
                      iconSize: WidgetStatePropertyAll<double>(28.0),
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        ValueListenableBuilder<bool>(
                          valueListenable: fullyLoadedNotifier,
                          builder: (context, value, child) {
                            if (!value) return Row(children: []);
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: _buildVisibleVarButtons(),
                            );
                          },
                        ),
                        Positioned.fill(
                          child: DragToMoveArea(
                            child: Container(color: Colors.transparent),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: getAccentColor().lighter),
                    style: ButtonStyle(
                      iconSize: WidgetStatePropertyAll<double>(28.0),
                    ),
                    onPressed: () => exit(0),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 24.0,
              ),
              child: Row(
                children: List.generate(4, (index) {
                  final letter = String.fromCharCode(65 + index);
                  final text = _currentChoiceOptions[letter];
                  if (text == null) {
                    return const Expanded(child: SizedBox());
                  }
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: FilledButton(
                        style: ButtonStyle(
                          backgroundColor: WidgetStatePropertyAll<Color>(
                            getAccentColor().lightest,
                          ),
                        ),
                        onPressed: () async {
                          await _onChoiceSelected(letter);
                        },

                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              letter,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontFamily: "Microsoft YaHei UI",
                              ),
                            ),
                            Text(
                              text,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black,
                                fontFamily: "Microsoft YaHei UI",
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
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
                  icon: Icon(Icons.west, color: getAccentColor().lighter),
                ),
                Expanded(
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      ValueListenableBuilder<bool>(
                        valueListenable: fullyLoadedNotifier,
                        builder: (context, value, child) {
                          if (!value) return Row(children: []);
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: _buildVisibleVarButtons(),
                          );
                        },
                      ),
                      Positioned.fill(
                        child: DragToMoveArea(
                          child: Container(color: Colors.transparent),
                        ),
                      ),
                    ],
                  ),
                ),
                MaterialDesktopCustomButton(
                  onPressed: () => exit(0),
                  icon: Icon(Icons.close, color: getAccentColor().lighter),
                ),
              ],
              bottomButtonBar: [
                MaterialDesktopPlayOrPauseButton(
                  iconColor: getAccentColor().lighter,
                ),
                MaterialDesktopPositionIndicator(style: textStyle),
                Spacer(),
                MaterialDesktopCustomButton(
                  icon: Icon(
                    Icons.file_download_outlined,
                    color: getAccentColor().lighter,
                  ),
                  iconSize: 24.0,
                  onPressed: _saveGame,
                ),
                MaterialDesktopCustomButton(
                  icon: Icon(
                    Icons.file_upload_outlined,
                    color: getAccentColor().lighter,
                  ),
                  iconSize: 24.0,
                  onPressed: _loadGame,
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
                            child: Text(speed, style: textStyle),
                          ),
                        ],
                      );
                    },
                  ),
                  iconSize: 24.0,
                  onPressed: () {
                    final currentIndex = speedOptions.indexOf(
                      selectedSpeedNotifier.value,
                    );
                    final nextIndex = (currentIndex + 1) % speedOptions.length;
                    selectedSpeedNotifier.value = speedOptions[nextIndex];
                    player.setRate(
                      double.parse(
                        selectedSpeedNotifier.value.replaceAll('x', ''),
                      ),
                    );
                  },
                ),
                MaterialDesktopVolumeButton(
                  iconColor: getAccentColor().lighter,
                ),
              ],
            ),
            fullscreen: const MaterialDesktopVideoControlsThemeData(),
            child: Scaffold(
              body: Stack(
                children: [
                  Video(wakelock: false, controller: controller),
                  if (_showChoiceOverlay) _buildChoiceOverlay(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
