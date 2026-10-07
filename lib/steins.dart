import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

import 'utils.dart';

class Steins {
  final String type;
  late final Map<String, dynamic> config;
  late final Map<String, dynamic> fileData;

  int pos = 1;
  int cid = 0;
  final Map<String, int> vars = {};

  Steins._(this.type);

  static Future<Steins> create(String type) async {
    final steins = Steins._(type);
    await steins._loadAssets();
    return steins;
  }

  /// A [Steins] over already decoded data, so the story logic can be tested
  /// without the asset bundle.
  @visibleForTesting
  factory Steins.fromData(
    String type,
    Map<String, dynamic> config,
    Map<String, dynamic> fileData,
  ) {
    final steins = Steins._(type);
    steins.config = config;
    steins.fileData = fileData;
    steins._initVars();
    return steins;
  }

  Future<void> _loadAssets() async {
    final configString = await rootBundle.loadString(
      'res/works/$type/config.json',
    );
    final fileString = await rootBundle.loadString('res/works/$type/file.json');

    final decodedConfig = jsonDecode(configString);
    final decodedFile = jsonDecode(fileString);

    if (decodedConfig is! Map<String, dynamic> ||
        decodedFile is! Map<String, dynamic>) {
      throw FormatException('Steins assets must contain valid JSON maps');
    }

    config = decodedConfig;
    fileData = decodedFile;

    _initVars();
  }

  void _initVars() {
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

  Map<String, dynamic>? proceed(String? actionLetter) {
    final node = _getCurrentNode();
    if (actionLetter == null) {
      if (node != null && node['type'] == 'direct') {
        _advanceDirectNodeOnce(node);
      }
      if (node != null && node['type'] == 'exit') {
        Utils.exitApp();
      }
      if (node == null || node['type'] == 'leaf' || node['type'] == 'choice') {
        return null;
      }
      _randomizeRandomVars();
      return currentState();
    }

    if (node != null && node['type'] == 'choice') {
      final options = _optionsFor(node);
      final choice = options[actionLetter];
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
    debugPrint(
      'proceed with action: $actionLetter, new pos: $pos, vars: $vars',
    );
    _randomizeRandomVars();
    return currentState();
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

  Map<String, dynamic> currentState() {
    final node = _getCurrentNode();
    final state = <String, dynamic>{
      'pos': pos,
      'title': node?['title']?.toString() ?? '',
      'cid': node?['cid'] ?? 0,
    };
    if (node != null && node['type'] == 'choice') {
      state.addAll(
        _optionsFor(
          node,
        ).map((key, choice) => MapEntry(key, choice['text']?.toString() ?? '')),
      );
    }
    return state;
  }

  String encodeSaveData() =>
      jsonEncode(<String, dynamic>{'type': type, 'pos': pos, 'vars': vars});

  Future<void> save(String filePath) async {
    final file = File(filePath);
    await file.writeAsString(encodeSaveData());
  }

  Future<Map<String, dynamic>?> load(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return null;
      }

      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      if (decoded['type'] != type) {
        return null;
      }

      final loadedPos = decoded['pos'];
      final loadedVars = decoded['vars'];
      if (loadedPos is! num || loadedVars is! Map<String, dynamic>) {
        return null;
      }

      final newVars = <String, int>{};
      for (final entry in loadedVars.entries) {
        final key = entry.key;
        final value = entry.value;
        if (value is! num) {
          return null;
        }
        newVars[key] = value.toInt();
      }

      if (!vars.keys.every(newVars.containsKey)) {
        return null;
      }

      pos = loadedPos.toInt();
      vars
        ..clear()
        ..addAll(newVars);
      return currentState();
    } catch (_) {
      return null;
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

  /// Options the player can pick at [node].
  ///
  /// A condition normally decides whether an option exists. When nothing at all
  /// is left, a *menu* (two or more declared options) is offered anyway: several
  /// works leave a gap in their conditions (e.g. random values of 100 in a node
  /// whose options cover 1-99), and ending the story there would drop the player
  /// out of the branch they are on. A *gate* (a single declared option) that does
  /// not match is a real ending - that is how the works mark an unreachable
  /// ending - so it stays hidden and the story ends.
  Map<String, Map<String, dynamic>> _optionsFor(Map<String, dynamic> node) {
    final available = _availableChoices(node);
    if (available.isNotEmpty) {
      return available;
    }
    final declared = _declaredChoices(node);
    if (declared.length > 1) {
      debugPrint(
        'no option matches at pos $pos, offering the ${declared.length} '
        'declared options of ${node['title']}',
      );
      return declared;
    }
    return const {};
  }

  Map<String, Map<String, dynamic>> _availableChoices(
    Map<String, dynamic> node,
  ) {
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

  /// Every option a node declares, whether its condition matches or not.
  Map<String, Map<String, dynamic>> _declaredChoices(
    Map<String, dynamic> node,
  ) {
    final result = <String, Map<String, dynamic>>{};
    for (final entry in node.entries) {
      final key = entry.key;
      if (key == 'title' || key == 'cid' || key == 'type' || key == 'pos') {
        continue;
      }
      final candidate = entry.value;
      if (candidate is Map<String, dynamic>) {
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
