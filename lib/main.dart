import 'dart:io';
import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';

import 'about.dart';
import 'cutout.dart';
import 'player.dart';
import 'signup.dart';
import 'update.dart';
import 'splash.dart';
import 'utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await Update.getAppVersion();
  await Signup.readUsername();

  if (!Platform.isWindows) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
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
      title: 'Lullaby Core',
      theme: FluentThemeData(
        brightness: Brightness.dark,
        accentColor: Utils.systemAccentColor(),
      ),
      home: const SplashPage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final List<String> _types = [
    'anon',
    'soyo',
    'sakiko',
    'tomori',
    'mutsumi',
    'viola',
  ];
  late final player = Player();
  late final controller = VideoController(player);
  late AnimationController _fadeInController;
  bool _showFadeInOverlay = true;

  String? _hoveredType;
  bool _aboutOpen = false;

  @override
  void initState() {
    super.initState();
    _fadeInController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _fadeInController.addListener(() {
      setState(() {});
    });
    _fadeInController.forward().then((_) {
      setState(() {
        _showFadeInOverlay = false;
      });
    });
    player.setVolume(100.0);
    Utils.mediaUri(
      'res/global/background.mp4',
    ).then((uri) => player.open(Media(uri)));
    player.stream.completed.listen((completed) {
      if (completed) {
        player.seek(Duration.zero);
        player.play();
      }
    });
    WidgetsBinding.instance.addObserver(this);
    DisplayCutOut.refresh().then((_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Update().checkUpdate(context);
      if (Signup.currentUsername == '') Signup.showSignupDialog(context);
    });
  }

  /// The video output is torn down while the app is in the background, so the
  /// background video has to be restarted when the app comes back.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_aboutOpen) {
      player.play();
    }
  }

  /// Rotating the phone flips which short edge carries the camera cut-out.
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    DisplayCutOut.refresh().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fadeInController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insets = Utils.systemInsets(context);
    final double sideInset = math.max(insets.left, insets.right);
    final screen = MediaQuery.sizeOf(context);
    final bool bottomRightBlocked =
        !Platform.isWindows && DisplayCutOut.blocksBottomRight(screen);
    return PopScope(
      // The system back gesture on the home page leaves the app (no route is
      // left to pop), instead of landing on the stopped loading video.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Utils.exitApp();
      },
      child: Stack(
        children: [
          Video(
            wakelock: false,
            controller: controller,
            controls: NoVideoControls,
            fit: Utils.backgroundVideoFit,
          ),
          Padding(
            padding: EdgeInsets.only(
              left: sideInset,
              right: sideInset,
              bottom: insets.bottom,
            ),
            child: NavigationPaneTheme(
              data: NavigationPaneThemeData(
                backgroundColor: Colors.transparent,
              ),
              child: NavigationView(
                titleBar: Utils.buildTopButtonBar(context, showBack: false),
                content: ScaffoldPage(
                  content: Stack(
                    children: [
                      if (Platform.isWindows)
                        Positioned(
                          right: 24,
                          bottom: 24,
                          child: _buildAboutBall(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // The covers are centred on the whole window: the navigation title bar
          // only takes space at the top, so centring them in the navigation
          // content would push them down. They are drawn above the navigation
          // view as well, otherwise its page background swallows the taps.
          Positioned.fill(child: _buildGrid(context)),
          // On phones the entry button is drawn on top of everything, including
          // the covers it sits next to.
          if (!Platform.isWindows)
            Positioned(
              right: 16,
              // It sits in the bottom-right corner, which the covers leave free.
              // A camera cut-out reported over that corner moves it up to the
              // middle of the right edge, which is still clear of the covers.
              top: bottomRightBlocked ? (screen.height - 48) / 2 : null,
              bottom: bottomRightBlocked ? null : math.max(16, insets.bottom),
              child: _buildAboutBall(),
            ),
          if (_showFadeInOverlay)
            Positioned.fill(
              child: Opacity(
                opacity: 1.0 - _fadeInController.value,
                child: Container(color: Colors.black),
              ),
            ),
        ],
      ),
    );
  }

  /// The round green entry button that opens the about page.
  Widget _buildAboutBall() {
    return Container(
      width: Platform.isWindows ? 56 : 48,
      height: Platform.isWindows ? 56 : 48,
      decoration: BoxDecoration(
        color: Colors.green,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: IconButton(
        icon: const Icon(FluentIcons.info, color: Colors.white),
        style: ButtonStyle(
          iconSize: WidgetStatePropertyAll<double>(
            Platform.isWindows ? 28.0 : 24.0,
          ),
          backgroundColor: WidgetStatePropertyAll<Color>(Colors.transparent),
          padding: WidgetStatePropertyAll<EdgeInsets>(EdgeInsets.zero),
        ),
        onPressed: _openAbout,
      ),
    );
  }

  Future<void> _openAbout() async {
    _aboutOpen = true;
    player.pause();
    await Navigator.of(
      context,
    ).push(FluentPageRoute(builder: (context) => const AboutPage()));
    _aboutOpen = false;
    player.play();
  }

  /// The five work entries, sized to use as much of the available box as
  /// possible: on phones both dimensions are filled (the covers get cropped a
  /// little vertically), on Windows the original 16:9 sizing is kept.
  Widget _buildGrid(BuildContext context) {
    if (Platform.isWindows) {
      return FractionallySizedBox(
        widthFactor: 0.94,
        heightFactor: 0.94,
        child: LayoutBuilder(builder: _buildGridLayout),
      );
    }
    // The grid sits at the root of the page, so it has to clear the safe area
    // itself: the base margin, or the camera cut-out when that is wider. The
    // same margin is used on both sides so the row stays centred on the screen.
    final insets = Utils.systemInsets(context);
    final double sideMargin = math.max(28, math.max(insets.left, insets.right));
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: sideMargin),
      child: LayoutBuilder(
        builder: (context, constraints) =>
            _buildGridLayout(context, constraints, scale: 0.9),
      ),
    );
  }

  Widget _buildGridLayout(
    BuildContext context,
    BoxConstraints constraints, {
    double scale = 1,
  }) {
    const double gap = 16;
    double cellWidth = (constraints.maxWidth - gap * 2) / 3;
    double cellHeight = cellWidth * 9 / 16 + 8;
    final double maxCellHeight = (constraints.maxHeight - gap) / 2;
    if (cellHeight > maxCellHeight) {
      cellHeight = maxCellHeight < 0 ? 0 : maxCellHeight;
      if (Platform.isWindows) {
        cellWidth = cellHeight > 8 ? (cellHeight - 8) * 16 / 9 : 0;
      }
    }
    cellWidth *= scale;
    cellHeight *= scale;
    final double rowHeight = cellHeight;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: rowHeight,
          child: _buildRow(0, 3, cellWidth, cellHeight),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: rowHeight,
          child: _buildRow(3, 3, cellWidth, cellHeight, includeEmptyLast: true),
        ),
      ],
    );
  }

  Widget _buildRow(
    int startIndex,
    int count,
    double cellWidth,
    double cellHeight, {
    bool includeEmptyLast = false,
  }) {
    final cells = List<Widget>.generate(count, (index) {
      final overallIndex = startIndex + index;
      if (includeEmptyLast && overallIndex >= _types.length) {
        return SizedBox(width: cellWidth, height: cellHeight);
      }
      final type = _types[overallIndex];
      return SizedBox(width: cellWidth, child: _buildCell(type, cellHeight));
    });
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < cells.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          cells[i],
        ],
      ],
    );
  }

  Widget _buildCell(String type, double cellHeight) {
    final hovered = _hoveredType == type;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hoveredType = type),
      onExit: (_) => setState(() => _hoveredType = null),
      child: GestureDetector(
        onTap: () async {
          player.pause();
          await Navigator.of(
            context,
          ).push(FluentPageRoute(builder: (context) => PlayerPage(type: type)));
          player.play();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          height: cellHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            color: hovered
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hovered
                  ? Colors.blue
                  : Colors.white.withValues(alpha: 0.12),
              width: hovered ? 3 : 0,
            ),
            boxShadow: hovered
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'res/works/$type/cover.png',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey.withValues(alpha: 0.18),
                        alignment: Alignment.center,
                        child: Text(
                          type,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
