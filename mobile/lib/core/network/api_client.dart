import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../storage/token_storage.dart';

/// Low-level HTTP request structure for pluggable transport execution.
class RawHttpRequest {
  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final String? body;
  final Duration timeout;

  const RawHttpRequest({
    required this.method,
    required this.uri,
    required this.headers,
    this.body,
    required this.timeout,
  });
}

/// Low-level HTTP response structure returned by [HttpTransport].
class RawHttpResponse {
  final int statusCode;
  final String body;
  final Map<String, String> headers;

  const RawHttpResponse({
    required this.statusCode,
    required this.body,
    this.headers = const {},
  });
}

typedef HttpTransport = Future<RawHttpResponse> Function(RawHttpRequest request);

/// Standardized exception thrown by [ApiClient] on HTTP or transport errors.
class ApiClientException implements Exception {
  final int? statusCode;
  final String message;
  final Map<String, dynamic>? validationErrors;

  const ApiClientException({
    this.statusCode,
    required this.message,
    this.validationErrors,
  });

  /// Maps HTTP status codes and transport errors to safe, accessible user-facing strings.
  /// Never exposes stack traces, SQL, or credentials.
  String toUserFriendlyMessage() {
    switch (statusCode) {
      case 400:
        if (validationErrors != null && validationErrors!.isNotEmpty) {
          return validationErrors!.values.map((v) => v.toString()).join(' ');
        }
        return message.isNotEmpty ? message : 'Invalid input values.';
      case 401:
        return 'Your session has expired. Please sign in again.';
      case 403:
        return "You no longer have permission to view this user's information.";
      case 404:
        return message.isNotEmpty && message != 'Not Found'
            ? message
            : 'The requested information is unavailable.';
      case 409:
        return message.isNotEmpty ? message : 'Action conflict or invalid transition.';
      default:
        if (statusCode != null && statusCode! >= 500) {
          return 'Service temporarily unavailable. Please try again.';
        }
        return message.isNotEmpty ? message : 'Network communication error.';
    }
  }

  @override
  String toString() => 'ApiClientException(status: $statusCode, message: $message)';
}

/// Centralized REST API Client for the SAHAYAK Flutter Platform.
///
/// Features:
/// - Base URL & timeout configuration
/// - Automatic JWT Bearer header injection
/// - Transparent 401 refresh-token rotation and single-request retry
/// - Standardized ApiResponse / ErrorResponse JSON parsing
class ApiClient {
  final String baseUrl;
  final TokenStorage tokenStorage;
  final Duration timeout;
  final HttpTransport _transport;
  final void Function()? onSessionExpired;

  bool _isRefreshing = false;

  ApiClient({
    required this.baseUrl,
    required this.tokenStorage,
    this.timeout = const Duration(seconds: 15),
    HttpTransport? transport,
    this.onSessionExpired,
  }) : _transport = transport ?? _defaultDartIoTransport;

  Future<Map<String, dynamic>> get(
    String path, {
    bool requiresAuth = true,
    Map<String, String>? extraHeaders,
  }) {
    return _sendRequest(
      method: 'GET',
      path: path,
      requiresAuth: requiresAuth,
      extraHeaders: extraHeaders,
    );
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
    Map<String, String>? extraHeaders,
  }) {
    return _sendRequest(
      method: 'POST',
      path: path,
      body: body,
      requiresAuth: requiresAuth,
      extraHeaders: extraHeaders,
    );
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
    Map<String, String>? extraHeaders,
  }) {
    return _sendRequest(
      method: 'PUT',
      path: path,
      body: body,
      requiresAuth: requiresAuth,
      extraHeaders: extraHeaders,
    );
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
    Map<String, String>? extraHeaders,
  }) {
    return _sendRequest(
      method: 'PATCH',
      path: path,
      body: body,
      requiresAuth: requiresAuth,
      extraHeaders: extraHeaders,
    );
  }

  Future<Map<String, dynamic>> _sendRequest({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    required bool requiresAuth,
    Map<String, String>? extraHeaders,
    bool isRetry = false,
  }) async {
    final uri = _resolveUri(path);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (extraHeaders != null) ...extraHeaders,
    };

    if (requiresAuth) {
      final accessToken = await tokenStorage.readAccessToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $accessToken';
      }
    }

    final rawRequest = RawHttpRequest(
      method: method,
      uri: uri,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
      timeout: timeout,
    );

    final RawHttpResponse response;
    try {
      response = await _transport(rawRequest);
    } on TimeoutException {
      throw const ApiClientException(message: 'Network request timed out');
    } catch (_) {
      throw const ApiClientException(message: 'Network communication error');
    }

    // Handle 401 Unauthorized via automatic refresh-token flow (once per request)
    if (response.statusCode == 401 && requiresAuth && !isRetry && !_isAuthRefreshPath(path)) {
      final refreshed = await tryRefreshSession();
      if (refreshed) {
        return _sendRequest(
          method: method,
          path: path,
          body: body,
          requiresAuth: requiresAuth,
          extraHeaders: extraHeaders,
          isRetry: true,
        );
      } else {
        onSessionExpired?.call();
      }
    }

    final Map<String, dynamic> decoded = _decodeJsonSafely(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final errorMessage = decoded['message'] as String? ?? 'Request failed with status ${response.statusCode}';
    final validationErrors = decoded['validationErrors'] is Map<String, dynamic>
        ? decoded['validationErrors'] as Map<String, dynamic>
        : null;

    throw ApiClientException(
      statusCode: response.statusCode,
      message: errorMessage,
      validationErrors: validationErrors,
    );
  }

  /// Attempts to rotate the stored refresh token via POST /api/v1/auth/refresh.
  /// Never logs tokens. Clears tokens on failure.
  Future<bool> tryRefreshSession() async {
    if (_isRefreshing) {
      return false;
    }
    _isRefreshing = true;
    try {
      final refreshToken = await tokenStorage.readRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        await tokenStorage.clearTokens();
        return false;
      }

      final refreshRequest = RawHttpRequest(
        method: 'POST',
        uri: _resolveUri('/api/v1/auth/refresh'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'refreshToken': refreshToken}),
        timeout: timeout,
      );

      final response = await _transport(refreshRequest);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = _decodeJsonSafely(response.body);
        final data = decoded['data'];
        if (data is Map<String, dynamic>) {
          final newAccess = data['accessToken'] as String?;
          final newRefresh = data['refreshToken'] as String?;
          if (newAccess != null &&
              newAccess.isNotEmpty &&
              newRefresh != null &&
              newRefresh.isNotEmpty) {
            await tokenStorage.saveTokens(
              accessToken: newAccess,
              refreshToken: newRefresh,
            );
            return true;
          }
        }
      }

      await tokenStorage.clearTokens();
      return false;
    } catch (_) {
      await tokenStorage.clearTokens();
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  Uri _resolveUri(String path) {
    final normalizedBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$normalizedBase$normalizedPath');
  }

  bool _isAuthRefreshPath(String path) => path.contains('/api/v1/auth/refresh');

  Map<String, dynamic> _decodeJsonSafely(String rawBody) {
    if (rawBody.trim().isEmpty) {
      return <String, dynamic>{};
    }
    try {
      final parsed = jsonDecode(rawBody);
      if (parsed is Map<String, dynamic>) {
        return parsed;
      }
      return <String, dynamic>{'data': parsed};
    } catch (_) {
      return <String, dynamic>{'message': 'Malformed JSON response'};
    }
  }

  static Future<RawHttpResponse> _defaultDartIoTransport(RawHttpRequest request) async {
    final client = HttpClient()..connectionTimeout = request.timeout;
    try {
      final ioRequest = await client.openUrl(request.method, request.uri).timeout(request.timeout);
      request.headers.forEach(ioRequest.headers.set);
      if (request.body != null) {
        final encoded = utf8.encode(request.body!);
        ioRequest.contentLength = encoded.length;
        ioRequest.add(encoded);
      }
      final ioResponse = await ioRequest.close().timeout(request.timeout);
      final responseBody = await ioResponse.transform(utf8.decoder).join().timeout(request.timeout);
      final responseHeaders = <String, String>{};
      ioResponse.headers.forEach((name, values) {
        if (values.isNotEmpty) {
          responseHeaders[name] = values.join(', ');
        }
      });
      return RawHttpResponse(
        statusCode: ioResponse.statusCode,
        body: responseBody,
        headers: responseHeaders,
      );
    } finally {
      client.close(force: false);
    }
  }
}
