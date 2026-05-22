import 'package:flutter/foundation.dart';

class ApiConfig {
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const _productionBaseUrl = String.fromEnvironment(
    'PRODUCTION_API_BASE_URL',
    defaultValue: 'https://edi-3792.onrender.com',
  );

  static final String baseUrl = _normalizeBaseUrl(
    _configuredBaseUrl.isNotEmpty
        ? _configuredBaseUrl
        : kReleaseMode
        ? _productionBaseUrl
        : _debugBaseUrl(),
  );

  static void logSelectedBackend() {
    debugPrint('ProctorAI backend URL: $baseUrl');
    debugPrint('ProctorAI websocket URL: $webSocketBaseUrl');
  }

  static String get webSocketBaseUrl {
    final base = Uri.parse(baseUrl);
    return base
        .replace(scheme: base.scheme == 'https' ? 'wss' : 'ws')
        .toString();
  }

  static String webSocketUrl(String path, {String? token}) {
    final base = Uri.parse(webSocketBaseUrl);
    return base
        .replace(
          path: '${base.path}${path.startsWith('/') ? path : '/$path'}',
          queryParameters: {
            if (token != null && token.isNotEmpty) 'token': token,
          },
        )
        .toString();
  }

  static String _normalizeBaseUrl(String value) {
    return value.trim().replaceFirst(RegExp(r'/$'), '');
  }

  static String _debugBaseUrl() {
    final browserOrigin = Uri.base;
    return browserOrigin
        .replace(scheme: 'http', port: 8000, path: '', query: '', fragment: '')
        .toString();
  }
}
