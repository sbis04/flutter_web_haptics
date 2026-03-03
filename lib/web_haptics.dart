/// Haptic feedback for Flutter web apps.
///
/// A Dart port of the [web-haptics](https://github.com/lochie/web-haptics)
/// JavaScript library by Lochie Axon. Uses the iOS Taptic Engine via the hidden
/// checkbox-switch trick and `navigator.vibrate()` as the Android fallback.
library;

export 'src/types.dart';
export 'src/patterns.dart' show defaultPatterns;
export 'src/web_haptics_base.dart' show WebHaptics;
