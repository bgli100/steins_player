import 'package:flutter_test/flutter_test.dart';
import 'package:steins_player/steins.dart';

/// Builds a work with three nodes:
///
///  * `1` - a choice node whose options depend on the variables,
///  * `2`/`3` - the nodes those options lead to.
Map<String, dynamic> workWith(Map<String, dynamic> node) => {
  '1': node,
  '2': {'title': 'left', 'cid': 2, 'type': 'leaf'},
  '3': {'title': 'right', 'cid': 3, 'type': 'leaf'},
};

Map<String, dynamic> configWith({Map<String, dynamic>? vars}) => {
  'vars':
      vars ??
      {
        'C': {'name': 'info', 'type': 'normal', 'value': 0},
      },
};

Steins steinsFor(
  Map<String, dynamic> node, {
  Map<String, dynamic>? vars,
}) => Steins.fromData(
  'test',
  configWith(vars: vars),
  workWith(node),
);

void main() {
  test('options whose condition matches are offered', () {
    final steins = steinsFor({
      'title': 'gate',
      'cid': 1,
      'type': 'choice',
      'A': {
        'text': 'only when C >= 90',
        'pos': '2',
        'condition': [
          {'var': 'C', 'op': 'ge', 'num': 90},
        ],
      },
    }, vars: {
      'C': {'name': 'info', 'type': 'normal', 'value': 95},
    });

    final state = steins.currentState();
    expect(state['A'], 'only when C >= 90');
    expect(steins.proceed('A'), isNotNull);
    expect(steins.pos, 2);
  });

  test('a gate that does not match has no option and ends the story', () {
    final steins = steinsFor({
      'title': 'E ending',
      'cid': 1,
      'type': 'choice',
      'A': {
        'text': 'reach the E ending',
        'pos': '2',
        'condition': [
          {'var': 'C', 'op': 'gt', 'num': 90},
        ],
      },
    });

    final state = steins.currentState();
    expect(state.containsKey('A'), isFalse);
    // The player settles the segment, sees no option and asks for the next
    // segment - which a choice node cannot provide, so the story ends there.
    expect(steins.proceed(null), isNull);
  });

  test('a menu without a matching option is still offered', () {
    // Mirrors the works whose random variable can land outside the buckets the
    // options cover (e.g. 100 in a node covering 1-99): the branch continues
    // instead of dropping the player out of the story.
    final steins = steinsFor({
      'title': 'sleep',
      'cid': 1,
      'type': 'choice',
      'A': {
        'text': 'sleep 1-24',
        'pos': '2',
        'condition': [
          {'var': 'R', 'op': 'ge', 'num': 1},
          {'var': 'R', 'op': 'le', 'num': 24},
        ],
      },
      'B': {
        'text': 'sleep 25-49',
        'pos': '3',
        'condition': [
          {'var': 'R', 'op': 'ge', 'num': 25},
          {'var': 'R', 'op': 'le', 'num': 49},
        ],
      },
    }, vars: {
      // The real works roll 1-100 while their options cover 1-99, so 100
      // matches nothing.
      'R': {'name': 'roll', 'type': 'normal', 'value': 100},
    });

    final state = steins.currentState();
    expect(state['A'], 'sleep 1-24');
    expect(state['B'], 'sleep 25-49');

    // The fallback options are selectable as well, otherwise the menu would
    // show buttons that do nothing.
    expect(steins.proceed('B'), isNotNull);
    expect(steins.pos, 3);
  });

  test('a metadata key such as a default choice is not an option', () {
    final steins = steinsFor({
      'title': 'default',
      'cid': 1,
      'type': 'choice',
      'A': {'text': 'default branch', 'pos': '2'},
      'default': 'A',
    });

    final state = steins.currentState();
    expect(state['A'], 'default branch');
    expect(state.containsKey('default'), isFalse);
  });

  test('choosing an option applies its changes and moves on', () {
    final steins = steinsFor({
      'title': 'change',
      'cid': 1,
      'type': 'choice',
      'A': {
        'text': 'add information',
        'pos': '2',
        'change': [
          {'var': 'C', 'op': 'add', 'num': 5},
        ],
      },
    });

    steins.proceed('A');
    expect(steins.pos, 2);
    expect(steins.vars['C'], 5);
  });

  test('a direct node advances to its target', () {
    final steins = Steins.fromData('test', configWith(), {
      '1': {'title': 'intro', 'cid': 1, 'type': 'direct', 'pos': '2'},
      '2': {'title': 'next', 'cid': 2, 'type': 'leaf'},
    });

    final state = steins.proceed(null);
    expect(state, isNotNull);
    expect(state!['pos'], 2);
    expect(state['title'], 'next');
  });

  test('a leaf node reports the end of the story', () {
    final steins = Steins.fromData('test', configWith(), {
      '1': {'title': 'ending', 'cid': 1, 'type': 'leaf'},
    });

    expect(steins.proceed(null), isNull);
  });
}
