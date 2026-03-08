import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/local_database.dart';

class InvoiceRepository {
  final LocalDatabase _db;

  InvoiceRepository(this._db);

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> getInvoice(int id) async {
    final local = await _db.queryById('invoices', id);
    if (local == null) return null;
    return _attachPayments(local);
  }

  Future<Map<String, dynamic>?> getInvoiceByOrderId(int orderId) async {
    final rows = await _db.queryWhere('invoices',
        where: 'order_id = ?', whereArgs: [orderId]);
    if (rows.isEmpty) return null;
    return _attachPayments(rows.first);
  }

  // ---------------------------------------------------------------------------
  // Write
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> generateInvoice(int orderId) async {
    // Return existing invoice if already created
    final existing = await _db.queryWhere('invoices',
        where: 'order_id = ?', whereArgs: [orderId]);
    if (existing.isNotEmpty) {
      return _attachPayments(existing.first);
    }

    final order = await _db.queryById('orders', orderId);
    if (order == null) throw Exception('Không tìm thấy đơn hàng #$orderId');

    final now = DateTime.now().toIso8601String();
    final invoiceNumber = _generateInvoiceNumber();

    final subtotal = (order['subtotal'] as num?)?.toDouble() ?? 0.0;
    const taxRate = 0.0;
    const taxAmount = 0.0;
    final discountAmount = (order['discount'] as num?)?.toDouble() ?? 0.0;
    final total = subtotal + taxAmount - discountAmount;

    final invoice = {
      'order_id': orderId,
      'invoice_number': invoiceNumber,
      'subtotal': subtotal,
      'tax_rate': taxRate,
      'tax_amount': taxAmount,
      'discount_amount': discountAmount,
      'total': total < 0 ? 0.0 : total,
      'payment_status': 'unpaid',
      'created_at': now,
      'updated_at': now,
    };

    await _db.upsert('invoices', invoice);

    final rows = await _db.queryWhere('invoices',
        where: 'invoice_number = ?', whereArgs: [invoiceNumber]);
    if (rows.isEmpty) return null;
    return _attachPayments(rows.first);
  }

  Future<Map<String, dynamic>?> addPayment(
    int invoiceId, {
    required double amount,
    required String method,
    String? reference,
  }) async {
    final invoice = await _db.queryById('invoices', invoiceId);
    if (invoice == null) throw Exception('Không tìm thấy hóa đơn #$invoiceId');

    final now = DateTime.now().toIso8601String();
    await _db.upsert('payments', {
      'invoice_id': invoiceId,
      'amount': amount,
      'payment_method': method,
      'reference_number': reference,
      'paid_at': now,
      'created_at': now,
      'updated_at': now,
    });

    // Recalculate payment_status
    final payments = await _db.queryWhere('payments',
        where: 'invoice_id = ?', whereArgs: [invoiceId]);
    final totalPaid = payments.fold<double>(
        0.0, (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0.0));
    final invoiceTotal = (invoice['total'] as num?)?.toDouble() ?? 0.0;

    final paymentStatus = totalPaid >= invoiceTotal
        ? 'paid'
        : totalPaid > 0
            ? 'partial'
            : 'unpaid';

    await _db.upsert('invoices', {
      ...invoice,
      'payment_status': paymentStatus,
      'updated_at': now,
    });

    final updated = await _db.queryById('invoices', invoiceId);
    return updated == null ? null : _attachPayments(updated);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static String _generateInvoiceNumber() {
    final now = DateTime.now();
    String pad2(int n) => n.toString().padLeft(2, '0');
    final date = '${now.year}${pad2(now.month)}${pad2(now.day)}';
    final time = '${pad2(now.hour)}${pad2(now.minute)}${pad2(now.second)}';
    return 'INV-$date-$time';
  }

  Future<Map<String, dynamic>> _attachPayments(Map<String, dynamic> invoice) async {
    final id = invoice['id'];
    if (id == null) return invoice;
    final payments = await _db.queryWhere('payments',
        where: 'invoice_id = ?', whereArgs: [id]);
    return {...invoice, 'payments': payments};
  }
}

final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  return InvoiceRepository(ref.watch(localDatabaseProvider));
});
