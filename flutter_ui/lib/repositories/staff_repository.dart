import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/database/local_database.dart';

class StaffRepository {
  final LocalDatabase _db;

  StaffRepository(this._db);

  // ---------------------------------------------------------------------------
  // Staff (users with staff/cashier/manager roles)
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getStaff() async {
    // Get users with non-admin roles (staff, cashier, manager)
    final roles = await _db.queryWhere('roles',
        where: "name IN ('staff','cashier','manager')",
        whereArgs: []);
    final roleIds = roles.map((r) => r['id']).toList();
    if (roleIds.isEmpty) return [];

    final placeholders = List.filled(roleIds.length, '?').join(',');
    final users = await _db.queryWhere('users',
        where: 'role_id IN ($placeholders)', whereArgs: roleIds, orderBy: 'name ASC');

    return Future.wait(users.map(_attachProfile));
  }

  Future<Map<String, dynamic>?> getStaffById(int userId) async {
    final user = await _db.queryById('users', userId);
    if (user == null) return null;
    return _attachProfile(user);
  }

  Future<void> updateProfile(int userId, Map<String, dynamic> data) async {
    final now = DateTime.now().toIso8601String();
    final existing = await _db.queryWhere('staff_profiles',
        where: 'user_id = ?', whereArgs: [userId]);

    if (existing.isNotEmpty) {
      await _db.upsert('staff_profiles', {
        ...existing.first,
        ...data,
        'user_id': userId,
        'updated_at': now,
      });
    } else {
      await _db.upsert('staff_profiles', {
        ...data,
        'user_id': userId,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Shifts
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getShifts({String? date}) async {
    final shifts = date != null
        ? await _db.queryWhere('shifts',
            where: 'shift_date = ?', whereArgs: [date], orderBy: 'start_time ASC')
        : await _db.queryAll('shifts', orderBy: 'shift_date DESC, start_time ASC');

    return Future.wait(shifts.map(_attachShiftUser));
  }

  Future<void> createShift(Map<String, dynamic> data) async {
    final now = DateTime.now().toIso8601String();
    await _db.upsert('shifts', {
      ...data,
      'status': data['status'] ?? 'scheduled',
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> updateShift(int id, Map<String, dynamic> data) async {
    final existing = await _db.queryById('shifts', id);
    if (existing == null) return;
    await _db.upsert('shifts', {
      ...existing,
      ...data,
      'id': id,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteShift(int id) async {
    await _db.deleteByIds('shifts', [id]);
  }

  // ---------------------------------------------------------------------------
  // Attendances
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getAttendances({String? date}) async {
    final attendances = date != null
        ? await _db.queryWhere('attendances',
            where: "DATE(check_in) = ? OR DATE(created_at) = ?",
            whereArgs: [date, date],
            orderBy: 'id DESC')
        : await _db.queryAll('attendances', orderBy: 'id DESC');

    return Future.wait(attendances.map(_attachAttendanceUser));
  }

  Future<void> checkIn(int userId) async {
    final now = DateTime.now().toIso8601String();
    final today = now.substring(0, 10);

    // Find shift for today
    final todayShifts = await _db.queryWhere('shifts',
        where: 'user_id = ? AND shift_date = ?', whereArgs: [userId, today]);
    final shiftId = todayShifts.isNotEmpty ? todayShifts.first['id'] as int? : null;

    // Check if already checked in today without check-out
    final openAttendances = await _db.queryWhere('attendances',
        where: "user_id = ? AND DATE(check_in) = ? AND check_out IS NULL",
        whereArgs: [userId, today]);
    if (openAttendances.isNotEmpty) throw Exception('Đã check-in rồi, vui lòng check-out trước');

    await _db.upsert('attendances', {
      'user_id': userId,
      'shift_id': shiftId,
      'check_in': now,
      'created_at': now,
      'updated_at': now,
    });

    // Update shift status to active
    if (shiftId != null) {
      final shift = await _db.queryById('shifts', shiftId);
      if (shift != null) {
        await _db.upsert('shifts', {...shift, 'status': 'active', 'updated_at': now});
      }
    }
  }

  Future<void> checkOut(int userId) async {
    final now = DateTime.now().toIso8601String();
    final today = now.substring(0, 10);

    final openAttendances = await _db.queryWhere('attendances',
        where: "user_id = ? AND DATE(check_in) = ? AND check_out IS NULL",
        whereArgs: [userId, today]);
    if (openAttendances.isEmpty) throw Exception('Không tìm thấy bản ghi check-in hôm nay');

    final attendance = openAttendances.first;
    await _db.upsert('attendances', {...attendance, 'check_out': now, 'updated_at': now});

    // Update shift status to completed
    final shiftId = attendance['shift_id'] as int?;
    if (shiftId != null) {
      final shift = await _db.queryById('shifts', shiftId);
      if (shift != null) {
        await _db.upsert('shifts', {...shift, 'status': 'completed', 'updated_at': now});
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> _attachProfile(Map<String, dynamic> user) async {
    final userId = user['id'];
    final roleId = user['role_id'];
    Map<String, dynamic>? role;
    Map<String, dynamic>? profile;

    if (roleId != null) {
      role = await _db.queryById('roles', roleId as int);
    }
    if (userId != null) {
      final profiles = await _db.queryWhere('staff_profiles',
          where: 'user_id = ?', whereArgs: [userId]);
      if (profiles.isNotEmpty) profile = profiles.first;
    }

    return {
      ...user,
      if (role != null) 'role': role,
      if (profile != null) 'staff_profile': profile,
    };
  }

  Future<Map<String, dynamic>> _attachShiftUser(Map<String, dynamic> shift) async {
    final userId = shift['user_id'];
    if (userId == null) return shift;
    final user = await _db.queryById('users', userId as int);
    return {...shift, if (user != null) 'user': {'id': user['id'], 'name': user['name']}};
  }

  Future<Map<String, dynamic>> _attachAttendanceUser(Map<String, dynamic> att) async {
    final userId = att['user_id'];
    if (userId == null) return att;
    final user = await _db.queryById('users', userId as int);
    return {...att, if (user != null) 'user': {'id': user['id'], 'name': user['name']}};
  }
}

final staffRepositoryProvider = Provider<StaffRepository>((ref) {
  return StaffRepository(ref.watch(localDatabaseProvider));
});

/// Convenience provider to get current user ID from SharedPreferences
final currentUserIdProvider = FutureProvider<int?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt('user_id');
});
