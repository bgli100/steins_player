import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:fluent_ui/fluent_ui.dart';

class Update {
  static String currentVersion = '';

  /// Remote feed describing the newest release.
  static const String feedUrl =
      'https://raw.gitcode.com/bgli100/LullabyCore/raw/master/version.json';

  /// Labels used when the feed does not name the links through
  /// `download_name` / `download_name2`.
  static const String primaryLinkLabel = '去下载';
  static const String secondaryLinkLabel = '备用下载';

  static Future<void> getAppVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    currentVersion = packageInfo.version;
  }

  TextStyle get textStyle =>
      TextStyle(fontSize: 18, fontFamily: "Microsoft YaHei UI");

  Future<void> checkUpdate(BuildContext context) async {
    try {
      final response = await http.get(Uri.parse(feedUrl));
      if (response.statusCode != 200) return;
      final data = json.decode(response.body);
      if (data is! Map<String, dynamic>) return;
      final remoteVersion = _text(data['version']);
      if (remoteVersion == null) return;
      if (context.mounted && isNewerVersion(remoteVersion, currentVersion)) {
        await showUpdateDialog(
          context,
          newVersion: remoteVersion,
          announcement: _text(data['announcement']) ?? '',
          links: downloadLinks(data),
        );
      }
    } catch (error) {
      debugPrint('Update check failed: $error');
    }
  }

  /// The download links of the update feed, as (label, url) pairs.
  ///
  /// `download_url` / `download_url2` hold the addresses, the optional
  /// `download_name` / `download_name2` their button labels. Links that the
  /// feed leaves empty are skipped.
  static List<(String, String)> downloadLinks(Map<String, dynamic> data) {
    final links = <(String, String)>[];

    void add(String urlKey, String nameKey, String fallbackLabel) {
      final url = _text(data[urlKey]);
      if (url == null) return;
      links.add((_text(data[nameKey]) ?? fallbackLabel, url));
    }

    add('download_url', 'download_name', primaryLinkLabel);
    add('download_url2', 'download_name2', secondaryLinkLabel);
    return links;
  }

  /// Whether [remote] is a newer release than [current]. Missing parts count as
  /// zero, so "1.1" and "1.1.0" describe the same release.
  static bool isNewerVersion(String remote, String current) {
    final remoteParts = _versionParts(remote);
    final currentParts = _versionParts(current);
    for (int i = 0; i < remoteParts.length; i++) {
      if (remoteParts[i] != currentParts[i]) {
        return remoteParts[i] > currentParts[i];
      }
    }
    return false;
  }

  static List<int> _versionParts(String version) {
    final parts = <int>[];
    for (final part in version.split('.')) {
      parts.add(int.tryParse(part.trim()) ?? 0);
    }
    while (parts.length < 3) {
      parts.add(0);
    }
    return parts;
  }

  static String? _text(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  /// Shows the release notes with one button per download link.
  Future<void> showUpdateDialog(
    BuildContext context, {
    required String newVersion,
    required String announcement,
    required List<(String, String)> links,
  }) {
    return showDialog(
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
          for (final (label, url) in links)
            FilledButton(
              onPressed: () async {
                await _openLink(url);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: Text(label, style: textStyle),
            ),
        ],
      ),
    );
  }

  /// HarmonyOS needs the external mode to hand the link to a browser.
  static Future<void> _openLink(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (error) {
      debugPrint('Failed to open $url: $error');
    }
  }
}
