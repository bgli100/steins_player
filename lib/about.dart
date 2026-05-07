import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:window_manager/window_manager.dart';

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

  @override
  Widget build(BuildContext context) {
    return NavigationView(
      titleBar: _buildTopButtonBar(context),
      content: ScaffoldPage(
        content: Stack(
          children: [
            Center(
              child: SizedBox(
                width: 560,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Steins Player', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        SizedBox(height: 12),
                        Text('This app lets you launch character segments directly from the home grid and play them with native media controls.'),
                        SizedBox(height: 8),
                        Text('Tap a cover tile to open the player. The bottom-right button returns here.'),
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

  Widget _buildTopButtonBar(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.west),
            style: ButtonStyle(
              iconSize: WidgetStatePropertyAll<double>(28.0)
            ),
            onPressed: () => Navigator.of(context).pop(),
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
}