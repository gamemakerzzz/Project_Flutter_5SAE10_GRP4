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
    final localDebug =
        kDebugMode &&
        uri.scheme == 'http' &&
        const ['10.0.2.2', '127.0.0.1', 'localhost'].contains(uri.host);
    if ((!localDebug && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException(
        'Configure an HTTPS API_BASE_URL. Local HTTP is supported only in debug mode.',
      );
    }
  }
}
