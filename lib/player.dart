import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show Icons, Scaffold;
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:file_picker_ohos/file_picker_ohos.dart';
import 'package:media_kit_video/media_kit_video_controls/src/controls/extensions/duration.dart';
import 'package:window_manager/window_manager.dart';
import 'package:intl/intl.dart';

import 'device.dart';
import 'segment_watchdog.dart';
import 'signup.dart';
import 'utils.dart';
import 'steins.dart';

/// An empty stand-in for `media_kit`'s video controls.
///
/// `NoVideoControls` cannot be used to take the controls away again: it is the
/// `null` constant and `VideoViewParameters.copyWith` keeps the previous value
/// whenever the new one is `null`, so the *old* builder stays mounted and the
/// controls keep drawing over the choice and ending overlays until their own
/// auto-hide kicks in. Passing a real builder removes them.
Widget _withoutVideoControls(VideoState state) => const SizedBox.shrink();

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key, required this.type});

  final String type;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with WidgetsBindingObserver {
  late final _player = Player();
  // Emulators that spoof a real phone get no usable picture out of MediaCodec's
  // zero copy output (black video while playback runs fine), so they decode in
  // software instead. Real devices keep hardware acceleration.
  late final _controller = VideoController(
    _player,
    configuration: VideoControllerConfiguration(
      enableHardwareAcceleration: !Device.isEmulator,
    ),
  );
  StreamSubscription<bool>? _completedSubscription;
  late final Steins steins;
  int pos = 1;
  late int cid;
  String title = '';
  TextStyle get textStyle => TextStyle(
    color: getAccentColor().lighter,
    fontSize: 14,
    fontFamily: "Microsoft YaHei UI",
  );

  late Map<String, String> _currentChoiceOptions = {};
  bool _showChoiceOverlay = false;
  bool _storyEnded = false;
  bool _playingBeforeBackground = false;

  /// Set while a segment completion is being handled, so the `completed` event
  /// and the stall watchdog cannot settle the same segment twice.
  bool _settling = false;
  bool _disposed = false;

  /// Polls the player for progress: `media_kit`/mpv can end up "playing" while
  /// nothing advances (a decoder that stops feeding frames), which would leave
  /// the game waiting for a completion that never arrives.
  Timer? _watchdog;
  final SegmentWatchdog _stallDetector = SegmentWatchdog();

  /// Top bar geometry of the player chrome, shared by the video controls and
  /// the choice/ending overlays so the back button never moves.
  static const double _topBarHeight = 56.0;
  static const double _mobileTopBarMargin = 40.0;

  late final ValueNotifier<String> selectedSpeedNotifier;
  late final ValueNotifier<bool> fullyLoadedNotifier = ValueNotifier(false);
  late final ValueNotifier<String> usernameNotifier;
  late final ValueNotifier<bool> isFullscreenNotifier = ValueNotifier(
    Platform.isAndroid,
  );
  final List<String> speedOptions = ['0.5x', '1.0x', '1.5x', '2.0x'];
  static const MethodChannel _saveFileChannel = MethodChannel(
    'lullaby/save_file',
  );

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
    _disposed = true;
    _watchdog?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    selectedSpeedNotifier.dispose();
    fullyLoadedNotifier.dispose();
    usernameNotifier.dispose();
    isFullscreenNotifier.dispose();
    // Both may be null/absent when the page is left before the player finished
    // starting; skipping them used to leak the whole player (and its decoder).
    _completedSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  /// The video output is torn down while the app is in the background, so a
  /// playing video has to be restarted when the app comes back.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _playingBeforeBackground = _player.state.playing;
    } else if (state == AppLifecycleState.resumed && _playingBeforeBackground) {
      _playingBeforeBackground = false;
      _player.play();
    }
  }

  AccentColor getAccentColor() {
    return Utils.getAccentColorForType(widget.type);
  }

  Future<void> _initPlayer() async {
    steins = await Steins.create(widget.type);
    if (_disposed) return;
    final state = steins.currentState();
    await _applyState(state);
    _completedSubscription = _player.stream.completed.listen((completed) {
      if (completed) _onVideoCompleted();
    });
    _watchdog ??= Timer.periodic(
      _stallDetector.interval,
      (_) => _onWatchdogTick(),
    );
    debugPrint('device: emulator=${Device.isEmulator}');
    if (!_disposed) {
      setState(() {
        fullyLoadedNotifier.value = true;
      });
    }
  }

  /// Applies a story state and starts its segment.
  Future<void> _applyState(Map<String, dynamic>? state) async {
    if (state == null || _disposed) {
      return;
    }
    _updateState(state);
    await _openCurrentSegment();
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
      _storyEnded = false;
    });
  }

  /// Opens the segment the story is currently on.
  ///
  /// [retry] marks this as the watchdog's recovery attempt, which keeps the
  /// detector from reloading the same segment again and again.
  Future<void> _openCurrentSegment({bool play = true, bool retry = false}) async {
    _stallDetector.reset(retry: retry);
    final uri = await Utils.mediaUri(
      'res/works/${widget.type}/segments/$cid.mp4',
    );
    if (_disposed) return;
    debugPrint('opening segment $cid of "$title"');
    try {
      await _player.open(Media(uri), play: play);
    } catch (error) {
      debugPrint('failed to open segment $cid: $error');
    }
  }

  /// Settles a segment exactly once, no matter whether the completion came from
  /// `media_kit` or from the stall watchdog.
  Future<void> _onVideoCompleted() async {
    if (_settling || _disposed) return;
    _settling = true;
    try {
      if (_currentChoiceOptions.isNotEmpty) {
        debugPrint('Video completed, showing choices: $_currentChoiceOptions');
        if (!_disposed) {
          setState(() {
            _showChoiceOverlay = true;
          });
        }
        return;
      }
      debugPrint('Video completed, proceeding to next segment');
      await _proceedAndLoad(null);
    } finally {
      _settling = false;
    }
  }

  Future<void> _onChoiceSelected(String letter) async {
    if (_settling || _disposed) return;
    _settling = true;
    try {
      setState(() {
        _showChoiceOverlay = false;
      });
      await _proceedAndLoad(letter);
    } finally {
      _settling = false;
    }
  }

  Future<void> _proceedAndLoad(String? actionLetter) async {
    debugPrint('selected action: $actionLetter');
    final state = steins.proceed(actionLetter);
    if (state == null) {
      debugPrint('No more segments to play. Ending game.');
      if (!_disposed) {
        setState(() {
          _storyEnded = true;
        });
      }
      return;
    }
    await _applyState(state);
  }

  /// Detects a standstill: mpv reporting playback while the position does not
  /// move. Near the end of the segment that means the completion event was
  /// lost, so the game is settled here; elsewhere it means the pipeline died,
  /// which a seek (or, if that fails, reloading the segment) recovers from.
  void _onWatchdogTick() {
    if (_disposed || _settling || _storyEnded || _showChoiceOverlay) return;
    final state = _player.state;
    final action = _stallDetector.tick(
      position: state.position,
      duration: state.duration,
      playing: state.playing,
      buffering: state.buffering,
    );
    switch (action) {
      case StallAction.none:
        return;
      case StallAction.settle:
        debugPrint(
          'watchdog: playback stopped at ${state.position} / ${state.duration}, '
          'settling as completed',
        );
        _onVideoCompleted();
      case StallAction.seek:
        debugPrint(
          'watchdog: playback stalled at ${state.position} / ${state.duration}, '
          'seeking',
        );
        _player.seek(state.position);
      case StallAction.reload:
        debugPrint('watchdog: still stalled, reloading segment $cid');
        _openCurrentSegment(retry: true);
      case StallAction.giveUp:
        debugPrint(
          'watchdog: segment $cid stays stuck at ${state.position}, giving up',
        );
    }
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
    final isPaused = _player.state.playing == false;
    if (!isPaused) {
      await _player.pause();
    }
    String? location;
    try {
      if (Platform.isWindows) {
        location = await FilePicker.platform.saveFile(
          dialogTitle: '保存游戏',
          fileName: suggestedName,
          type: FileType.custom,
          allowedExtensions: ['json'],
          lockParentWindow: true,
        );
        if (location != null) await steins.save(location);
      } else if (Platform.operatingSystem == 'ohos') {
        // `file_picker` drops the payload of save() on HarmonyOS, so the
        // system picker is driven by the native channel instead.
        // (`Platform.isOhos` would be shorter, but it only exists in the
        // HarmonyOS fork of the Dart SDK.)
        location = await _saveFileChannel.invokeMethod<String>('save', {
          'fileName': suggestedName,
          'bytes': Uint8List.fromList(utf8.encode(steins.encodeSaveData())),
        });
      } else {
        // Mobile pickers only take a save location together with the data.
        location = await FilePicker.platform.saveFile(
          dialogTitle: '保存游戏',
          fileName: suggestedName,
          type: FileType.custom,
          allowedExtensions: ['json'],
          bytes: Uint8List.fromList(utf8.encode(steins.encodeSaveData())),
        );
      }
    } catch (error) {
      debugPrint('Failed to save game: $error');
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => ContentDialog(
            title: const Text('保存失败'),
            content: Text('$error', style: const TextStyle(fontSize: 16)),
            actions: [
              Button(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
    }
    if (location == null) {
      if (!isPaused) {
        await _player.play();
      }
      return;
    }
    debugPrint('Saved game to: $location');
    if (!isPaused) {
      await _player.play();
    }
  }

  Future<void> _loadGame() async {
    final isPaused = _player.state.playing == false;
    if (!isPaused) {
      await _player.pause();
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      lockParentWindow: true,
    );

    if (result == null || result.files.isEmpty) {
      if (!isPaused) {
        await _player.play();
      }
      return;
    }
    final file = result.files.first;
    if (file.path == null) {
      if (!isPaused) {
        await _player.play();
      }
      return;
    }
    final state = await steins.load(file.path!);
    if (state == null) {
      debugPrint('Failed to load game: ${file.path}');
      if (!isPaused) {
        await _player.play();
      }
      return;
    }
    _updateState(state);
    await _openCurrentSegment(play: !isPaused);
    debugPrint('Loaded game from: ${file.path}');
  }

  Future<void> _toggleFullscreen() async {
    isFullscreenNotifier.value = !isFullscreenNotifier.value;
    if (Platform.isWindows) {
      await windowManager.setFullScreen(isFullscreenNotifier.value);
    } else if (Platform.isAndroid) {
      await SystemChrome.setEnabledSystemUIMode(
        isFullscreenNotifier.value
            ? SystemUiMode.immersiveSticky
            : SystemUiMode.edgeToEdge,
      );
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
              onPressed: () async {
                final paused = !_player.state.playing;
                if (!paused) {
                  await _player.pause();
                }
                await (() async {
                  if (context.mounted) {
                    await Signup.showSignupDialog(context);
                  }
                })();
                if (!paused) {
                  await _player.play();
                }
              },
            ),
            Expanded(
              child: Utils.dragToMoveArea(
                child: Container(color: Colors.transparent),
              ),
            ),
            if (Platform.isWindows)
              MaterialDesktopCustomButton(
                onPressed: () => Utils.exitApp(),
                icon: Icon(Icons.close, color: getAccentColor().lighter),
              ),
          ],
        ),
      ],
    );
  }

  /// The player chrome the choice and ending overlays draw themselves.
  ///
  /// It mirrors the layout `media_kit` uses for the video controls (same
  /// insets, height and horizontal margin), so the back button stays in one
  /// place while playing and while choosing - otherwise both bars are on screen
  /// at once and the corner shows two back buttons.
  Widget _buildOverlayTopBar(EdgeInsets insets) {
    return Padding(
      padding: insets,
      child: Container(
        height: _topBarHeight,
        margin: EdgeInsets.symmetric(
          horizontal: Platform.isWindows ? 16.0 : _mobileTopBarMargin,
        ),
        child: _buildTopBar(),
      ),
    );
  }

  Widget _buildChoiceOverlay() {
    final insets = Utils.systemInsets(context);
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: .25),
        child: Column(
          children: [
            _buildOverlayTopBar(insets),
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

  /// Shown when the story has no content left: an ending was reached or an
  /// ending gate did not match. Without it the last frame just freezes and the
  /// player has no idea whether the game is still working.
  Widget _buildEndingOverlay() {
    final insets = Utils.systemInsets(context);
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: .45),
        child: Column(
          children: [
            _buildOverlayTopBar(insets),
            const Spacer(),
            Text(
              '剧情已结束',
              style: TextStyle(
                color: getAccentColor().lighter,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: "Microsoft YaHei UI",
              ),
            ),
            if (title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  title,
                  style: TextStyle(
                    color: getAccentColor().lightest,
                    fontSize: 14,
                    fontFamily: "Microsoft YaHei UI",
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32.0),
              child: FilledButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll<Color>(
                    getAccentColor().lightest,
                  ),
                ),
                onPressed: () {
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: Text(
                  '返回首页',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                    fontFamily: "Microsoft YaHei UI",
                  ),
                ),
              ),
            ),
            const Spacer(flex: 2),
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

  void _cycleSpeed() {
    final currentIndex = speedOptions.indexOf(selectedSpeedNotifier.value);
    final nextIndex = (currentIndex + 1) % speedOptions.length;
    selectedSpeedNotifier.value = speedOptions[nextIndex];
    _player.setRate(
      double.parse(selectedSpeedNotifier.value.replaceAll('x', '')),
    );
  }

  /// `media_kit` picks the desktop controls on Windows, but the Material ones
  /// everywhere else, so the latter are configured with the same button bars.
  Widget _mobileControlsTheme({required Widget child}) {
    if (Platform.isWindows) {
      return child;
    }
    return MaterialVideoControlsTheme(
      normal: _mobileThemeData(),
      fullscreen: _mobileThemeData(),
      child: child,
    );
  }

  MaterialVideoControlsThemeData _mobileThemeData() {
    final insets = Utils.systemInsets(context);
    return MaterialVideoControlsThemeData(
      padding: insets == EdgeInsets.zero ? null : insets,
      primaryButtonBar: const [],
      topButtonBar: [Expanded(child: _buildTopBar())],
      // Keep every button clear of the corners, where phones may cut out a
      // camera hole. The choice and ending overlays reuse these numbers.
      buttonBarHeight: _topBarHeight,
      topButtonBarMargin: const EdgeInsets.symmetric(
        horizontal: _mobileTopBarMargin,
      ),
      bottomButtonBarMargin: const EdgeInsets.symmetric(horizontal: 40.0),
      bottomButtonBar: [
        Expanded(
          child: Row(
            children: [
              MaterialPlayOrPauseButton(
                iconSize: 24.0,
                iconColor: getAccentColor().lighter,
              ),
              MaterialPositionIndicator(style: textStyle),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: '保存游戏',
              useMousePosition: false,
              style: TooltipThemeData(textStyle: textStyle),
              child: MaterialCustomButton(
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
              child: MaterialCustomButton(
                icon: Icon(
                  Icons.file_upload_outlined,
                  color: getAccentColor().lighter,
                ),
                iconSize: 24.0,
                onPressed: _loadGame,
              ),
            ),
          ],
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              MaterialCustomButton(
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
                onPressed: _cycleSpeed,
              ),
            ],
          ),
        ),
      ],
      // Keep the seek bar just above the button bar instead of the screen edge.
      seekBarMargin: const EdgeInsets.only(bottom: 60.0),
      seekBarPositionColor: getAccentColor().lighter,
      seekBarThumbColor: getAccentColor().light,
    );
  }

  @override
  Widget build(BuildContext context) {
    final insets = Utils.systemInsets(context);
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: _mobileControlsTheme(
                child: MaterialDesktopVideoControlsTheme(
                  normal: MaterialDesktopVideoControlsThemeData(
                    padding: insets == EdgeInsets.zero ? null : insets,
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
                        onPressed: _cycleSpeed,
                      ),
                      MaterialDesktopVolumeButton(
                        iconColor: getAccentColor().lighter,
                      ),
                      if (Platform.isWindows)
                        Tooltip(
                          message: '全屏',
                          useMousePosition: false,
                          style: TooltipThemeData(textStyle: textStyle),
                          child: MaterialDesktopCustomButton(
                            icon: Icon(
                              Icons.fullscreen,
                              color: getAccentColor().lighter,
                            ),
                            iconSize: 24.0,
                            onPressed: _toggleFullscreen,
                          ),
                        ),
                    ],
                  ),
                  fullscreen: MaterialDesktopVideoControlsThemeData(
                    padding: insets == EdgeInsets.zero ? null : insets,
                    keyboardShortcuts: keyboardShortcuts(context),
                    seekBarThumbColor: getAccentColor().light,
                    seekBarPositionColor: getAccentColor().lighter,
                    toggleFullscreenOnDoublePress: Platform.isWindows,
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
                        onPressed: _cycleSpeed,
                      ),
                      MaterialDesktopVolumeButton(
                        iconColor: getAccentColor().lighter,
                      ),
                      if (Platform.isWindows)
                        Tooltip(
                          message: '退出全屏',
                          useMousePosition: false,
                          style: TooltipThemeData(textStyle: textStyle),
                          child: MaterialDesktopCustomButton(
                            icon: Icon(
                              Icons.fullscreen_exit,
                              color: getAccentColor().lighter,
                            ),
                            iconSize: 24.0,
                            onPressed: _toggleFullscreen,
                          ),
                        ),
                    ],
                  ),
                  child: Scaffold(
                    body: Video(
                      wakelock: false,
                      controller: _controller,
                      // While the choice or ending overlay is up the video
                      // controls would draw a second top bar over it.
                      controls: (_showChoiceOverlay || _storyEnded)
                          ? _withoutVideoControls
                          : AdaptiveVideoControls,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_showChoiceOverlay) _buildChoiceOverlay(),
          if (_storyEnded) _buildEndingOverlay(),
        ],
      ),
    );
  }
}
