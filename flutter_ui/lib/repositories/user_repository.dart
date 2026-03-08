import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/local_database.dart';

class UserRepository {
  final LocalDatabase _db;

  UserRepository(this._db);

  static String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    final users = await _db.queryAll('users', orderBy: 'name ASC');
    return Future.wait(users.map(_attachRole));
  }

  Future<Map<String, dynamic>?> getUserById(int id) async {
    final user = await _db.queryById('users', id);
    if (user == null) return null;
    return _attachRole(user);
  }

  Future<Map<String, dynamic>> createUser(Map<String, dynamic> data) async {
    final now = DateTime.now().toIso8601String();
    final password = data['password'] as String? ?? '';
    await _db.upsert('users', {
      ...data,
      'password_hash': _hashPassword(password),
      'is_active': data['is_active'] ?? true,
      'created_at': now,
      'updated_at': now,
    });
    final db = await _db.database;
    final rows = await db.query('users', orderBy: 'id DESC', limit: 1);
    return await _attachRole(Map<String, dynamic>.from(rows.first));
  }

  Future<void> updateUser(int id, Map<String, dynamic> data) async {
    final existing = await _db.queryById('users', id);
    if (existing == null) return;

    final patch = Map<String, dynamic>.from(data)..remove('password');
    if (data.containsKey('password') && (data['password'] as String?)?.isNotEmpty == true) {
      patch['password_hash'] = _hashPassword(data['password'] as String);
    }

    await _db.upsert('users', {
      ...existing,
      ...patch,
      'id': id,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateRole(int id, int roleId) async {
    final existing = await _db.queryById('users', id);
    if (existing == null) return;
    await _db.upsert('users', {
      ...existing,
      'role_id': roleId,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteUser(int id) async {
    await _db.deleteByIds('users', [id]);
  }

  Future<List<Map<String, dynamic>>> getRoles() async {
    return _db.queryAll('roles', orderBy: 'id ASC');
  }

  Future<Map<String, dynamic>> _attachRole(Map<String, dynamic> user) async {
    final roleId = user['role_id'];
    if (roleId == null) return user;
    final role = await _db.queryById('roles', roleId as int);
    return {...user, if (role != null) 'role': role};
  }
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(localDatabaseProvider));
});
