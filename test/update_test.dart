import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steins_player/update.dart';

void main() {
  group('download links', () {
    test('the primary link keeps its default label', () {
      final links = Update.downloadLinks({'download_url': 'https://a'});
      expect(links, [(Update.primaryLinkLabel, 'https://a')]);
    });

    test('a second link is reported with its own label', () {
      final links = Update.downloadLinks({
        'download_url': 'https://a',
        'download_url2': 'https://b',
      });
      expect(links, [
        (Update.primaryLinkLabel, 'https://a'),
        (Update.secondaryLinkLabel, 'https://b'),
      ]);
    });

    test('the feed may name the links itself', () {
      final links = Update.downloadLinks({
        'download_url': 'https://a',
        'download_name': '百度网盘',
        'download_url2': 'https://b',
        'download_name2': '夸克网盘',
      });
      expect(links, [('百度网盘', 'https://a'), ('夸克网盘', 'https://b')]);
    });

    test('empty and missing links are skipped', () {
      expect(Update.downloadLinks({}), isEmpty);
      expect(Update.downloadLinks({'download_url': '  '}), isEmpty);
      expect(Update.downloadLinks({'download_url2': 'https://b'}), [
        (Update.secondaryLinkLabel, 'https://b'),
      ]);
    });
  });

  group('version comparison', () {
    test('newer, equal and older releases', () {
      expect(Update.isNewerVersion('1.0.1', '1.0.0'), isTrue);
      expect(Update.isNewerVersion('1.1.0', '1.0.9'), isTrue);
      expect(Update.isNewerVersion('2.0.0', '1.9.9'), isTrue);
      expect(Update.isNewerVersion('1.0.0', '1.0.0'), isFalse);
      expect(Update.isNewerVersion('0.3.7', '1.0.0'), isFalse);
    });

    test('shorter versions are padded with zeros', () {
      expect(Update.isNewerVersion('1.1', '1.0.0'), isTrue);
      expect(Update.isNewerVersion('1.0', '1.0.0'), isFalse);
      expect(Update.isNewerVersion('1.0.0', '1.0'), isFalse);
    });
  });

  testWidgets('the dialog shows a button per link', (tester) async {
    await tester.pumpWidget(
      FluentApp(
        home: Builder(
          builder: (context) => ScaffoldPage(
            content: Button(
              onPressed: () => Update().showUpdateDialog(
                context,
                newVersion: '1.0.1',
                announcement: '修复了一些问题',
                links: const [('百度网盘', 'https://a'), ('夸克网盘', 'https://b')],
              ),
              child: const Text('check'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('check'));
    await tester.pumpAndSettle();

    expect(find.text('发现新版本 1.0.1'), findsOneWidget);
    expect(find.text('修复了一些问题'), findsOneWidget);
    expect(find.text('返回'), findsOneWidget);
    expect(find.text('百度网盘'), findsOneWidget);
    expect(find.text('夸克网盘'), findsOneWidget);
  });

  testWidgets('a feed without links still offers a way out', (tester) async {
    await tester.pumpWidget(
      FluentApp(
        home: Builder(
          builder: (context) => ScaffoldPage(
            content: Button(
              onPressed: () => Update().showUpdateDialog(
                context,
                newVersion: '1.0.1',
                announcement: '修复了一些问题',
                links: const [],
              ),
              child: const Text('check'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('check'));
    await tester.pumpAndSettle();

    expect(find.text('返回'), findsOneWidget);
    expect(find.text('去下载'), findsNothing);
  });

  testWidgets('three actions still fit a phone in landscape', (tester) async {
    tester.view.physicalSize = const Size(2400, 1080);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      FluentApp(
        home: Builder(
          builder: (context) => ScaffoldPage(
            content: Button(
              onPressed: () => Update().showUpdateDialog(
                context,
                newVersion: '1.0.1',
                announcement: '修复了随机卡死问题, 增加全屏支持. 度盘下载慢的, 请去UP动态寻找夸克盘链接',
                links: const [('去下载', 'https://a'), ('备用下载', 'https://b')],
              ),
              child: const Text('check'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('check'));
    await tester.pumpAndSettle();

    expect(find.text('去下载'), findsOneWidget);
    expect(find.text('备用下载'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
