import 'package:fluent_ui/fluent_ui.dart';

class Utils {
  static AccentColor getAccentColorForType(String type) {
    switch (type) {
      case "anon":
        return AccentColor.lerp(
          Colors.red,
          AccentColor.swatch(const <String, Color>{
            'darkest': Colors.white,
            'darker': Colors.white,
            'dark': Colors.white,
            'normal': Colors.white,
            'light': Colors.white,
            'lighter': Colors.white,
            'lightest': Colors.white,
          }),
          0.5,
        );
      case "soyo":
        return Colors.orange;
      case "sakiko":
        return Colors.blue;
      case "tomori":
        return AccentColor.swatch(const <String, Color>{
          'darkest': Color(0xFF11100F),
          'darker': Color(0xFF201F1E),
          'dark': Color(0xFF323130),
          'normal': Color(0xFF605E5C),
          'light': Color(0xFF979593),
          'lighter': Color(0xFFBEBBB8),
          'lightest': Color(0xFFE1DFDD),
        });
      case "mutsumi":
      default:
        return Colors.green;
    }
  }
}
