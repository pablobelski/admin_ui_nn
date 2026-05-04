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
    this.accessToken,
    this.email,
    this.fullName,
    this.roleCode,
    this.errorMessage,
  });

  const AuthSessionState.loading()
      : isLoading = true,
        isAuthenticated = false,
        accessToken = null,
        email = null,
        fullName = null,
        roleCode = null,
        errorMessage = null;

  const AuthSessionState.signedOut({this.errorMessage})
      : isLoading = false,
        isAuthenticated = false,
        accessToken = null,
        email = null,
        fullName = null,
        roleCode = null;

  const AuthSessionState.signedIn({
    required this.accessToken,
    required this.email,
    required this.fullName,
    required this.roleCode,
  })  : isLoading = false,
        isAuthenticated = true,
        errorMessage = null;

  final bool isLoading;
  final bool isAuthenticated;
  final String? accessToken;
  final String? email;
  final String? fullName;
  final String? roleCode;
  final String? errorMessage;

  AuthSessionState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    String? accessToken,
    String? email,
    String? fullName,
    String? roleCode,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthSessionState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      accessToken: accessToken ?? this.accessToken,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
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
        email: me.email,
        fullName: me.fullName,
        roleCode: me.roleCode,
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

      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_tokenStorageKey, response.accessToken);
      await preferences.setString(_emailStorageKey, response.user.email);
      await preferences.setString(_nameStorageKey, response.user.fullName ?? '');
      await preferences.setString(_roleStorageKey, response.user.roleCode);

      state = AuthSessionState.signedIn(
        accessToken: response.accessToken,
        email: response.user.email,
        fullName: response.user.fullName,
        roleCode: response.user.roleCode,
      );
      return true;
    } catch (error) {
      state = AuthSessionState.signedOut(errorMessage: error.toString());
      return false;
    }
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
