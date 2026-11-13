import 'package:flutter/foundation.dart';

abstract final class ApiConfig {
  static const demo = bool.fromEnvironment('DEMO_MODE', defaultValue: false);
  static Uri get baseUri => Uri.parse(
    const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:8080',
    ),
  );
  static void validate(Uri uri) {
    const usbBackend = bool.fromEnvironment('USB_LOCAL_BACKEND');
    const wifiHost = String.fromEnvironment('WIFI_BACKEND_HOST');
    final localHttp = uri.scheme == 'http' &&
        ((kDebugMode && const ['10.0.2.2', '127.0.0.1', 'localhost'].contains(uri.host)) ||
         (usbBackend && const ['127.0.0.1', 'localhost'].contains(uri.host)) ||
         (wifiHost.isNotEmpty && uri.host == wifiHost));
    if ((!localHttp && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException(
        'Configure an HTTPS API_BASE_URL, or use a local development build.',
      );
    }
  }
}
