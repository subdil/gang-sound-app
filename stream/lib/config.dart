import 'package:flutter/foundation.dart';

// Point this at your deployed backend (or pass --dart-define=API_URL=https://api.example.com)
const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:4000');
// Bump this with every release; the update system compares against it
const appVersion = '1.0.0';

String get platformName {
  if (kIsWeb) return 'web';
  switch (defaultTargetPlatform) {
    case TargetPlatform.android: return 'android';
    case TargetPlatform.iOS: return 'ios';
    case TargetPlatform.windows: return 'windows';
    case TargetPlatform.macOS: return 'macos';
    case TargetPlatform.linux: return 'linux';
    default: return 'other';
  }
}
