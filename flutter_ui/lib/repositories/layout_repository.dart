import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/local_database.dart';

class LayoutRepository {
  final LocalDatabase _db;

  LayoutRepository(this._db);

  // ---------------------------------------------------------------------------
  // Floors
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getFloors() async {
    return _db.queryAll('floors', orderBy: 'floor_number ASC');
  }

  Future<void> saveFloor(Map<String, dynamic> data, {int? id}) async {
    final now = DateTime.now().toIso8601String();
    if (id != null) {
      final existing = await _db.queryById('floors', id);
      if (existing == null) return;
      await _db.upsert('floors', {...existing, ...data, 'id': id, 'updated_at': now});
    } else {
      await _db.upsert('floors', {...data, 'is_active': true, 'created_at': now, 'updated_at': now});
    }
  }

  Future<void> deleteFloor(int id) async {
    await _db.deleteByIds('floors', [id]);
  }

  // ---------------------------------------------------------------------------
  // Layout Objects (per floor)
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getFloorObjects(int floorId) async {
    return _db.queryWhere('layout_objects',
        where: 'floor_id = ?', whereArgs: [floorId]);
  }

  Future<void> addObject(Map<String, dynamic> data) async {
    final now = DateTime.now().toIso8601String();
    await _db.upsert('layout_objects', {...data, 'is_active': true, 'created_at': now, 'updated_at': now});
  }

  Future<void> updateObject(int id, Map<String, dynamic> data) async {
    final now = DateTime.now().toIso8601String();
    final existing = await _db.queryById('layout_objects', id);
    if (existing == null) return;
    await _db.upsert('layout_objects', {...existing, ...data, 'id': id, 'updated_at': now});
  }

  Future<void> batchUpdate(List<Map<String, dynamic>> objects) async {
    final now = DateTime.now().toIso8601String();
    for (final obj in objects) {
      final id = obj['id'];
      if (id == null) continue;
      final existing = await _db.queryById('layout_objects', id as int);
      if (existing == null) continue;
      await _db.upsert('layout_objects', {...existing, ...obj, 'id': id, 'updated_at': now});
    }
  }

  Future<void> deleteObject(int id) async {
    // Cancel any pending orders for this table
    final now = DateTime.now().toIso8601String();
    final orders = await _db.queryWhere('orders',
        where: "table_id = ? AND status IN ('pending', 'in_progress')",
        whereArgs: [id]);
    for (final order in orders) {
      await _db.upsert('orders', {...order, 'status': 'cancelled', 'updated_at': now});
    }
    await _db.deleteByIds('layout_objects', [id]);
  }
}

final layoutRepositoryProvider = Provider<LayoutRepository>((ref) {
  return LayoutRepository(ref.watch(localDatabaseProvider));
});
