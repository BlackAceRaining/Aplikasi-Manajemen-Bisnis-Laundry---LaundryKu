import 'package:flutter/foundation.dart';

class ApiConstants {
  /// Base URL API. Override saat build/run untuk device fisik:
  ///   flutter run --dart-define=API_BASE_URL=http://192.168.1.11:8000/api/v1
  ///   `flutter build apk --release --dart-define=API_BASE_URL=http://IP-LAPTOP:8000/api/v1`
  static const String _override =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (kIsWeb) {
      // Browser di mesin yang sama dengan server API.
      return 'http://127.0.0.1:8000/api/v1';
    }
    // Emulator Android -> 10.0.2.2 (= host laptop). HP fisik wajib pakai --dart-define.
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:8000/api/v1'
        : 'http://127.0.0.1:8000/api/v1';
  }
}
