import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/api_client.dart';
import '../config/api_config.dart';

class AuthState {
  final bool isLoggedIn;
  final bool isLoading;
  final Map<String, dynamic>? user;
  final String? error;

  const AuthState({this.isLoggedIn = false, this.isLoading = false, this.user, this.error});

  AuthState copyWith({bool? isLoggedIn, bool? isLoading, Map<String, dynamic>? user, String? error}) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _api;

  AuthNotifier(this._api) : super(const AuthState()) {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token != null) {
      try {
        final response = await _api.get(ApiConfig.me);
        state = AuthState(isLoggedIn: true, user: Map<String, dynamic>.from(response.data));
      } catch (_) {
        await prefs.remove('jwt_token');
        state = const AuthState();
      }
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.post(ApiConfig.login, data: {'email': email, 'password': password});
      final data = response.data;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', data['access_token']);
      state = AuthState(isLoggedIn: true, user: Map<String, dynamic>.from(data['user']));
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _api.post(ApiConfig.logout);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    state = const AuthState();
  }

  Future<void> refreshUser() async {
    try {
      final response = await _api.get(ApiConfig.me);
      state = state.copyWith(user: Map<String, dynamic>.from(response.data));
    } catch (_) {}
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(apiClientProvider));
});
