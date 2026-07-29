import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';

class AuthRepository {
  AuthRepository({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<LoginResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _httpClient.post(
      Uri.parse('$apiBaseUrl/api/auth/login'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    _ensureSuccess(response, fallbackMessage: 'Login failed');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return LoginResponse.fromJson(decoded);
  }

  Future<AuthUser> fetchMe(String token) async {
    final response = await _httpClient.get(
      Uri.parse('$apiBaseUrl/api/auth/me'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    _ensureSuccess(response, fallbackMessage: 'Session restore failed');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return AuthUser.fromJson(decoded);
  }

  Future<LoginResponse> completePasswordChange({
    required String token,
    required String newPassword,
  }) async {
    final response = await _httpClient.post(
      Uri.parse('$apiBaseUrl/api/auth/complete-password-change'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'new_password': newPassword}),
    );

    _ensureSuccess(response, fallbackMessage: 'Password change failed');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return LoginResponse.fromJson(decoded);
  }

  void _ensureSuccess(
    http.Response response, {
    required String fallbackMessage,
  }) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message']?.toString().trim() ?? '';
        if (message.isNotEmpty) {
          throw AuthException(message);
        }
      }
    } on AuthException {
      rethrow;
    } catch (_) {
      // Use the fallback message below.
    }

    throw AuthException('$fallbackMessage (HTTP ${response.statusCode})');
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LoginResponse {
  const LoginResponse({
    required this.accessToken,
    required this.user,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      accessToken: json['access_token']?.toString() ?? '',
      user: AuthUser.fromJson(Map<String, dynamic>.from(json['user'] as Map)),
    );
  }

  final String accessToken;
  final AuthUser user;
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.contactName,
    required this.organizationName,
    required this.roleCode,
    required this.mustChangePassword,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: json['full_name']?.toString(),
      contactName: json['contact_name']?.toString(),
      organizationName: json['organization_name']?.toString(),
      roleCode: json['role_code']?.toString() ?? 'viewer',
      mustChangePassword: json['must_change_password'] == true,
    );
  }

  final String id;
  final String email;
  final String? fullName;
  final String? contactName;
  final String? organizationName;
  final String roleCode;
  final bool mustChangePassword;
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());
