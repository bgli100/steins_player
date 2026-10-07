import 'package:flutter_test/flutter_test.dart';
import 'package:steins_player/segment_watchdog.dart';

void main() {
  const interval = Duration(milliseconds: 500);
  const end = Duration(minutes: 1);

  SegmentWatchdog detector() => SegmentWatchdog(
    interval: interval,
    stallTimeout: const Duration(milliseconds: 2500),
    endTolerance: const Duration(seconds: 2),
  );

  /// Feeds [count] identical samples of a playing segment.
  ///
  /// The very first sample of a position that differs from the previous one
  /// counts as progress, so a standstill needs stallTimeout / interval + 1
  /// samples to be reported.
  StallAction feed(
    SegmentWatchdog watchdog,
    int count, {
    required Duration position,
    Duration duration = end,
    bool playing = true,
    bool buffering = false,
  }) {
    var action = StallAction.none;
    for (var i = 0; i < count; i++) {
      action = watchdog.tick(
        position: position,
        duration: duration,
        playing: playing,
        buffering: buffering,
      );
    }
    return action;
  }

  test('a playing segment that advances is never stuck', () {
    final watchdog = detector();
    for (var second = 0; second < 30; second++) {
      final action = watchdog.tick(
        position: Duration(seconds: second),
        duration: end,
        playing: true,
        buffering: false,
      );
      expect(action, StallAction.none);
    }
  });

  test('a paused segment is never stuck', () {
    final watchdog = detector();
    expect(
      feed(
        watchdog,
        20,
        position: const Duration(seconds: 10),
        playing: false,
      ),
      StallAction.none,
    );
  });

  test('a buffering segment is never stuck', () {
    final watchdog = detector();
    expect(
      feed(
        watchdog,
        20,
        position: const Duration(seconds: 10),
        buffering: true,
      ),
      StallAction.none,
    );
  });

  test('a segment without a duration is never stuck', () {
    final watchdog = detector();
    expect(
      feed(watchdog, 20, position: Duration.zero, duration: Duration.zero),
      StallAction.none,
    );
  });

  test('a standstill just before the end settles the segment', () {
    final watchdog = detector();
    // 1 s short of the end, exactly what the stuck player page showed.
    final position = end - const Duration(seconds: 1);
    expect(feed(watchdog, 1, position: position), StallAction.none);
    expect(feed(watchdog, 4, position: position), StallAction.none);
    expect(feed(watchdog, 1, position: position), StallAction.settle);
  });

  test('a standstill at the very last frame settles the segment', () {
    final watchdog = detector();
    final position = end - const Duration(milliseconds: 200);
    expect(feed(watchdog, 1, position: position), StallAction.none);
    expect(feed(watchdog, 5, position: position), StallAction.settle);
  });

  test('a standstill mid-segment seeks, then reloads, then gives up', () {
    final watchdog = detector();
    const position = Duration(seconds: 10);
    expect(feed(watchdog, 1, position: position), StallAction.none);
    expect(feed(watchdog, 5, position: position), StallAction.seek);
    expect(feed(watchdog, 5, position: position), StallAction.reload);
    expect(feed(watchdog, 5, position: position), StallAction.giveUp);
    expect(watchdog.nudged, isTrue);
    expect(watchdog.reloaded, isTrue);
  });

  test('seeking back to the start is not mistaken for progress', () {
    final watchdog = detector();
    // A reload restarts the segment: position 0 is a standstill even though it
    // is the detector's initial value.
    expect(feed(watchdog, 5, position: Duration.zero), StallAction.seek);
  });

  test('progress after a stall clears it', () {
    final watchdog = detector();
    expect(
      feed(watchdog, 1, position: const Duration(seconds: 10)),
      StallAction.none,
    );
    expect(
      feed(watchdog, 4, position: const Duration(seconds: 10)),
      StallAction.none,
    );
    expect(
      feed(watchdog, 1, position: const Duration(seconds: 11)),
      StallAction.none,
    );
    expect(
      feed(watchdog, 5, position: const Duration(seconds: 11)),
      StallAction.seek,
    );
  });

  test('reset arms the detector for the next segment', () {
    final watchdog = detector();
    const position = Duration(seconds: 10);
    expect(feed(watchdog, 1, position: position), StallAction.none);
    expect(feed(watchdog, 5, position: position), StallAction.seek);
    watchdog.reset();
    expect(watchdog.nudged, isFalse);
    expect(watchdog.reloaded, isFalse);
    expect(feed(watchdog, 1, position: position), StallAction.none);
    expect(feed(watchdog, 4, position: position), StallAction.none);
    expect(feed(watchdog, 1, position: position), StallAction.seek);
  });

  test('a reload is only attempted once per segment', () {
    final watchdog = detector();
    const position = Duration(seconds: 10);
    expect(feed(watchdog, 1, position: position), StallAction.none);
    expect(feed(watchdog, 5, position: position), StallAction.seek);
    expect(feed(watchdog, 5, position: position), StallAction.reload);

    // The reload restarts the segment: the detector must not start the ladder
    // over, otherwise a segment that cannot play would be reloaded forever.
    watchdog.reset(retry: true);
    expect(watchdog.nudged, isTrue);
    expect(watchdog.reloaded, isTrue);
    expect(feed(watchdog, 1, position: position), StallAction.none);
    expect(feed(watchdog, 5, position: position), StallAction.giveUp);
  });

  test('a shorter stall timeout reacts sooner', () {
    final watchdog = SegmentWatchdog(
      interval: interval,
      stallTimeout: const Duration(milliseconds: 500),
      endTolerance: const Duration(seconds: 2),
    );
    final position = end - const Duration(seconds: 1);
    expect(feed(watchdog, 1, position: position), StallAction.none);
    expect(feed(watchdog, 1, position: position), StallAction.settle);
  });
}
