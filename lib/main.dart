import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:media_kit/media_kit.dart';
import 'package:system_theme/system_theme.dart';
import 'package:window_manager/window_manager.dart';

import 'about.dart';
import 'player.dart';

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
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<String> _types = [
    'anon',
    'soyo',
    'sakiko',
    'tomori',
    'mutsumi'
  ];

  String? _hoveredType;

  @override
  Widget build(BuildContext context) {
    return NavigationView(
      titleBar: _buildTopButtonBar(context, showBack: false),
      content: ScaffoldPage(
        content: Stack(
          children: [
            Center(
              child: FractionallySizedBox(
                widthFactor: 0.94,
                heightFactor: 0.94,
                child: LayoutBuilder(
                   builder: (context, constraints) {
                    return Column(
                      children: [
                        Expanded(child: _buildRow(0, 3)),
                        const SizedBox(height: 16),
                        Expanded(child: _buildRow(3, 3, includeEmptyLast: true)),
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
                  color: Colors.blue,
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
                  icon: const Icon(FluentIcons.help, color: Colors.white),
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll<Color>(Colors.transparent),
                    padding: WidgetStatePropertyAll<EdgeInsets>(EdgeInsets.zero),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      FluentPageRoute(builder: (context) => const AboutPage()),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopButtonBar(BuildContext context, {required bool showBack}) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      decoration: BoxDecoration(
        color: Colors.transparent,
      ),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              icon: const Icon(Icons.west, color: Colors.white),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          Expanded(
            child: DragToMoveArea(
              child: Container(color: Colors.transparent),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            style: ButtonStyle(
              iconSize: WidgetStatePropertyAll<double>(28.0)
            ),
            onPressed: () => exit(0),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(int startIndex, int count, {bool includeEmptyLast = false}) {
    final cells = List<Widget>.generate(count, (index) {
      final overallIndex = startIndex + index;
      if (includeEmptyLast && overallIndex >= _types.length) {
        return Expanded(child: Container());
      }
      final type = _types[overallIndex];
      return Expanded(child: _buildCell(type));
    });
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < cells.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          cells[i],
        ],
      ],
    );
  }

  Widget _buildCell(String type) {
    final hovered = _hoveredType == type;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hoveredType = type),
      onExit: (_) => setState(() => _hoveredType = null),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            FluentPageRoute(builder: (context) => PlayerPage(type: type)),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: hovered ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hovered ? Colors.blue : Colors.white.withValues(alpha: 0.12),
              width: hovered ? 2 : 1,
            ),
            boxShadow: hovered
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 12,
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
                child: Image.asset(
                  'res/$type/cover.jpg',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.withValues(alpha: 0.18),
                      alignment: Alignment.center,
                      child: Text(
                        type,
                        style: const TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    );
                  },
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
