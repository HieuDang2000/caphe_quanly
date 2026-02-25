import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/api_config.dart';
import '../core/database/local_database.dart';
import '../core/network/api_client.dart';

class InvoiceRepository {
  final ApiClient _api;
  final LocalDatabase _db;

  InvoiceRepository(this._api, this._db);

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> getInvoice(int id, {bool forceRefresh = false}) async {
    final local = await _db.queryById('invoices', id);
    if (local != null && !forceRefresh) {
      _refreshInvoice(id);
      return _attachPayments(local);
    }
    try {
      return await _refreshInvoice(id);
    } catch (e) {
      if (local != null) return _attachPayments(local);
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _refreshInvoice(int id) async {
    final res = await _api.get('${ApiConfig.invoices}/$id');
    final invoice = Map<String, dynamic>.from(res.data);
    await _cacheInvoice(invoice);
    return invoice;
  }

  // ---------------------------------------------------------------------------
  // Write (require online)
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> generateInvoice(int orderId) async {
    final res = await _api.post('${ApiConfig.invoices}/generate/$orderId');
    final invoice = Map<String, dynamic>.from(res.data);
    await _cacheInvoice(invoice);
    return invoice;
  }

  Future<Map<String, dynamic>?> addPayment(
    int invoiceId, {
    required double amount,
    required String method,
    String? reference,
  }) async {
    final res = await _api.post('${ApiConfig.invoices}/$invoiceId/payment',
        data: {
          'amount': amount,
          'payment_method': method,
          'reference_number': reference,
        });
    final data = Map<String, dynamic>.from(res.data);
    final invoice = data['invoice'];
    if (invoice is Map<String, dynamic>) {
      await _cacheInvoice(invoice);
      return invoice;
    }
    return null;
  }

  Future<List<int>> downloadPdf(int invoiceId, {bool receipt80mm = false}) async {
    final path = receipt80mm
        ? '${ApiConfig.invoices}/$invoiceId/receipt'
        : '${ApiConfig.invoices}/$invoiceId/pdf';
    final res = await _api.get(path);
    final data = res.data;
    if (data is List<int>) return data;
    if (data is List) return data.cast<int>();
    throw Exception('Không thể tải PDF hóa đơn');
  }

  // ---------------------------------------------------------------------------
  // Cache helpers
  // ---------------------------------------------------------------------------

  Future<void> _cacheInvoice(Map<String, dynamic> invoice) async {
    await _db.upsert('invoices', invoice);
    final payments = invoice['payments'];
    if (payments is List && payments.isNotEmpty) {
      await _db.upsertBatch(
          'payments', List<Map<String, dynamic>>.from(payments));
    }
    await _db.setSyncTime('invoices', DateTime.now());
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
  return InvoiceRepository(
    ref.watch(apiClientProvider),
    ref.watch(localDatabaseProvider),
  );
});
