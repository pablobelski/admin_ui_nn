import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/auth_repository.dart';

const _tokenStorageKey = 'configurator_access_token';
const _emailStorageKey = 'configurator_user_email';
const _nameStorageKey = 'configurator_user_name';
const _roleStorageKey = 'configurator_user_role';

class AuthSessionState {
  const AuthSessionState({
    required this.isLoading,
    required this.isAuthenticated,
    required this.mustChangePassword,
    this.accessToken,
    this.userId,
    this.email,
    this.fullName,
    this.contactName,
    this.organizationName,
    this.roleCode,
    this.errorMessage,
  });

  const AuthSessionState.loading()
      : isLoading = true,
        isAuthenticated = false,
        mustChangePassword = false,
        accessToken = null,
        userId = null,
        email = null,
        fullName = null,
        contactName = null,
        organizationName = null,
        roleCode = null,
        errorMessage = null;

  const AuthSessionState.signedOut({this.errorMessage})
      : isLoading = false,
        isAuthenticated = false,
        mustChangePassword = false,
        accessToken = null,
        userId = null,
        email = null,
        fullName = null,
        contactName = null,
        organizationName = null,
        roleCode = null;

  const AuthSessionState.signedIn({
    required this.accessToken,
    required this.userId,
    required this.email,
    required this.fullName,
    required this.contactName,
    required this.organizationName,
    required this.roleCode,
    required this.mustChangePassword,
    this.errorMessage,
  })  : isLoading = false,
        isAuthenticated = true;

  final bool isLoading;
  final bool isAuthenticated;
  final bool mustChangePassword;
  final String? accessToken;
  final String? userId;
  final String? email;
  final String? fullName;
  final String? contactName;
  final String? organizationName;
  final String? roleCode;
  final String? errorMessage;

  AuthSessionState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    bool? mustChangePassword,
    String? accessToken,
    String? userId,
    String? email,
    String? fullName,
    String? contactName,
    String? organizationName,
    String? roleCode,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthSessionState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      accessToken: accessToken ?? this.accessToken,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      contactName: contactName ?? this.contactName,
      organizationName: organizationName ?? this.organizationName,
      roleCode: roleCode ?? this.roleCode,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuthSessionNotifier extends Notifier<AuthSessionState> {
  @override
  AuthSessionState build() => const AuthSessionState.loading();

  Future<void> restore() async {
    state = const AuthSessionState.loading();
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_tokenStorageKey);
    if (token == null || token.isEmpty) {
      state = const AuthSessionState.signedOut();
      return;
    }

    try {
      final repository = ref.read(authRepositoryProvider);
      final me = await repository.fetchMe(token);
      state = AuthSessionState.signedIn(
        accessToken: token,
        userId: me.id,
        email: me.email,
        fullName: me.fullName,
        contactName: me.contactName,
        organizationName: me.organizationName,
        roleCode: me.roleCode,
        mustChangePassword: me.mustChangePassword,
      );
    } catch (_) {
      await signOut();
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    state = const AuthSessionState.loading();
    try {
      final repository = ref.read(authRepositoryProvider);
      final response = await repository.login(email: email, password: password);
      await _storeSession(response);
      return true;
    } catch (error) {
      state = AuthSessionState.signedOut(errorMessage: error.toString());
      return false;
    }
  }

  Future<bool> completePasswordChange(String newPassword) async {
    final current = state;
    final token = current.accessToken;
    if (token == null || token.isEmpty) {
      await signOut();
      return false;
    }

    state = current.copyWith(isLoading: true, clearError: true);
    try {
      final repository = ref.read(authRepositoryProvider);
      final response = await repository.completePasswordChange(
        token: token,
        newPassword: newPassword,
      );
      await _storeSession(response);
      return true;
    } catch (error) {
      state = AuthSessionState.signedIn(
        accessToken: current.accessToken!,
        userId: current.userId ?? '',
        email: current.email ?? '',
        fullName: current.fullName,
        contactName: current.contactName,
        organizationName: current.organizationName,
        roleCode: current.roleCode ?? 'viewer',
        mustChangePassword: true,
        errorMessage: error.toString(),
      );
      return false;
    }
  }

  Future<void> _storeSession(LoginResponse response) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_tokenStorageKey, response.accessToken);
    await preferences.setString(_emailStorageKey, response.user.email);
    await preferences.setString(_nameStorageKey, response.user.fullName ?? '');
    await preferences.setString(_roleStorageKey, response.user.roleCode);

    state = AuthSessionState.signedIn(
      accessToken: response.accessToken,
      userId: response.user.id,
      email: response.user.email,
      fullName: response.user.fullName,
      contactName: response.user.contactName,
      organizationName: response.user.organizationName,
      roleCode: response.user.roleCode,
      mustChangePassword: response.user.mustChangePassword,
    );
  }

  Future<void> signOut() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenStorageKey);
    await preferences.remove(_emailStorageKey);
    await preferences.remove(_nameStorageKey);
    await preferences.remove(_roleStorageKey);
    state = const AuthSessionState.signedOut();
  }
}

final authSessionProvider = NotifierProvider<AuthSessionNotifier, AuthSessionState>(
  AuthSessionNotifier.new,
);
