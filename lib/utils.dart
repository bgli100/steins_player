import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:window_manager/window_manager.dart';

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

  static Widget buildTopButtonBar(
    BuildContext context, {
    required bool showBack,
  }) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      decoration: BoxDecoration(color: Colors.transparent),
      foregroundDecoration: BoxDecoration(color: Colors.transparent),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              icon: const Icon(Icons.west, color: Colors.white),
              style: ButtonStyle(
                iconSize: WidgetStatePropertyAll<double>(28.0),
              ),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          Expanded(
            child: DragToMoveArea(child: Container(color: Colors.transparent)),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            style: ButtonStyle(iconSize: WidgetStatePropertyAll<double>(28.0)),
            onPressed: () => exit(0),
          ),
        ],
      ),
    );
  }
}
