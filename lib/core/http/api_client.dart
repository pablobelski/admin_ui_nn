import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.tokenProvider,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final String? Function() tokenProvider;
  final http.Client _httpClient;

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('$baseUrl$path').replace(
      queryParameters: query == null || query.isEmpty ? null : query,
    );
  }

  Map<String, String> _headers({Map<String, String>? extra}) {
    final token = tokenProvider();
    final headers = <String, String>{
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      ...?extra,
    };
    return headers;
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
  }) async {
    final response = await _httpClient.get(
      _uri(path, query),
      headers: _headers(),
    );
    _ensureSuccess(response);
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is List) {
      return <String, dynamic>{'items': decoded, 'total': decoded.length};
    }
    throw const FormatException('Unexpected GET response shape');
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    final response = await _httpClient.post(
      _uri(path),
      headers: _headers(extra: {'Content-Type': 'application/json'}),
      body: jsonEncode(body),
    );
    _ensureSuccess(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> putJson(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    final response = await _httpClient.put(
      _uri(path),
      headers: _headers(extra: {'Content-Type': 'application/json'}),
      body: jsonEncode(body),
    );
    _ensureSuccess(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> delete(String path) async {
    final response = await _httpClient.delete(
      _uri(path),
      headers: _headers(),
    );
    _ensureSuccess(response);
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    throw ApiException(
      statusCode: response.statusCode,
      body: response.body,
    );
  }
}

class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;

  String get displayMessage {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message']?.toString().trim() ?? '';
        final code = decoded['code']?.toString().trim() ?? '';
        final details = decoded['details']?.toString().trim() ?? '';
        return [
          'HTTP $statusCode',
          if (message.isNotEmpty) message,
          if (code.isNotEmpty) 'code: $code',
          if (details.isNotEmpty) 'details: $details',
        ].join(' | ');
      }
    } catch (_) {
      // Fall back to the raw body below.
    }

    final rawBody = body.trim();
    return rawBody.isEmpty ? 'HTTP $statusCode' : 'HTTP $statusCode | $rawBody';
  }

  @override
  String toString() => displayMessage;
}
