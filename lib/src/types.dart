/// A single vibration segment.
class Vibration {
  /// Duration in milliseconds (clamped to 1000 ms max).
  final int duration;

  /// Intensity from 0.0 to 1.0. Defaults to the trigger-level intensity.
  final double? intensity;

  /// Delay in milliseconds before this vibration starts.
  final int? delay;

  const Vibration({
    required this.duration,
    this.intensity,
    this.delay,
  });
}

/// A named haptic preset containing a vibration pattern.
class HapticPreset {
  final List<Vibration> pattern;

  const HapticPreset({required this.pattern});
}

/// Options passed to [WebHaptics.trigger].
class TriggerOptions {
  /// Override intensity for the entire pattern (0.0 – 1.0, default 0.5).
  final double? intensity;

  const TriggerOptions({this.intensity});
}

/// Configuration for the [WebHaptics] instance.
class WebHapticsOptions {
  /// Enable audio feedback for desktop debugging.
  final bool debug;

  /// Show the hidden haptic feedback toggle switch in the DOM.
  final bool showSwitch;

  const WebHapticsOptions({
    this.debug = false,
    this.showSwitch = false,
  });
}
