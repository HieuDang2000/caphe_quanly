import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/local_database.dart';

class ReservationRepository {
  final LocalDatabase _db;

  ReservationRepository(this._db);

  Future<List<Map<String, dynamic>>> getReservations({String? date, String? status, int? tableId}) async {
    String? where;
    List<Object?> whereArgs = [];

    if (date != null) {
      where = 'reservation_date = ?';
      whereArgs.add(date);
    }
    if (status != null) {
      where = where != null ? '$where AND status = ?' : 'status = ?';
      whereArgs.add(status);
    }
    if (tableId != null) {
      where = where != null ? '$where AND table_id = ?' : 'table_id = ?';
      whereArgs.add(tableId);
    }

    final reservations = where != null
        ? await _db.queryWhere('reservations',
            where: where, whereArgs: whereArgs, orderBy: 'start_time ASC')
        : await _db.queryAll('reservations', orderBy: 'reservation_date ASC, start_time ASC');

    // Attach customer and table info
    return Future.wait(reservations.map(_attachRelations));
  }

  Future<Map<String, dynamic>?> getReservationById(int id) async {
    final r = await _db.queryById('reservations', id);
    if (r == null) return null;
    return _attachRelations(r);
  }

  Future<Map<String, dynamic>> createReservation(Map<String, dynamic> data) async {
    // Check for conflicts
    await _checkConflict(
      tableId: data['table_id'] as int,
      date: data['reservation_date'] as String,
      startTime: data['start_time'] as String,
      endTime: data['end_time'] as String,
    );

    final now = DateTime.now().toIso8601String();
    await _db.upsert('reservations', {
      ...data,
      'status': data['status'] ?? 'pending',
      'guests_count': data['guests_count'] ?? 1,
      'created_at': now,
      'updated_at': now,
    });

    final db = await _db.database;
    final rows = await db.query('reservations', orderBy: 'id DESC', limit: 1);
    return await _attachRelations(Map<String, dynamic>.from(rows.first));
  }

  Future<void> updateStatus(int id, String status) async {
    final existing = await _db.queryById('reservations', id);
    if (existing == null) return;
    await _db.upsert('reservations', {
      ...existing,
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateReservation(int id, Map<String, dynamic> data) async {
    final existing = await _db.queryById('reservations', id);
    if (existing == null) return;
    await _db.upsert('reservations', {
      ...existing,
      ...data,
      'id': id,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteReservation(int id) async {
    await _db.deleteByIds('reservations', [id]);
  }

  Future<void> _checkConflict({
    required int tableId,
    required String date,
    required String startTime,
    required String endTime,
    int? excludeId,
  }) async {
    final conflicts = await _db.queryWhere(
      'reservations',
      where: "table_id = ? AND reservation_date = ? AND status NOT IN ('cancelled') AND NOT (end_time <= ? OR start_time >= ?)",
      whereArgs: [tableId, date, startTime, endTime],
    );
    final filtered = excludeId != null ? conflicts.where((r) => r['id'] != excludeId).toList() : conflicts;
    if (filtered.isNotEmpty) {
      throw Exception('Bàn đã có đặt chỗ trong khung giờ này');
    }
  }

  Future<Map<String, dynamic>> _attachRelations(Map<String, dynamic> r) async {
    final customerId = r['customer_id'];
    final tableId = r['table_id'];
    Map<String, dynamic>? customer;
    Map<String, dynamic>? table;

    if (customerId != null) {
      final c = await _db.queryById('customers', customerId as int);
      if (c != null) customer = {'id': c['id'], 'name': c['name'], 'phone': c['phone']};
    }
    if (tableId != null) {
      final t = await _db.queryById('layout_objects', tableId as int);
      if (t != null) table = {'id': t['id'], 'name': t['name']};
    }

    return {
      ...r,
      if (customer != null) 'customer': customer,
      if (table != null) 'table': table,
    };
  }
}

final reservationRepositoryProvider = Provider<ReservationRepository>((ref) {
  return ReservationRepository(ref.watch(localDatabaseProvider));
});
