import 'dart:convert';
import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class Signup {
  static TextStyle get textStyle =>
      TextStyle(fontSize: 18, fontFamily: "Microsoft YaHei UI");

  static String currentUsername = '';

  static Future<void> writeUsername() async {
    Map<String, dynamic> map = <String, dynamic>{"username": currentUsername};
    final directory = await getApplicationSupportDirectory();
    final file = File(p.join(directory.path, "lullaby_core.json"));
    await file.writeAsString(jsonEncode(map));
    debugPrint("saved to ${file.path}, data $map");
  }

  static Future<void> readUsername() async {
    final directory = await getApplicationSupportDirectory();
    final file = File(p.join(directory.path, "lullaby_core.json"));
    if (!file.existsSync()) {
      currentUsername = '';
      return;
    }
    final content = await file.readAsString();
    final data = jsonDecode(content);
    currentUsername = data?['username'] ?? '';
    debugPrint("loaded from ${file.path}, data $data");
  }

  static Future<void> showSignupDialog(BuildContext context) {
    String tempUsername = currentUsername;
    String? errorMessage;
    final controller = TextEditingController(text: currentUsername);

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => ContentDialog(
          title: Text(
            '请输入你的用户名: ',
            style: TextStyle(
              fontSize: 18,
              fontFamily: "Microsoft YaHei UI",
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextBox(
                controller: controller,
                style: textStyle,
                maxLines: 1,
                onChanged: (value) {
                  tempUsername = value;
                },
              ),
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    errorMessage!,
                    style: textStyle.copyWith(color: Colors.red),
                  ),
                ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () async {
                if (tempUsername.isEmpty) {
                  setState(() {
                    errorMessage = '用户名无法为空';
                  });
                  return;
                }
                currentUsername = tempUsername;
                await writeUsername();
                controller.dispose();
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('确认'),
            ),
          ],
        ),
      ),
    );
  }
}
