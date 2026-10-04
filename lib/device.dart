import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Platform facts the Android build needs before it configures a video output.
///
/// media_kit only recognises the stock emulators (its check is based on
/// `Build.BRAND`/`FINGERPRINT`/...), so the ones that spoof a real phone slip
/// through: MuMu/YXArkNights reports itself as a vivo V2185A while running on
/// an x86_64 host. [isEmulator] therefore comes from the native side, which
/// looks for what such emulators cannot hide.
class Device {
  static const MethodChannel _channel = MethodChannel('lullaby/device');

  static bool _isEmulator = false;

  /// Whether this device appears to be an emulator. Always `false` outside
  /// Android, where the question does not apply.
  static bool get isEmulator => _isEmulator;

  /// Resolves [isEmulator]. Call once during startup, before the first
  /// [VideoController] is created.
  static Future<void> init() async {
    if (!Platform.isAndroid) return;
    try {
      _isEmulator = await _channel.invokeMethod<bool>('isEmulator') ?? false;
    } on PlatformException catch (error) {
      debugPrint('device: emulator check failed: $error');
    }
    debugPrint('device: emulator=$_isEmulator');
  }
}
