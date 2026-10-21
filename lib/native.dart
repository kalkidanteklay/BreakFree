import 'package:flutter/services.dart';

/// Mirrors Prefs.MODE_* constants on the native side.
enum BreakFreeMode {
  off(0),
  level1Timer(1),
  level2Strict(2),
  level3Strict(3);

  final int value;
  const BreakFreeMode(this.value);

  static BreakFreeMode fromValue(int value) =>
      BreakFreeMode.values.firstWhere(
        (m) => m.value == value,
        orElse: () => BreakFreeMode.off,
      );
}

class AppState {
  const AppState({
    required this.mode,
    required this.quotaMin,
    required this.usedTodayMs,
    required this.serviceEnabled,
    required this.overlayGranted,
  });

  final BreakFreeMode mode;
  final int quotaMin;
  final int usedTodayMs;
  final bool serviceEnabled;
  final bool overlayGranted;

  int get quotaMs => quotaMin * 60 * 1000;

  bool get isBlocked => usedTodayMs >= quotaMs;

  double get usedFraction =>
      quotaMs <= 0 ? 0 : (usedTodayMs / quotaMs).clamp(0.0, 1.0);

  factory AppState.fromMap(Map<dynamic, dynamic> map) {
    return AppState(
      mode: BreakFreeMode.fromValue((map['mode'] as int?) ?? 0),
      quotaMin: (map['quotaMin'] as int?) ?? 30,
      usedTodayMs: (map['usedTodayMs'] as int?) ?? 0,
      serviceEnabled: (map['serviceEnabled'] as bool?) ?? false,
      overlayGranted: (map['overlayGranted'] as bool?) ?? false,
    );
  }

  static const idle = AppState(
    mode: BreakFreeMode.off,
    quotaMin: 30,
    usedTodayMs: 0,
    serviceEnabled: false,
    overlayGranted: false,
  );
}

class NativeApi {
  static const MethodChannel _channel =
      MethodChannel('com.example.breakfree/native');

  static Future<AppState> getState() async {
    try {
      final map = await _channel.invokeMapMethod<dynamic, dynamic>('getState');
      if (map == null) return AppState.idle;
      return AppState.fromMap(map);
    } on PlatformException catch (_) {
      return AppState.idle;
    } on MissingPluginException catch (_) {
      return AppState.idle;
    }
  }

  static Future<void> setMode(BreakFreeMode mode) async {
    await _channel.invokeMethod('setMode', {'mode': mode.value});
  }

  static Future<void> setQuota(int minutes) async {
    await _channel.invokeMethod('setQuota', {'minutes': minutes});
  }

  static Future<void> openAccessibilitySettings() async {
    await _channel.invokeMethod('openAccessibilitySettings');
  }

  static Future<void> openOverlaySettings() async {
    await _channel.invokeMethod('openOverlaySettings');
  }
}