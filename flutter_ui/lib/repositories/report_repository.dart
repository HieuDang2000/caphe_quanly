import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/local_database.dart';

class ReportRepository {
  final LocalDatabase _db;

  ReportRepository(this._db);

  // ---------------------------------------------------------------------------
  // Daily Summary
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> dailySummary() async {
    final today = DateTime.now();
    final todayStr = today.toIso8601String().substring(0, 10);

    // Use Vietnam UTC offset (UTC+7) for date boundaries
    final startUtc = DateTime.utc(today.year, today.month, today.day)
        .subtract(const Duration(hours: 7));
    final endUtc = startUtc.add(const Duration(days: 1));
    final start = startUtc.toIso8601String();
    final end = endUtc.toIso8601String();

    final rows = await _db.rawQuery('''
      SELECT
        COUNT(*) AS total_orders,
        COALESCE(SUM(CASE WHEN status IN ('completed','paid') THEN 1 ELSE 0 END), 0) AS completed_orders,
        COALESCE(SUM(CASE WHEN status = 'pending' OR status = 'in_progress' THEN 1 ELSE 0 END), 0) AS pending_orders,
        COALESCE(SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END), 0) AS cancelled_orders,
        COALESCE(SUM(CASE WHEN status IN ('completed','paid') THEN total ELSE 0 END), 0) AS total_revenue
      FROM orders
      WHERE created_at >= ? AND created_at < ?
    ''', [start, end]);

    final data = rows.isNotEmpty ? rows.first : <String, dynamic>{};
    return {
      'date': todayStr,
      'total_orders': data['total_orders'] ?? 0,
      'completed_orders': data['completed_orders'] ?? 0,
      'pending_orders': data['pending_orders'] ?? 0,
      'cancelled_orders': data['cancelled_orders'] ?? 0,
      'total_revenue': data['total_revenue'] ?? 0,
    };
  }

  /// Tổng hợp theo khoảng bất kỳ. Nếu không truyền [from]/[to] thì dùng logic hôm nay.
  Future<Map<String, dynamic>> summary({String? from, String? to}) async {
    if (from == null || to == null) {
      return dailySummary();
    }

    final rows = await _db.rawQuery('''
      SELECT
        COUNT(*) AS total_orders,
        COALESCE(SUM(CASE WHEN status IN ('completed','paid') THEN 1 ELSE 0 END), 0) AS completed_orders,
        COALESCE(SUM(CASE WHEN status = 'pending' OR status = 'in_progress' THEN 1 ELSE 0 END), 0) AS pending_orders,
        COALESCE(SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END), 0) AS cancelled_orders,
        COALESCE(SUM(CASE WHEN status IN ('completed','paid') THEN total ELSE 0 END), 0) AS total_revenue
      FROM orders
      WHERE created_at >= ? AND created_at <= ?
    ''', [from, to]);

    final data = rows.isNotEmpty ? rows.first : <String, dynamic>{};
    return {
      'from': from,
      'to': to,
      'total_orders': data['total_orders'] ?? 0,
      'completed_orders': data['completed_orders'] ?? 0,
      'pending_orders': data['pending_orders'] ?? 0,
      'cancelled_orders': data['cancelled_orders'] ?? 0,
      'total_revenue': data['total_revenue'] ?? 0,
    };
  }

  /// Thống kê đơn chênh lệch và đơn có xóa món theo khoảng thời gian.
  Future<Map<String, dynamic>> discrepancyStats({String? from, String? to}) async {
    final start = from ?? _daysAgo(30);
    final end = to ?? _tomorrow();

    final rows = await _db.rawQuery('''
      SELECT
        COALESCE(SUM(
          CASE
            WHEN highest_total IS NOT NULL
              AND highest_total != 0
              AND (COALESCE(total_all, 0) - highest_total) != 0
            THEN 1 ELSE 0
          END
        ), 0) AS discrepancy_orders_count,
        COALESCE(SUM(
          CASE
            WHEN highest_total IS NOT NULL
              AND highest_total != 0
              AND (COALESCE(total_all, 0) - highest_total) != 0
            THEN (COALESCE(total_all, 0) - highest_total)
            ELSE 0
          END
        ), 0) AS discrepancy_total_diff,
        COALESCE(SUM(
          CASE
            WHEN is_deleted_item = 1 THEN 1 ELSE 0
          END
        ), 0) AS deleted_item_orders_count
      FROM orders
      WHERE created_at >= ? AND created_at <= ?
    ''', [start, end]);

    final data = rows.isNotEmpty ? rows.first : <String, dynamic>{};
    return {
      'from': start,
      'to': end,
      'discrepancy_orders_count': data['discrepancy_orders_count'] ?? 0,
      'discrepancy_total_diff': data['discrepancy_total_diff'] ?? 0,
      'deleted_item_orders_count': data['deleted_item_orders_count'] ?? 0,
    };
  }

  // ---------------------------------------------------------------------------
  // Sales data (daily grouped)
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> salesData({String? from, String? to}) async {
    final start = from ?? _daysAgo(30);
    final end = to ?? _tomorrow();

    final rows = await _db.rawQuery('''
      SELECT
        DATE(datetime(created_at, '+7 hours')) AS date,
        COUNT(*) AS order_count,
        COALESCE(SUM(CASE WHEN status IN ('completed','paid') THEN total ELSE 0 END), 0) AS revenue
      FROM orders
      WHERE created_at >= ? AND created_at <= ?
        AND status != 'cancelled'
      GROUP BY date
      ORDER BY date ASC
    ''', [start, end]);

    num totalRevenue = 0;
    num totalOrders = 0;
    for (final r in rows) {
      totalRevenue += r['revenue'] as num? ?? 0;
      totalOrders += r['order_count'] as num? ?? 0;
    }

    return {
      'total_revenue': totalRevenue,
      'total_orders': totalOrders,
      'daily_sales': rows,
    };
  }

  // ---------------------------------------------------------------------------
  // Top Items
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> topItems({String? from, String? to, int limit = 10}) async {
    final start = from ?? _daysAgo(30);
    final end = to ?? _tomorrow();

    return _db.rawQuery('''
      SELECT
        mi.id,
        mi.name,
        SUM(oi.quantity) AS total_quantity,
        SUM(oi.subtotal) AS total_revenue
      FROM order_items oi
      JOIN menu_items mi ON mi.id = oi.menu_item_id
      JOIN orders o ON o.id = oi.order_id
      WHERE o.created_at >= ? AND o.created_at <= ?
        AND o.status != 'cancelled'
      GROUP BY mi.id, mi.name
      ORDER BY total_quantity DESC
      LIMIT ?
    ''', [start, end, limit]);
  }

  // ---------------------------------------------------------------------------
  // Category Revenue
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> categoryRevenue({String? from, String? to}) async {
    final start = from ?? _daysAgo(30);
    final end = to ?? _tomorrow();

    return _db.rawQuery('''
      SELECT
        c.id,
        c.name,
        SUM(oi.subtotal) AS revenue,
        SUM(oi.quantity) AS quantity
      FROM order_items oi
      JOIN menu_items mi ON mi.id = oi.menu_item_id
      JOIN categories c ON c.id = mi.category_id
      JOIN orders o ON o.id = oi.order_id
      WHERE o.created_at >= ? AND o.created_at <= ?
        AND o.status != 'cancelled'
      GROUP BY c.id, c.name
      ORDER BY revenue DESC
    ''', [start, end]);
  }

  // ---------------------------------------------------------------------------
  // Table Usage
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> tableUsage({String? from, String? to}) async {
    final start = from ?? _daysAgo(30);
    final end = to ?? _tomorrow();

    return _db.rawQuery('''
      SELECT
        lo.id,
        lo.name,
        COUNT(o.id) AS usage_count,
        COALESCE(SUM(CASE WHEN o.status IN ('completed','paid') THEN o.total ELSE 0 END), 0) AS revenue
      FROM layout_objects lo
      LEFT JOIN orders o ON o.table_id = lo.id
        AND o.created_at >= ? AND o.created_at <= ?
        AND o.status != 'cancelled'
      WHERE lo.type = 'table'
      GROUP BY lo.id, lo.name
      ORDER BY usage_count DESC
    ''', [start, end]);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static String _daysAgo(int days) {
    return DateTime.now().subtract(Duration(days: days)).toIso8601String().substring(0, 10);
  }

  static String _tomorrow() {
    return DateTime.now().add(const Duration(days: 1)).toIso8601String().substring(0, 10);
  }
}

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository(ref.watch(localDatabaseProvider));
});
