# web_haptics

Haptic feedback for Flutter web apps. A Dart port of the [web-haptics](https://github.com/lochie/web-haptics) JavaScript library by [Lochie Axon](https://github.com/lochie).

Works on **iOS Safari** (Taptic Engine) and **Android Chrome** (`navigator.vibrate()`), with an optional desktop debug mode that plays audio clicks.

## Try it

Open the [live demo](https://sbis04.github.io/flutter_web_haptics/) on your phone to feel each preset.

## How it works

| Platform | Mechanism |
|---|---|
| **iOS Safari** | A hidden `<input type="checkbox" switch>` + `<label>` is injected into the DOM. Clicking the label toggles the checkbox, which fires the Taptic Engine. Patterns are produced by timed repeated clicks via `requestAnimationFrame`. |
| **Android / Chrome** | `navigator.vibrate()` with PWM-based intensity modulation. Each vibration segment is broken into rapid on/off pulses to simulate intensity levels between 0 and 1. |
| **Desktop (debug)** | Web Audio API generates short bandpass-filtered noise clicks at the frequency and gain matching the requested intensity. |

## Installation

```yaml
dependencies:
  web_haptics: ^0.0.1
```

> **Note:** This package uses `package:web` and `dart:js_interop`. It only works on **Flutter web** (or Dart web) targets.

## Quick start

```dart
import 'package:web_haptics/web_haptics.dart';

final haptics = WebHaptics();

// Built-in presets
haptics.trigger('success');
haptics.trigger('warning');
haptics.trigger('error');
haptics.trigger('medium');

// Clean up when done
haptics.destroy();
```

## Usage

### Presets

Trigger any of the 11 built-in presets by name:

```dart
haptics.trigger('success');   // ascending double-tap
haptics.trigger('warning');   // two hesitant taps
haptics.trigger('error');     // three rapid harsh taps
haptics.trigger('light');     // minor impact
haptics.trigger('medium');    // standard interaction
haptics.trigger('heavy');     // significant interaction
haptics.trigger('soft');      // cushioned feel
haptics.trigger('rigid');     // crisp, precise feel
haptics.trigger('selection'); // subtle selection change
haptics.trigger('nudge');     // reminder nudge
haptics.trigger('buzz');      // extended continuous vibration
```

### Custom duration

```dart
haptics.trigger(100); // vibrate for 100 ms
```

### Alternating vibrate/pause pattern

```dart
haptics.trigger([100, 50, 200]); // 100ms on, 50ms off, 200ms on
```

### Vibration objects with intensity

```dart
haptics.trigger([
  Vibration(duration: 50, intensity: 0.8),
  Vibration(delay: 30, duration: 80, intensity: 0.4),
]);
```

### Full preset object

```dart
haptics.trigger(HapticPreset(pattern: [
  Vibration(duration: 20, intensity: 1.0),
  Vibration(delay: 40, duration: 20, intensity: 0.5),
]));
```

### Override intensity

```dart
haptics.trigger('success', TriggerOptions(intensity: 0.8));
```

### Cancel ongoing feedback

```dart
haptics.cancel();
```

## API

### `WebHaptics`

```dart
WebHaptics({bool debug = false, bool showSwitch = false})
```

| Parameter | Default | Description |
|---|---|---|
| `debug` | `false` | Play audio click sounds on desktop for testing. |
| `showSwitch` | `false` | Make the hidden checkbox switch visible in the DOM. |

### Methods

| Method | Description |
|---|---|
| `trigger([Object? input, TriggerOptions? options])` | Fire haptic feedback. Returns `Future<void>`. |
| `cancel()` | Stop any ongoing haptic pattern. |
| `destroy()` | Remove DOM elements and release audio resources. |
| `setDebug(bool debug)` | Toggle debug mode at runtime. |
| `setShowSwitch(bool show)` | Toggle switch visibility at runtime. |

### Static

| Property | Description |
|---|---|
| `WebHaptics.isSupported` | `true` if `navigator.vibrate()` is available (Android). On iOS the checkbox trick is used regardless. |

## Debug mode

Pass `debug: true` to hear click sounds on desktop browsers. This is useful for testing haptic patterns without a mobile device.

```dart
final haptics = WebHaptics(debug: true);
haptics.trigger('success'); // plays audio clicks
```

## Credits

This package is a Dart port of the [web-haptics](https://github.com/lochie/web-haptics) JavaScript library created by [Lochie Axon](https://github.com/lochie). The original library provides the iOS checkbox-switch trick, the PWM intensity modulation algorithm, and the built-in haptic presets that this package implements.

## License

MIT - see [LICENSE](LICENSE) for details.
