import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/user_repository.dart';

class UserManagementState {
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> roles;
  final bool isLoading;
  final String? error;

  const UserManagementState({
    this.users = const [],
    this.roles = const [],
    this.isLoading = false,
    this.error,
  });

  UserManagementState copyWith({
    List<Map<String, dynamic>>? users,
    List<Map<String, dynamic>>? roles,
    bool? isLoading,
    String? error,
  }) {
    return UserManagementState(
      users: users ?? this.users,
      roles: roles ?? this.roles,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class UserManagementNotifier extends StateNotifier<UserManagementState> {
  final UserRepository _repo;

  UserManagementNotifier(this._repo) : super(const UserManagementState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait([_repo.getUsers(), _repo.getRoles()]);
      state = state.copyWith(users: results[0], roles: results[1], isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> create(Map<String, dynamic> data) async {
    try {
      await _repo.createUser(data);
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> update(int id, Map<String, dynamic> data) async {
    try {
      await _repo.updateUser(id, data);
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> delete(int id) async {
    try {
      await _repo.deleteUser(id);
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> updateRole(int id, int roleId) async {
    try {
      await _repo.updateRole(id, roleId);
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

final userManagementProvider =
    StateNotifierProvider<UserManagementNotifier, UserManagementState>((ref) {
  return UserManagementNotifier(ref.watch(userRepositoryProvider));
});
