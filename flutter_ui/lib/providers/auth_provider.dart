import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/database/local_database.dart';

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
  final LocalDatabase _db;

  AuthNotifier(this._db) : super(const AuthState()) {
    _checkAuth();
  }

  static String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  Future<void> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null) return;

    final user = await _db.queryById('users', userId);
    if (user == null) {
      await prefs.remove('user_id');
      return;
    }

    final roleId = user['role_id'];
    Map<String, dynamic>? role;
    if (roleId != null) {
      role = await _db.queryById('roles', roleId as int);
    }

    state = AuthState(
      isLoggedIn: true,
      user: {
        ...user,
        if (role != null) 'role': role,
      },
    );
  }

  Future<bool> login(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    final users = await _db.queryWhere(
      'users',
      where: 'email = ?',
      whereArgs: [username.trim()],
    );

    if (users.isEmpty) {
      state = state.copyWith(isLoading: false, error: 'Tên đăng nhập không tồn tại');
      return false;
    }

    final user = users.first;

    if (user['is_active'] == false) {
      state = state.copyWith(isLoading: false, error: 'Tài khoản đã bị khóa');
      return false;
    }

    final expectedHash = _hashPassword(password);
    if (user['password_hash'] != expectedHash) {
      state = state.copyWith(isLoading: false, error: 'Mật khẩu không đúng');
      return false;
    }

    final roleId = user['role_id'];
    Map<String, dynamic>? role;
    if (roleId != null) {
      role = await _db.queryById('roles', roleId as int);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_id', user['id'] as int);

    state = AuthState(
      isLoggedIn: true,
      user: {
        ...user,
        if (role != null) 'role': role,
      },
    );
    return true;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    state = const AuthState();
  }

  Future<void> refreshUser() async {
    await _checkAuth();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(localDatabaseProvider));
});
