import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/api_config.dart';
import '../core/database/local_database.dart';
import '../core/network/api_client.dart';

class LayoutRepository {
  final ApiClient _api;
  final LocalDatabase _db;

  LayoutRepository(this._api, this._db);

  // ---------------------------------------------------------------------------
  // Floors
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getFloors({bool forceRefresh = false}) async {
    final local = await _db.queryAll('floors', orderBy: 'floor_number ASC');
    if (local.isNotEmpty && !forceRefresh) {
      _refreshFloors();
      return local;
    }
    try {
      return await _refreshFloors();
    } catch (e) {
      if (local.isNotEmpty) return local;
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _refreshFloors() async {
    final res = await _api.get(ApiConfig.floors);
    final data = List<Map<String, dynamic>>.from(res.data);
    await _db.upsertBatch('floors', data);
    await _db.setSyncTime('floors', DateTime.now());
    return data;
  }

  // ---------------------------------------------------------------------------
  // Layout Objects (per floor)
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getFloorObjects(int floorId,
      {bool forceRefresh = false}) async {
    final local = await _db.queryWhere('layout_objects',
        where: 'floor_id = ?', whereArgs: [floorId]);

    if (local.isNotEmpty && !forceRefresh) {
      _refreshFloorObjects(floorId);
      return local;
    }
    try {
      return await _refreshFloorObjects(floorId);
    } catch (e) {
      if (local.isNotEmpty) return local;
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _refreshFloorObjects(int floorId) async {
    final res = await _api.get('${ApiConfig.floors}/$floorId/objects');
    final data = List<Map<String, dynamic>>.from(res.data);
    // Clear old objects for this floor, then insert fresh
    final db = await _db.database;
    await db.delete('layout_objects',
        where: 'floor_id = ?', whereArgs: [floorId]);
    await _db.upsertBatch('layout_objects', data);
    await _db.setSyncTime('layout_objects', DateTime.now());
    return data;
  }

  // ---------------------------------------------------------------------------
  // Write operations (require online)
  // ---------------------------------------------------------------------------

  Future<void> addObject(Map<String, dynamic> data) async {
    await _api.post(ApiConfig.layoutObjects, data: data);
  }

  Future<void> updateObject(int id, Map<String, dynamic> data) async {
    await _api.put('${ApiConfig.layoutObjects}/$id', data: data);
    await _db.upsert('layout_objects', {'id': id, ...data});
  }

  Future<void> batchUpdate(List<Map<String, dynamic>> objects) async {
    await _api.put(ApiConfig.layoutObjectsBatch, data: {'objects': objects});
  }

  Future<void> deleteObject(int id) async {
    await _api.delete('${ApiConfig.layoutObjects}/$id');
    await _db.deleteByIds('layout_objects', [id]);
  }
}

final layoutRepositoryProvider = Provider<LayoutRepository>((ref) {
  return LayoutRepository(
    ref.watch(apiClientProvider),
    ref.watch(localDatabaseProvider),
  );
});
