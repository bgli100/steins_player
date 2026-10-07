import 'package:flutter/foundation.dart';

/// What a stuck segment should do next.
enum StallAction {
  /// Playback is healthy (or paused) - nothing to do.
  none,

  /// Playback is standing still close to the end of the segment: the completion
  /// event never arrived, so the game has to settle the segment itself.
  settle,

  /// Playback is standing still somewhere else: a seek usually restarts the
  /// decoder.
  seek,

  /// The seek did not help: reload the segment.
  reload,

  /// Nothing helps - stop trying and leave the decision to the player.
  giveUp,
}

/// Watches playback progress and reports when a segment is stuck.
///
/// `media_kit`/mpv can keep reporting "playing" while nothing advances: a
/// hardware decoder that stops delivering frames, or a file whose last frames
/// never complete. Without this the game waits forever for a `completed` event
/// that never comes - the symptom is a frozen last frame with the progress bar
/// a second short of the end and an unresponsive play button.
class SegmentWatchdog {
  SegmentWatchdog({
    this.interval = const Duration(milliseconds: 500),
    this.stallTimeout = const Duration(milliseconds: 2500),
    this.endTolerance = const Duration(seconds: 2),
  });

  /// How often [tick] is called.
  final Duration interval;

  /// How long playback may stand still before it counts as stuck.
  final Duration stallTimeout;

  /// A standstill this close to the end of the segment is treated as the
  /// segment finishing rather than as a fault.
  final Duration endTolerance;

  Duration _lastPosition = Duration.zero;
  int _stalledTicks = 0;
  bool _nudged = false;
  bool _reloaded = false;

  /// Arms the detector for a segment that just started.
  ///
  /// [retry] keeps the recovery attempts already spent, so a segment that was
  /// reloaded once and stalled again is left alone instead of being reloaded
  /// over and over.
  void reset({bool retry = false}) {
    _lastPosition = Duration.zero;
    _stalledTicks = 0;
    _nudged = retry;
    _reloaded = retry;
  }

  /// Feeds one sample of the player state and returns what to do about it.
  StallAction tick({
    required Duration position,
    required Duration duration,
    required bool playing,
    required bool buffering,
  }) {
    if (position != _lastPosition) {
      _lastPosition = position;
      _stalledTicks = 0;
      return StallAction.none;
    }
    // A paused or buffering player is not stuck, and neither is a player that
    // has not been given a duration yet.
    if (!playing || buffering || duration <= Duration.zero) {
      _stalledTicks = 0;
      return StallAction.none;
    }
    _stalledTicks++;
    if (_stalledTicks * interval.inMilliseconds < stallTimeout.inMilliseconds) {
      return StallAction.none;
    }
    _stalledTicks = 0;
    if (duration - position <= endTolerance) {
      return StallAction.settle;
    }
    if (!_nudged) {
      _nudged = true;
      return StallAction.seek;
    }
    if (!_reloaded) {
      _reloaded = true;
      return StallAction.reload;
    }
    return StallAction.giveUp;
  }

  @visibleForTesting
  bool get nudged => _nudged;

  @visibleForTesting
  bool get reloaded => _reloaded;
}
