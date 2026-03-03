// ignore_for_file: unused_local_variable
import 'package:web_haptics/web_haptics.dart';

void main() {
  final haptics = WebHaptics();

  // Trigger a preset.
  haptics.trigger('success');
  haptics.trigger('warning');
  haptics.trigger('error');
  haptics.trigger('medium');

  // Custom duration (ms).
  haptics.trigger(100);

  // Alternating vibrate/pause pattern.
  haptics.trigger([100, 50, 200]);

  // Vibration objects with intensity.
  haptics.trigger([
    Vibration(duration: 50, intensity: 0.8),
    Vibration(delay: 30, duration: 80, intensity: 0.4),
  ]);

  // Full preset object.
  haptics.trigger(HapticPreset(pattern: [
    Vibration(duration: 20, intensity: 1),
    Vibration(delay: 40, duration: 20, intensity: 0.5),
  ]));

  // With trigger options.
  haptics.trigger('success', TriggerOptions(intensity: 0.8));

  // Cancel ongoing feedback.
  haptics.cancel();

  // Clean up.
  haptics.destroy();

  // Debug mode (plays audio clicks on desktop).
  final debugHaptics = WebHaptics(debug: true);
  debugHaptics.trigger('success');
}
