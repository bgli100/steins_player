import 'dart:async';
import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show Icons, Scaffold;
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:file_selector/file_selector.dart';
import 'package:media_kit_video/media_kit_video_controls/src/controls/extensions/duration.dart';
import 'package:window_manager/window_manager.dart';
import 'package:intl/intl.dart';

import 'signup.dart';
import 'utils.dart';
import 'steins.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key, required this.type});

  final String type;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with WidgetsBindingObserver {
  late final _player = Player();
  late final _controller = VideoController(_player);
  late final StreamSubscription<bool> _completedSubscription;
  late final Steins steins;
  late int pos;
  late int cid;
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
  late final ValueNotifier<String> usernameNotifier;
  final List<String> speedOptions = ['0.5x', '1.0x', '1.5x', '2.0x'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    selectedSpeedNotifier = ValueNotifier(speedOptions[1]);
    usernameNotifier = ValueNotifier(Signup.currentUsername);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initPlayer();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    selectedSpeedNotifier.dispose();
    fullyLoadedNotifier.dispose();
    usernameNotifier.dispose();
    _completedSubscription.cancel();
    _player.dispose();
    super.dispose();
  }

  AccentColor getAccentColor() {
    return Utils.getAccentColorForType(widget.type);
  }

  Future<void> _initPlayer() async {
    steins = await Steins.create(widget.type);
    final state = steins.proceed(null);
    if (state != null) _updateState(state);
    await _player.open(
      Media('asset:///res/works/${widget.type}/segments/$cid.mp4'),
    );
    _completedSubscription = _player.stream.completed.listen((completed) {
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
      if (entry.key != 'pos' &&
          entry.key != 'title' &&
          entry.key != 'cid' &&
          entry.value != null) {
        choices[entry.key] = entry.value.toString();
      }
    }

    pos = state['pos'] ?? 1;
    cid = state['cid'] ?? 1;
    title = state['title'] ?? '';

    debugPrint('pos: $pos, cid: $cid, title: "$title", choices: $choices');

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
    if (state == null) {
      debugPrint('No more segments to play. Ending game.');
      return;
    }
    _updateState(state);
    await _player.open(
      Media('asset:///res/works/${widget.type}/segments/$cid.mp4'),
    );
  }

  String _defaultSaveFileName() {
    final safeTitle = title.isEmpty
        ? 'state'
        : title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final timestamp = DateFormat(
      'yyyy年MM月dd日HH时mm分ss秒',
    ).format(DateTime.now()).replaceAll(RegExp(r'[:.]'), '');
    return '${widget.type}_${timestamp}_节点$safeTitle.json';
  }

  Future<void> _saveGame() async {
    final suggestedName = _defaultSaveFileName();
    await _player.pause();
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
    await _player.open(
      Media('asset:///res/works/${widget.type}/segments/$cid.mp4'),
    );
    debugPrint('Loaded game from: ${file.path}');
  }

  void _onVideoCompleted() {
    if (_currentChoiceOptions.isNotEmpty) {
      setState(() {
        debugPrint('Video completed, showing choices: $_currentChoiceOptions');
        _showChoiceOverlay = true;
      });
    } else {
      debugPrint('Video completed, proceeding to next segment');
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

  Widget _buildTopBar() {
    return Stack(
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
        Row(
          children: [
            MaterialDesktopCustomButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.west, color: getAccentColor().lighter),
            ),
            ValueListenableBuilder<String>(
              valueListenable: usernameNotifier,
              builder: (context, value, child) {
                return Text("用户: ${Signup.currentUsername}", style: textStyle);
              },
            ),
            MaterialDesktopCustomButton(
              icon: Icon(Icons.edit, color: getAccentColor().lighter, size: 24),
              onPressed: () => Signup.showSignupDialog(context),
            ),
            Expanded(
              child: DragToMoveArea(
                child: Container(color: Colors.transparent),
              ),
            ),
            MaterialDesktopCustomButton(
              onPressed: () => exit(0),
              icon: Icon(Icons.close, color: getAccentColor().lighter),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChoiceOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: .25),
        child: Column(
          children: [
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              decoration: BoxDecoration(color: Colors.transparent),
              child: _buildTopBar(),
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

  VideoController controller(BuildContext context) =>
      VideoStateInheritedWidget.of(context).state.widget.controller;

  Map<ShortcutActivator, VoidCallback> keyboardShortcuts(BuildContext context) {
    return {
      const SingleActivator(LogicalKeyboardKey.mediaPlay): () => _player.play(),
      const SingleActivator(LogicalKeyboardKey.mediaPause): () =>
          _player.pause(),
      const SingleActivator(LogicalKeyboardKey.mediaPlayPause): () =>
          _player.playOrPause(),
      const SingleActivator(LogicalKeyboardKey.space): () =>
          _player.playOrPause(),
      const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
        final rate = _player.state.position - const Duration(seconds: 5);
        _player.seek(rate.clamp(Duration.zero, _player.state.duration));
      },
      const SingleActivator(LogicalKeyboardKey.arrowRight): () {
        final rate = _player.state.position + const Duration(seconds: 5);
        _player.seek(rate.clamp(Duration.zero, _player.state.duration));
      },
      const SingleActivator(LogicalKeyboardKey.arrowUp): () {
        final volume = _player.state.volume + 5.0;
        _player.setVolume(volume.clamp(0.0, 100.0));
      },
      const SingleActivator(LogicalKeyboardKey.arrowDown): () {
        final volume = _player.state.volume - 5.0;
        _player.setVolume(volume.clamp(0.0, 100.0));
      },
    };
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
              keyboardShortcuts: keyboardShortcuts(context),
              seekBarThumbColor: getAccentColor().light,
              seekBarPositionColor: getAccentColor().lighter,
              toggleFullscreenOnDoublePress: false,
              topButtonBar: [Expanded(child: _buildTopBar())],
              bottomButtonBar: [
                MaterialDesktopPlayOrPauseButton(
                  iconColor: getAccentColor().lighter,
                ),
                MaterialDesktopPositionIndicator(style: textStyle),
                Spacer(),
                Tooltip(
                  message: '保存游戏',
                  useMousePosition: false,
                  style: TooltipThemeData(textStyle: textStyle),
                  child: MaterialDesktopCustomButton(
                    icon: Icon(
                      Icons.file_download_outlined,
                      color: getAccentColor().lighter,
                    ),
                    iconSize: 24.0,
                    onPressed: _saveGame,
                  ),
                ),
                Tooltip(
                  message: '加载存档',
                  useMousePosition: false,
                  style: TooltipThemeData(textStyle: textStyle),
                  child: MaterialDesktopCustomButton(
                    icon: Icon(
                      Icons.file_upload_outlined,
                      color: getAccentColor().lighter,
                    ),
                    iconSize: 24.0,
                    onPressed: _loadGame,
                  ),
                ),
                Spacer(),
                MaterialDesktopCustomButton(
                  icon: ValueListenableBuilder<String>(
                    valueListenable: selectedSpeedNotifier,
                    builder: (context, speed, child) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            height: 24.0,
                            alignment: Alignment.center,
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
                    _player.setRate(
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
                  Video(wakelock: false, controller: _controller),
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
