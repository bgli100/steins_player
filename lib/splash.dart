import 'package:fluent_ui/fluent_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'main.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  late final player = Player();
  late final controller = VideoController(player);

  @override
  void initState() {
    super.initState();
    player.setVolume(100.0);
    player.open(Media('asset:///res/global/loading.mp4'));
    player.stream.completed.listen((completed) {
      if (completed) {
        player.stop();
        if (!mounted) {
          return;
        }
        Navigator.of(
          context,
        ).push(FluentPageRoute(builder: (context) => HomePage()));
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  TextStyle get textStyle =>
      TextStyle(fontSize: 18, fontFamily: "Microsoft YaHei UI");

  @override
  Widget build(BuildContext context) {
    return Video(
      wakelock: false,
      controller: controller,
      controls: NoVideoControls,
    );
  }
}
