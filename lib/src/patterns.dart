import 'types.dart';

/// Built-in haptic presets mirroring iOS UIKit feedback generators.
///
/// These patterns are ported from the
/// [web-haptics](https://github.com/lochie/web-haptics) library by Lochie Axon.
const defaultPatterns = <String, HapticPreset>{
  // --- Notification (UINotificationFeedbackGenerator) ---
  'success': HapticPreset(pattern: [
    Vibration(duration: 30, intensity: 0.5),
    Vibration(delay: 60, duration: 40, intensity: 1),
  ]),
  'warning': HapticPreset(pattern: [
    Vibration(duration: 40, intensity: 0.8),
    Vibration(delay: 100, duration: 40, intensity: 0.6),
  ]),
  'error': HapticPreset(pattern: [
    Vibration(duration: 40, intensity: 0.9),
    Vibration(delay: 40, duration: 40, intensity: 0.9),
    Vibration(delay: 40, duration: 40, intensity: 0.9),
  ]),

  // --- Impact (UIImpactFeedbackGenerator) ---
  'light': HapticPreset(pattern: [
    Vibration(duration: 15, intensity: 0.4),
  ]),
  'medium': HapticPreset(pattern: [
    Vibration(duration: 25, intensity: 0.7),
  ]),
  'heavy': HapticPreset(pattern: [
    Vibration(duration: 35, intensity: 1),
  ]),
  'soft': HapticPreset(pattern: [
    Vibration(duration: 40, intensity: 0.5),
  ]),
  'rigid': HapticPreset(pattern: [
    Vibration(duration: 10, intensity: 1),
  ]),

  // --- Selection (UISelectionFeedbackGenerator) ---
  'selection': HapticPreset(pattern: [
    Vibration(duration: 8, intensity: 0.3),
  ]),

  // --- Custom ---
  'nudge': HapticPreset(pattern: [
    Vibration(duration: 80, intensity: 0.8),
    Vibration(delay: 80, duration: 50, intensity: 0.3),
  ]),
  'buzz': HapticPreset(pattern: [
    Vibration(duration: 1000, intensity: 1),
  ]),
};
