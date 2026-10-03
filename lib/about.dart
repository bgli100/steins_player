import 'dart:io';
import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:steins_player/utils.dart';
import 'package:url_launcher/url_launcher.dart';

import 'update.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  TextStyle get textStyle =>
      TextStyle(fontSize: 18, fontFamily: "Microsoft YaHei UI");

  /// Opens [url] in the system browser. The external mode is required on
  /// HarmonyOS, where the default mode tries to open an in-app web view.
  static Future<void> _openUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (error) {
      debugPrint('Failed to open $url: $error');
    }
  }

  /// Opens a Bilibili video with the Bilibili app when it is installed, and
  /// falls back to the website otherwise.
  static Future<void> _openBilibili(String bv) async {
    if (!Platform.isWindows) {
      try {
        final opened = await launchUrl(
          Uri.parse('bilibili://video/$bv'),
          mode: LaunchMode.externalApplication,
        );
        if (opened) return;
      } catch (error) {
        debugPrint('Bilibili app did not handle $bv: $error');
      }
    }
    await _openUrl('https://www.bilibili.com/video/$bv/');
  }

  /// The five works, linked to their Bilibili page.
  static const List<(String, String, String)> _works = [
    ('BV1GxLgzgEyL', '千早爱音的土拨鼠之日', 'anon'),
    ('BV1vSNbzgEQF', '长崎素世的月之暗面', 'soyo'),
    ('BV1zFnAzkEq5', '丰川祥子的五夜后宫', 'sakiko'),
    ('BV1qLBCB1Ej5', '高松灯的命运石之门', 'tomori'),
    ('BV1Uqo6BBEpa', '若叶睦的寓言', 'mutsumi'),
  ];

  List<Widget> _buildWorkButtons() => _works.map((work) {
    final (bv, label, type) = work;
    final accent = Utils.getAccentColorForType(type);
    return FilledButton(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.hovered)) {
            return accent.light;
          } else {
            return accent.normal;
          }
        }),
      ),
      onPressed: () => _openBilibili(bv),
      child: Text(label, style: textStyle),
    );
  }).toList();

  /// On phones the page is drawn without the desktop card: background and
  /// content are one and the same colour, and everything is compact enough to
  /// fit the short viewport instead of being dragged under the top bar.
  @override
  Widget build(BuildContext context) {
    final insets = Utils.systemInsets(context);
    final compact = !Platform.isWindows;
    final buttons = _buildWorkButtons();
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              'res/icon.png',
              width: compact ? 96 : 192,
              height: compact ? 96 : 192,
            ),
            SizedBox(width: compact ? 12 : 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lullaby Core ${Update.currentVersion}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: compact ? 20 : 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: "Microsoft YaHei UI",
                    ),
                  ),
                  SizedBox(height: compact ? 6 : 10),
                  Text(
                    '一个 Windows, HarmonyOS, Android 平台基于 Flutter 的 bilibili 互动视频播放器',
                    style: textStyle,
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 10 : 18),
        Text('感谢 foolish_dogve 制作的无限循环系列内容 (点击访问原作)', style: textStyle),
        if (compact)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: buttons,
            ),
          )
        else
          ...buttons.expand((button) => [const SizedBox(height: 12), button]),
        SizedBox(height: compact ? 10 : 12),
        Text('感谢 DeepSeek, Github Copilot 提供的代码生成支持', style: textStyle),
      ],
    );
    return NavigationView(
      titleBar: Utils.buildTopButtonBar(context, showBack: true),
      content: ScaffoldPage(
        content: Stack(
          children: [
            Padding(
              // On phones the content carries its own margin instead (see
              // below), so only the desktop padding is set here.
              padding: EdgeInsets.only(
                left: compact ? 0 : insets.left,
                right: compact ? 0 : insets.right,
                bottom: insets.bottom,
              ),
              child: SingleChildScrollView(
                child: Center(
                  child: SizedBox(
                    width: compact ? double.infinity : 760,
                    child: compact
                        ? Padding(
                            // Wider than the camera cut-out (48 dp) and the
                            // same on both sides, so the page stays symmetric.
                            padding: EdgeInsets.symmetric(
                              horizontal: math.max(
                                56,
                                math.max(insets.left, insets.right),
                              ),
                              vertical: 16.0,
                            ),
                            child: content,
                          )
                        : Padding(
                            // No card: background and content share the page
                            // colour, as on phones.
                            padding: const EdgeInsets.all(24.0),
                            child: content,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
