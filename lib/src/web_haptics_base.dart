import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import 'patterns.dart';
import 'types.dart';

// ---------------------------------------------------------------------------
// Constants (match the JS library)
// ---------------------------------------------------------------------------

const _toggleMin = 16; // ms at intensity 1 (every frame)
const _toggleMax = 184; // range above min
const _maxPhaseMs = 1000; // browser haptic-window limit
const _pwmCycle = 20; // ms per intensity-modulation cycle

// ---------------------------------------------------------------------------
// navigator.vibrate() interop
// ---------------------------------------------------------------------------

/// Extension type to access `navigator.vibrate()` which is not exposed by
/// `package:web`'s Navigator type.
extension type _VibratingNavigator(JSObject _) implements JSObject {
  external bool vibrate(JSAny pattern);
}

bool? _vibrateSupportedCache;

bool _checkVibrateSupported() {
  if (_vibrateSupportedCache != null) return _vibrateSupportedCache!;
  try {
    // vibrate(0) is a harmless cancel call used purely for feature detection.
    _VibratingNavigator(web.window.navigator as JSObject).vibrate(0.toJS);
    _vibrateSupportedCache = true;
  } catch (_) {
    _vibrateSupportedCache = false;
  }
  return _vibrateSupportedCache!;
}

void _vibrate(List<int> pattern) {
  final jsArr = pattern.map((e) => e.toJS).toList().toJS;
  _VibratingNavigator(web.window.navigator as JSObject).vibrate(jsArr);
}

void _vibrateCancel() {
  _VibratingNavigator(web.window.navigator as JSObject).vibrate(0.toJS);
}

// ---------------------------------------------------------------------------
// Input normalisation
// ---------------------------------------------------------------------------

List<Vibration>? _normalizeInput(Object? input) {
  if (input == null) {
    return [const Vibration(duration: 25, intensity: 0.7)];
  }

  if (input is String) {
    final preset = defaultPatterns[input];
    if (preset == null) {
      // ignore: avoid_print
      print('[web_haptics] Unknown preset: "$input"');
      return null;
    }
    return preset.pattern
        .map((v) => Vibration(
              duration: v.duration,
              intensity: v.intensity,
              delay: v.delay,
            ))
        .toList();
  }

  if (input is int) {
    return [Vibration(duration: input)];
  }

  if (input is List) {
    if (input.isEmpty) return [];

    if (input.first is int) {
      final nums = input.cast<int>();
      final vibrations = <Vibration>[];
      for (var i = 0; i < nums.length; i += 2) {
        final delay = i > 0 ? nums[i - 1] : 0;
        vibrations.add(Vibration(
          duration: nums[i],
          delay: delay > 0 ? delay : null,
        ));
      }
      return vibrations;
    }

    if (input.first is Vibration) {
      return input
          .cast<Vibration>()
          .map((v) => Vibration(
                duration: v.duration,
                intensity: v.intensity,
                delay: v.delay,
              ))
          .toList();
    }
  }

  if (input is HapticPreset) {
    return input.pattern
        .map((v) => Vibration(
              duration: v.duration,
              intensity: v.intensity,
              delay: v.delay,
            ))
        .toList();
  }

  return null;
}

// ---------------------------------------------------------------------------
// PWM modulation
// ---------------------------------------------------------------------------

/// Apply PWM modulation to simulate a given intensity.
List<int> _modulateVibration(int duration, double intensity) {
  if (intensity >= 1) return [duration];
  if (intensity <= 0) return [];

  final onTime = math.max(1, (_pwmCycle * intensity).round());
  final offTime = _pwmCycle - onTime;
  final result = <int>[];

  var remaining = duration;
  while (remaining >= _pwmCycle) {
    result.add(onTime);
    result.add(offTime);
    remaining -= _pwmCycle;
  }
  if (remaining > 0) {
    final remOn = math.max(1, (remaining * intensity).round());
    result.add(remOn);
    final remOff = remaining - remOn;
    if (remOff > 0) result.add(remOff);
  }

  return result;
}

/// Convert [Vibration] list to the flat `number[]` pattern for
/// `navigator.vibrate()`, applying per-vibration PWM intensity modulation.
List<int> _toVibratePattern(
    List<Vibration> vibrations, double defaultIntensity) {
  final result = <int>[];

  for (var i = 0; i < vibrations.length; i++) {
    final vib = vibrations[i];
    final intensity =
        (vib.intensity ?? defaultIntensity).clamp(0.0, 1.0);
    final delay = vib.delay ?? 0;

    // Prepend delay: merge into trailing off-time or add new gap.
    if (delay > 0) {
      if (result.isNotEmpty && result.length.isEven) {
        result[result.length - 1] += delay;
      } else {
        if (result.isEmpty) result.add(0);
        result.add(delay);
      }
    }

    final modulated = _modulateVibration(vib.duration, intensity);

    if (modulated.isEmpty) {
      // Zero intensity — treat as silence.
      if (result.isNotEmpty && result.length.isEven) {
        result[result.length - 1] += vib.duration;
      } else if (vib.duration > 0) {
        result.add(0);
        result.add(vib.duration);
      }
      continue;
    }

    result.addAll(modulated);
  }

  return result;
}

// ---------------------------------------------------------------------------
// Phase helper for the rAF-based pattern runner
// ---------------------------------------------------------------------------

class _Phase {
  final double end;
  final bool isOn;
  final double intensity;

  const _Phase(this.end, this.isOn, this.intensity);
}

// ---------------------------------------------------------------------------
// WebHaptics
// ---------------------------------------------------------------------------

var _instanceCounter = 0;

/// Provides haptic feedback on mobile web.
///
/// This is a Dart port of the
/// [web-haptics](https://github.com/lochie/web-haptics) JavaScript library
/// by [Lochie Axon](https://github.com/lochie).
///
/// On **iOS Safari** it uses the hidden `<input type="checkbox" switch>` trick
/// to fire the Taptic Engine. On **Android** it uses `navigator.vibrate()` with
/// PWM-based intensity modulation.
///
/// ```dart
/// final haptics = WebHaptics();
/// haptics.trigger('success');
/// haptics.trigger('medium');
/// haptics.trigger(100); // custom duration
/// ```
class WebHaptics {
  web.HTMLLabelElement? _hapticLabel;
  bool _domInitialized = false;
  final int _instanceId;
  bool _debug;
  bool _showSwitch;

  int? _rafId;
  Completer<void>? _patternCompleter;

  // Web Audio debug state
  web.AudioContext? _audioCtx;
  web.BiquadFilterNode? _audioFilter;
  web.GainNode? _audioGain;
  web.AudioBuffer? _audioBuffer;

  final math.Random _random = math.Random();

  WebHaptics({bool debug = false, bool showSwitch = false})
      : _instanceId = ++_instanceCounter,
        _debug = debug,
        _showSwitch = showSwitch;

  /// Whether `navigator.vibrate()` is available.
  static bool get isSupported => _checkVibrateSupported();

  /// Trigger haptic feedback.
  ///
  /// [input] accepts multiple formats:
  /// - `null` — default medium vibration
  /// - [String] — preset name (`'success'`, `'warning'`, `'error'`, …)
  /// - [int] — duration in milliseconds
  /// - `List<int>` — alternating vibrate/pause durations
  /// - `List<Vibration>` — vibration objects with intensity/delay
  /// - [HapticPreset] — a full preset object
  Future<void> trigger([Object? input, TriggerOptions? options]) async {
    final vibrations = _normalizeInput(input);
    if (vibrations == null || vibrations.isEmpty) return;

    final defaultIntensity = (options?.intensity ?? 0.5).clamp(0.0, 1.0);

    // Validate and clamp durations.
    for (final vib in vibrations) {
      if (vib.duration > _maxPhaseMs ||
          vib.duration < 0 ||
          !vib.duration.isFinite) {
        // ignore: avoid_print
        print('[web_haptics] Invalid vibration duration: ${vib.duration}');
        return;
      }
      if (vib.delay != null && (vib.delay! < 0 || !vib.delay!.isFinite)) {
        // ignore: avoid_print
        print('[web_haptics] Invalid vibration delay: ${vib.delay}');
        return;
      }
    }

    // Clamp durations in-place by creating a clamped copy.
    final clamped = vibrations
        .map((v) => Vibration(
              duration: v.duration.clamp(0, _maxPhaseMs),
              intensity: v.intensity,
              delay: v.delay,
            ))
        .toList();

    // Android / generic vibrate path.
    if (isSupported) {
      _vibrate(_toVibratePattern(clamped, defaultIntensity));
    }

    // iOS checkbox trick + optional debug audio.
    if (!isSupported || _debug) {
      _ensureDOM();
      if (_hapticLabel == null) return;

      if (_debug) {
        await _ensureAudio();
      }

      _stopPattern();

      final firstDelay = clamped.first.delay ?? 0;
      var firstClickFired = firstDelay == 0;

      // Fire the first click synchronously to stay inside the user-gesture
      // window (only when the first vibration has no delay).
      if (firstClickFired) {
        _hapticLabel!.click();
        if (_debug && _audioCtx != null) {
          final firstIntensity =
              (clamped.first.intensity ?? defaultIntensity).clamp(0.0, 1.0);
          _playClick(firstIntensity);
        }
      }

      await _runPattern(clamped, defaultIntensity, firstClickFired);
    }
  }

  /// Cancel any ongoing haptic pattern.
  void cancel() {
    _stopPattern();
    if (isSupported) {
      _vibrateCancel();
    }
  }

  /// Tear down DOM elements and audio resources.
  void destroy() {
    _stopPattern();
    if (_hapticLabel != null) {
      _hapticLabel!.remove();
      _hapticLabel = null;
      _domInitialized = false;
    }
    if (_audioCtx != null) {
      _audioCtx!.close();
      _audioCtx = null;
      _audioFilter = null;
      _audioGain = null;
      _audioBuffer = null;
    }
  }

  /// Enable or disable debug audio feedback.
  void setDebug(bool debug) {
    _debug = debug;
    if (!debug && _audioCtx != null) {
      _audioCtx!.close();
      _audioCtx = null;
      _audioFilter = null;
      _audioGain = null;
      _audioBuffer = null;
    }
  }

  /// Show or hide the haptic-feedback toggle switch.
  void setShowSwitch(bool show) {
    _showSwitch = show;
    if (_hapticLabel != null) {
      final checkbox = _hapticLabel!.querySelector('input');
      _hapticLabel!.style.display = show ? '' : 'none';
      if (checkbox != null) {
        (checkbox as web.HTMLElement).style.display = show ? '' : 'none';
      }
    }
  }

  // -----------------------------------------------------------------------
  // Private — pattern runner
  // -----------------------------------------------------------------------

  void _stopPattern() {
    if (_rafId != null) {
      web.window.cancelAnimationFrame(_rafId!);
      _rafId = null;
    }
    _patternCompleter?.complete();
    _patternCompleter = null;
  }

  Future<void> _runPattern(
    List<Vibration> vibrations,
    double defaultIntensity,
    bool firstClickFired,
  ) {
    final completer = Completer<void>();
    _patternCompleter = completer;

    // Build phase boundaries.
    final phases = <_Phase>[];
    var cumulative = 0.0;
    for (final vib in vibrations) {
      final intensity =
          (vib.intensity ?? defaultIntensity).clamp(0.0, 1.0);
      final delay = (vib.delay ?? 0).toDouble();
      if (delay > 0) {
        cumulative += delay;
        phases.add(_Phase(cumulative, false, 0));
      }
      cumulative += vib.duration;
      phases.add(_Phase(cumulative, true, intensity));
    }
    final totalDuration = cumulative;

    var startTime = 0.0;
    var lastToggleTime = -1.0;
    var localFirstClickFired = firstClickFired;

    late JSFunction jsLoop;
    jsLoop = ((JSNumber timeJS) {
      final time = timeJS.toDartDouble;
      if (startTime == 0) startTime = time;
      final elapsed = time - startTime;

      if (elapsed >= totalDuration) {
        _rafId = null;
        _patternCompleter = null;
        completer.complete();
        return;
      }

      // Find current phase.
      var phase = phases.first;
      for (final p in phases) {
        if (elapsed < p.end) {
          phase = p;
          break;
        }
      }

      if (phase.isOn) {
        final toggleInterval = _toggleMin + (1 - phase.intensity) * _toggleMax;

        if (lastToggleTime == -1) {
          lastToggleTime = time;
          if (!localFirstClickFired) {
            _hapticLabel?.click();
            if (_debug && _audioCtx != null) {
              _playClick(phase.intensity);
            }
            localFirstClickFired = true;
          }
        } else if (time - lastToggleTime >= toggleInterval) {
          _hapticLabel?.click();
          if (_debug && _audioCtx != null) {
            _playClick(phase.intensity);
          }
          lastToggleTime = time;
        }
      }

      _rafId = web.window.requestAnimationFrame(jsLoop);
    }).toJS;

    _rafId = web.window.requestAnimationFrame(jsLoop);
    return completer.future;
  }

  // -----------------------------------------------------------------------
  // Private — debug audio
  // -----------------------------------------------------------------------

  void _playClick(double intensity) {
    if (_audioCtx == null ||
        _audioFilter == null ||
        _audioGain == null ||
        _audioBuffer == null) {
      return;
    }

    final data = _audioBuffer!.getChannelData(0).toDart;
    for (var i = 0; i < data.length; i++) {
      data[i] = (_random.nextDouble() * 2 - 1) * math.exp(-i / 25.0);
    }

    _audioGain!.gain.value = 0.5 * intensity;

    final baseFreq = 2000 + intensity * 2000;
    final jitter = 1 + (_random.nextDouble() - 0.5) * 0.3;
    _audioFilter!.frequency.value = baseFreq * jitter;

    final source = _audioCtx!.createBufferSource();
    source.buffer = _audioBuffer;
    source.connect(_audioFilter!);
    source.addEventListener(
        'ended',
        ((web.Event _) {
          source.disconnect();
        }).toJS);
    source.start();
  }

  Future<void> _ensureAudio() async {
    if (_audioCtx == null) {
      _audioCtx = web.AudioContext();

      _audioFilter = _audioCtx!.createBiquadFilter();
      _audioFilter!.type = 'bandpass';
      _audioFilter!.frequency.value = 4000;
      _audioFilter!.Q.value = 8;

      _audioGain = _audioCtx!.createGain();
      _audioFilter!.connect(_audioGain!);
      _audioGain!.connect(_audioCtx!.destination);

      final sampleCount = (_audioCtx!.sampleRate * 0.004).round();
      _audioBuffer = _audioCtx!.createBuffer(1, sampleCount,
          _audioCtx!.sampleRate);
      final data = _audioBuffer!.getChannelData(0).toDart;
      for (var i = 0; i < data.length; i++) {
        data[i] = (_random.nextDouble() * 2 - 1) * math.exp(-i / 25.0);
      }
    }

    if (_audioCtx!.state == 'suspended') {
      await _audioCtx!.resume().toDart;
    }
  }

  // -----------------------------------------------------------------------
  // Private — DOM (hidden checkbox-switch trick for iOS Taptic Engine)
  // -----------------------------------------------------------------------

  void _ensureDOM() {
    if (_domInitialized) return;

    final id = 'web-haptics-$_instanceId';

    final hapticLabel =
        web.document.createElement('label') as web.HTMLLabelElement;
    hapticLabel.htmlFor = id;
    hapticLabel.textContent = 'Haptic feedback';
    hapticLabel.style.position = 'fixed';
    hapticLabel.style.bottom = '10px';
    hapticLabel.style.left = '10px';
    hapticLabel.style.padding = '5px 10px';
    hapticLabel.style.backgroundColor = 'rgba(0, 0, 0, 0.7)';
    hapticLabel.style.color = 'white';
    hapticLabel.style.fontFamily = 'sans-serif';
    hapticLabel.style.fontSize = '14px';
    hapticLabel.style.borderRadius = '4px';
    hapticLabel.style.zIndex = '9999';
    hapticLabel.style.setProperty('user-select', 'none');
    _hapticLabel = hapticLabel;

    final hapticCheckbox =
        web.document.createElement('input') as web.HTMLInputElement;
    hapticCheckbox.type = 'checkbox';
    hapticCheckbox.setAttribute('switch', '');
    hapticCheckbox.id = id;
    hapticCheckbox.style.setProperty('all', 'initial');
    hapticCheckbox.style.setProperty('appearance', 'auto');

    if (!_showSwitch) {
      hapticLabel.style.display = 'none';
      hapticCheckbox.style.display = 'none';
    }

    hapticLabel.appendChild(hapticCheckbox);
    web.document.body!.appendChild(hapticLabel);
    _domInitialized = true;
  }
}
