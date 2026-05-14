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

  @override
  Widget build(BuildContext context) {
    return NavigationView(
      titleBar: Utils.buildTopButtonBar(context, showBack: true),
      content: ScaffoldPage(
        content: Stack(
          children: [
            Center(
              child: SizedBox(
                width: 760,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Lullaby Core ${Update.currentVersion}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            fontFamily: "Microsoft YaHei UI",
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '一个 Windows 平台基于 Flutter 的 bilibili 互动视频播放器',
                          style: textStyle,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '感谢 foolish_dogve 制作的无限循环系列内容 (点击访问原作)',
                          style: textStyle,
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          style: ButtonStyle(
                            backgroundColor:
                                WidgetStateProperty.resolveWith<Color>((
                                  states,
                                ) {
                                  if (states.contains(WidgetState.hovered)) {
                                    return Utils.getAccentColorForType(
                                      'anon',
                                    ).light;
                                  } else {
                                    return Utils.getAccentColorForType(
                                      'anon',
                                    ).normal;
                                  }
                                }),
                          ),
                          onPressed: () async {
                            await launchUrl(
                              Uri.parse(
                                "https://www.bilibili.com/video/BV1GxLgzgEyL/",
                              ),
                            );
                          },
                          child: Text('千早爱音的土拨鼠之日', style: textStyle),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          style: ButtonStyle(
                            backgroundColor:
                                WidgetStateProperty.resolveWith<Color>((
                                  states,
                                ) {
                                  if (states.contains(WidgetState.hovered)) {
                                    return Utils.getAccentColorForType(
                                      'soyo',
                                    ).light;
                                  } else {
                                    return Utils.getAccentColorForType(
                                      'soyo',
                                    ).normal;
                                  }
                                }),
                          ),
                          onPressed: () async {
                            await launchUrl(
                              Uri.parse(
                                "https://www.bilibili.com/video/BV1vSNbzgEQF/",
                              ),
                            );
                          },
                          child: Text('长崎素世的月之暗面', style: textStyle),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          style: ButtonStyle(
                            backgroundColor:
                                WidgetStateProperty.resolveWith<Color>((
                                  states,
                                ) {
                                  if (states.contains(WidgetState.hovered)) {
                                    return Utils.getAccentColorForType(
                                      'sakiko',
                                    ).light;
                                  } else {
                                    return Utils.getAccentColorForType(
                                      'sakiko',
                                    ).normal;
                                  }
                                }),
                          ),
                          onPressed: () async {
                            await launchUrl(
                              Uri.parse(
                                "https://www.bilibili.com/video/BV1zFnAzkEq5",
                              ),
                            );
                          },
                          child: Text('丰川祥子的五夜后宫', style: textStyle),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          style: ButtonStyle(
                            backgroundColor:
                                WidgetStateProperty.resolveWith<Color>((
                                  states,
                                ) {
                                  if (states.contains(WidgetState.hovered)) {
                                    return Utils.getAccentColorForType(
                                      'tomori',
                                    ).light;
                                  } else {
                                    return Utils.getAccentColorForType(
                                      'tomori',
                                    ).normal;
                                  }
                                }),
                          ),
                          onPressed: () async {
                            await launchUrl(
                              Uri.parse(
                                "https://www.bilibili.com/video/BV1qLBCB1Ej5/",
                              ),
                            );
                          },
                          child: Text('高松灯的命运石之门', style: textStyle),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          style: ButtonStyle(
                            backgroundColor:
                                WidgetStateProperty.resolveWith<Color>((
                                  states,
                                ) {
                                  if (states.contains(WidgetState.hovered)) {
                                    return Utils.getAccentColorForType(
                                      'mutsumi',
                                    ).light;
                                  } else {
                                    return Utils.getAccentColorForType(
                                      'mutsumi',
                                    ).normal;
                                  }
                                }),
                          ),
                          onPressed: () async {
                            await launchUrl(
                              Uri.parse(
                                "https://www.bilibili.com/video/BV1Uqo6BBEpa/",
                              ),
                            );
                          },
                          child: Text('若叶睦的寓言', style: textStyle),
                        ),
                        const SizedBox(height: 12),
                        Text('感谢 Github Copilot 提供的代码生成支持', style: textStyle),
                      ],
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
