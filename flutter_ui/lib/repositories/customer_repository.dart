import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/local_database.dart';

class CustomerRepository {
  final LocalDatabase _db;

  CustomerRepository(this._db);

  Future<List<Map<String, dynamic>>> getCustomers({String? search, String? tier}) async {
    if (search != null && search.isNotEmpty) {
      final lower = '%${search.toLowerCase()}%';
      return _db.queryWhere('customers',
          where: "(LOWER(name) LIKE ? OR phone LIKE ?)",
          whereArgs: [lower, lower],
          orderBy: 'name ASC');
    }
    if (tier != null) {
      return _db.queryWhere('customers',
          where: 'tier = ?', whereArgs: [tier], orderBy: 'name ASC');
    }
    return _db.queryAll('customers', orderBy: 'name ASC');
  }

  Future<Map<String, dynamic>?> getCustomerById(int id) async {
    return _db.queryById('customers', id);
  }

  Future<Map<String, dynamic>> createCustomer(Map<String, dynamic> data) async {
    final now = DateTime.now().toIso8601String();
    await _db.upsert('customers', {
      ...data,
      'points': 0,
      'tier': 'regular',
      'created_at': now,
      'updated_at': now,
    });
    final db = await _db.database;
    final rows = await db.query('customers', orderBy: 'id DESC', limit: 1);
    return Map<String, dynamic>.from(rows.first);
  }

  Future<void> updateCustomer(int id, Map<String, dynamic> data) async {
    final existing = await _db.queryById('customers', id);
    if (existing == null) return;
    await _db.upsert('customers', {
      ...existing,
      ...data,
      'id': id,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteCustomer(int id) async {
    await _db.deleteByIds('customers', [id]);
  }

  Future<void> addPoints(int customerId, int points, {int? orderId, String? description}) async {
    final customer = await _db.queryById('customers', customerId);
    if (customer == null) return;
    final now = DateTime.now().toIso8601String();

    final currentPoints = (customer['points'] as num?)?.toInt() ?? 0;
    final newPoints = currentPoints + points;

    await _db.upsert('customers', {
      ...customer,
      'points': newPoints,
      'tier': _calcTier(newPoints),
      'updated_at': now,
    });

    await _db.upsert('customer_points', {
      'customer_id': customerId,
      'order_id': orderId,
      'points': points,
      'type': 'earn',
      'description': description ?? 'Tích điểm',
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> redeemPoints(int customerId, int points, {String? description}) async {
    final customer = await _db.queryById('customers', customerId);
    if (customer == null) return;

    final currentPoints = (customer['points'] as num?)?.toInt() ?? 0;
    if (currentPoints < points) throw Exception('Không đủ điểm để đổi');

    final now = DateTime.now().toIso8601String();
    final newPoints = currentPoints - points;

    await _db.upsert('customers', {
      ...customer,
      'points': newPoints,
      'tier': _calcTier(newPoints),
      'updated_at': now,
    });

    await _db.upsert('customer_points', {
      'customer_id': customerId,
      'points': points,
      'type': 'redeem',
      'description': description ?? 'Đổi điểm',
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<List<Map<String, dynamic>>> getPointsHistory(int customerId) async {
    return _db.queryWhere('customer_points',
        where: 'customer_id = ?', whereArgs: [customerId], orderBy: 'id DESC');
  }

  static String _calcTier(int points) {
    if (points >= 5000) return 'platinum';
    if (points >= 2000) return 'gold';
    if (points >= 500) return 'silver';
    return 'regular';
  }
}

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(ref.watch(localDatabaseProvider));
});
