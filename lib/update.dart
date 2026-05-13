import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:fluent_ui/fluent_ui.dart';

class Update {
  static final String currentVersion = '0.2.1';

  TextStyle get textStyle =>
      TextStyle(fontSize: 18, fontFamily: "Microsoft YaHei UI");

  Future<void> checkUpdate(BuildContext context) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://raw.gitcode.com/bgli100/LullabyCore/raw/master/version.json',
        ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final remoteVersion = data['version'] as String;
        final announcement = data['announcement'] as String;
        final downloadUrl = data['download_url'] as String;
        if (context.mounted && _isNewerVersion(remoteVersion, currentVersion)) {
          _showUpdateDialog(context, remoteVersion, announcement, downloadUrl);
        }
      }
    } catch (e) {
      // Handle error, maybe log it
    }
  }

  bool _isNewerVersion(String remote, String current) {
    List<int> remoteParts = remote.split('.').map(int.parse).toList();
    List<int> currentParts = current.split('.').map(int.parse).toList();
    for (int i = 0; i < 3; i++) {
      if (remoteParts[i] > currentParts[i]) return true;
      if (remoteParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  void _showUpdateDialog(
    BuildContext context,
    String newVersion,
    String announcement,
    String downloadUrl,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ContentDialog(
        title: Text(
          '发现新版本 $newVersion',
          style: TextStyle(
            fontSize: 24,
            fontFamily: "Microsoft YaHei UI",
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(announcement, style: textStyle),
        actions: [
          Button(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('返回', style: textStyle),
          ),
          FilledButton(
            onPressed: () async {
              await launchUrl(Uri.parse(downloadUrl));
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: Text('去下载', style: textStyle),
          ),
        ],
      ),
    );
  }
}
