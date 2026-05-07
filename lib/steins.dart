import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';

class Steins {
  final String type;
  late final Map<String, dynamic> config;
  late final Map<String, dynamic> fileData;

  int pos = 1;
  final Map<String, int> vars = {};

  Steins._(this.type);

  static Future<Steins> create(String type) async {
    final steins = Steins._(type);
    await steins._loadAssets();
    return steins;
  }

  Future<void> _loadAssets() async {
    final configString = await rootBundle.loadString('res/$type/config.json');
    final fileString = await rootBundle.loadString('res/$type/file.json');

    final decodedConfig = jsonDecode(configString);
    final decodedFile = jsonDecode(fileString);

    if (decodedConfig is! Map<String, dynamic> || decodedFile is! Map<String, dynamic>) {
      throw FormatException('Steins assets must contain valid JSON maps');
    }

    config = decodedConfig;
    fileData = decodedFile;

    vars.clear();

    final rawVars = config['vars'];
    if (rawVars is Map<String, dynamic>) {
      for (final entry in rawVars.entries) {
        final value = entry.value;
        if (value is Map<String, dynamic>) {
          if (value['type'] == 'random') {
            vars[entry.key] = 1 + Random().nextInt(100);
            continue;
          }
          final initialValue = value['value'];
          vars[entry.key] = _toInt(initialValue);
        } else {
          vars[entry.key] = 0;
        }
      }
    }
  }

  Map<String, dynamic> proceed(String? actionLetter) {
    _randomizeRandomVars();

    final node = _getCurrentNode();
    if (actionLetter == null) {
      if (node != null && node['type'] == 'direct') {
        _advanceDirectNodeOnce(node);
      }
      return _currentState();
    }

    if (node != null && node['type'] == 'choice') {
      final available = _availableChoices(node);
      final choice = available[actionLetter];
      if (choice != null) {
        _applyChange(choice['change']);
        final nextPos = choice['pos'];
        if (nextPos != null) {
          final parsed = int.tryParse(nextPos.toString());
          if (parsed != null) {
            pos = parsed;
          }
        }
      }
    }
    return _currentState();
  }

  void _advanceDirectNodeOnce(Map<String, dynamic> node) {
    final nextPos = node['pos'];
    if (nextPos == null) {
      return;
    }
    final parsed = int.tryParse(nextPos.toString());
    if (parsed != null) {
      pos = parsed;
    }
  }

  Map<String, dynamic> _currentState() {
    final node = _getCurrentNode();
    final state = <String, dynamic>{
      'pos': pos,
      'title': node?['title']?.toString() ?? '',
    };
    if (node != null && node['type'] == 'choice') {
      state.addAll(_availableChoices(node).map((key, choice) => MapEntry(key, choice['text']?.toString() ?? '')));
    }
    return state;
  }

  Future<void> save(String filePath) async {
    final saveData = <String, dynamic>{
      'type': type,
      'pos': pos,
      'vars': vars,
    };
    final file = File(filePath);
    await file.writeAsString(jsonEncode(saveData));
  }

  Future<int> load(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return 0;
      }

      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return 0;
      }

      if (decoded['type'] != type) {
        return 0;
      }

      final loadedPos = decoded['pos'];
      final loadedVars = decoded['vars'];
      if (loadedPos is! num || loadedVars is! Map<String, dynamic>) {
        return 0;
      }

      final newVars = <String, int>{};
      for (final entry in loadedVars.entries) {
        final key = entry.key;
        final value = entry.value;
        if (value is! num) {
          return 0;
        }
        newVars[key] = value.toInt();
      }

      if (!vars.keys.every(newVars.containsKey)) {
        return 0;
      }

      pos = loadedPos.toInt();
      vars
        ..clear()
        ..addAll(newVars);
      return pos;
    } catch (_) {
      return 0;
    }
  }

  Map<String, dynamic>? _getCurrentNode() {
    return fileData[pos.toString()] as Map<String, dynamic>?;
  }

  void _randomizeRandomVars() {
    final rawVars = config['vars'];
    if (rawVars is Map<String, dynamic>) {
      for (final entry in rawVars.entries) {
        final value = entry.value;
        if (value is Map<String, dynamic> && value['type'] == 'random') {
          vars[entry.key] = 1 + Random().nextInt(100);
        }
      }
    }
  }

  Map<String, Map<String, dynamic>> visiableVars() {
    final result = <String, Map<String, dynamic>>{};
    final rawVars = config['vars'];
    if (rawVars is Map<String, dynamic>) {
      for (final entry in rawVars.entries) {
        final key = entry.key;
        final value = entry.value;
        if (value is Map<String, dynamic> && value['is_show'] == true) {
          result[key] = {
            'name': value['name']?.toString() ?? key,
            'value': vars[key] ?? 0,
          };
        }
      }
    }
    return result;
  }

  Map<String, Map<String, dynamic>> _availableChoices(Map<String, dynamic> node) {
    final result = <String, Map<String, dynamic>>{};
    for (final entry in node.entries) {
      final key = entry.key;
      if (key == 'title' || key == 'cid' || key == 'type' || key == 'pos') {
        continue;
      }
      final candidate = entry.value;
      if (candidate is Map<String, dynamic> && _choiceIsAvailable(candidate)) {
        result[key] = candidate;
      }
    }
    return result;
  }

  bool _choiceIsAvailable(Map<String, dynamic> choice) {
    final condition = choice['condition'];
    if (condition == null) {
      return true;
    }
    if (condition is List) {
      for (final rawCond in condition) {
        if (rawCond is! Map<String, dynamic>) {
          return false;
        }
        final variable = rawCond['var']?.toString();
        final op = rawCond['op']?.toString();
        final numValue = rawCond['num'];
        if (variable == null || op == null || numValue is! num) {
          return false;
        }
        if (!_evaluateCondition(variable, op, numValue.toInt())) {
          return false;
        }
      }
      return true;
    }
    return false;
  }

  bool _evaluateCondition(String variable, String op, int numValue) {
    final currentValue = vars[variable] ?? 0;
    switch (op) {
      case 'eq':
        return currentValue == numValue;
      case 'ne':
        return currentValue != numValue;
      case 'gt':
        return currentValue > numValue;
      case 'ge':
        return currentValue >= numValue;
      case 'lt':
        return currentValue < numValue;
      case 'le':
        return currentValue <= numValue;
      default:
        return false;
    }
  }

  void _applyChange(dynamic changeSpec) {
    if (changeSpec is! List) {
      return;
    }
    for (final rawChange in changeSpec) {
      if (rawChange is! Map<String, dynamic>) {
        continue;
      }
      final variable = rawChange['var']?.toString();
      final op = rawChange['op']?.toString();
      final numValue = rawChange['num'];
      if (variable == null || op == null || numValue is! num) {
        continue;
      }
      final currentValue = vars[variable] ?? 0;
      switch (op) {
        case 'set':
          vars[variable] = numValue.toInt();
          break;
        case 'add':
          vars[variable] = currentValue + numValue.toInt();
          break;
        case 'sub':
          vars[variable] = currentValue - numValue.toInt();
          break;
        case 'mul':
          vars[variable] = currentValue * numValue.toInt();
          break;
        case 'div':
          final divisor = numValue.toInt();
          if (divisor != 0) {
            vars[variable] = currentValue ~/ divisor;
          }
          break;
      }
    }
  }

  int _toInt(dynamic raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    if (raw is String) {
      return int.tryParse(raw) ?? 0;
    }
    return 0;
  }
}
