import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:system_theme/system_theme.dart';
import 'package:window_manager/window_manager.dart';

import 'about.dart';
import 'player.dart';
import 'signup.dart';
import 'update.dart';
import 'splash.dart';
import 'utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await Signup.readUsername();

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
      home: const SplashPage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final List<String> _types = ['anon', 'soyo', 'sakiko', 'tomori', 'mutsumi'];
  late final player = Player();
  late final controller = VideoController(player);
  late AnimationController _fadeInController;
  bool _showFadeInOverlay = true;

  String? _hoveredType;

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
    player.open(Media('asset:///res/global/background.mp4'));
    player.stream.completed.listen((completed) {
      if (completed) {
        player.seek(Duration.zero);
        player.play();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Update().checkUpdate(context);
      if (Signup.currentUsername == '') Signup.showSignupDialog(context);
    });
  }

  @override
  void dispose() {
    _fadeInController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Video(
          wakelock: false,
          controller: controller,
          controls: NoVideoControls,
        ),
        NavigationPaneTheme(
          data: NavigationPaneThemeData(backgroundColor: Colors.transparent),
          child: NavigationView(
            titleBar: Utils.buildTopButtonBar(context, showBack: false),
            content: ScaffoldPage(
              content: Stack(
                children: [
                  Center(
                    child: FractionallySizedBox(
                      widthFactor: 0.94,
                      heightFactor: 0.94,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          double totalWidth = constraints.maxWidth;
                          double cellWidth = (totalWidth - 32) / 3;
                          double cellHeight = cellWidth * 9 / 16 + 8;
                          double rowHeight = cellHeight;
                          return Column(
                            children: [
                              SizedBox(
                                height: rowHeight,
                                child: _buildRow(0, 3, cellWidth, cellHeight),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: rowHeight,
                                child: _buildRow(
                                  3,
                                  3,
                                  cellWidth,
                                  cellHeight,
                                  includeEmptyLast: true,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    right: 24,
                    bottom: 24,
                    child: Container(
                      width: 56,
                      height: 56,
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
                          iconSize: WidgetStatePropertyAll<double>(28.0),
                          backgroundColor: WidgetStatePropertyAll<Color>(
                            Colors.transparent,
                          ),
                          padding: WidgetStatePropertyAll<EdgeInsets>(
                            EdgeInsets.zero,
                          ),
                        ),
                        onPressed: () async {
                          player.pause();
                          await Navigator.of(context).push(
                            FluentPageRoute(
                              builder: (context) => const AboutPage(),
                            ),
                          );
                          player.play();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_showFadeInOverlay)
          Positioned.fill(
            child: Opacity(
              opacity: 1.0 - _fadeInController.value,
              child: Container(color: Colors.black),
            ),
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
