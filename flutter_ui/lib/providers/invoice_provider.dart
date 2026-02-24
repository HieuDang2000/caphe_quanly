import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../config/api_config.dart';

class InvoiceState {
  final Map<String, dynamic>? invoice;
  final bool isLoading;
  final String? error;

  const InvoiceState({this.invoice, this.isLoading = false, this.error});

  InvoiceState copyWith({Map<String, dynamic>? invoice, bool? isLoading, String? error}) {
    return InvoiceState(invoice: invoice ?? this.invoice, isLoading: isLoading ?? this.isLoading, error: error);
  }
}

class InvoiceNotifier extends StateNotifier<InvoiceState> {
  final ApiClient _api;
  InvoiceNotifier(this._api) : super(const InvoiceState());

  Future<Map<String, dynamic>?> generateInvoice(int orderId) async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await _api.post('${ApiConfig.invoices}/generate/$orderId');
      final invoice = Map<String, dynamic>.from(res.data);
      state = InvoiceState(invoice: invoice);
      return invoice;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<Map<String, dynamic>?> loadInvoice(int id) async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await _api.get('${ApiConfig.invoices}/$id');
      final invoice = Map<String, dynamic>.from(res.data);
      state = InvoiceState(invoice: invoice);
      return invoice;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<bool> addPayment(int invoiceId, {required double amount, required String method, String? reference}) async {
    try {
      final res = await _api.post('${ApiConfig.invoices}/$invoiceId/payment', data: {
        'amount': amount,
        'payment_method': method,
        'reference_number': reference,
      });
      final data = Map<String, dynamic>.from(res.data);
      state = state.copyWith(invoice: Map<String, dynamic>.from(data['invoice']));
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<List<int>> downloadInvoicePdf(int invoiceId, {bool receipt80mm = false}) async {
    final path = receipt80mm ? '${ApiConfig.invoices}/$invoiceId/receipt' : '${ApiConfig.invoices}/$invoiceId/pdf';
    final res = await _api.get(path, queryParameters: null);
    // Dio mặc định trả về bytes cho PDF, đảm bảo cast đúng
    final data = res.data;
    if (data is List<int>) return data;
    if (data is List) {
      return data.cast<int>();
    }
    throw Exception('Không thể tải PDF hóa đơn');
  }
}

final invoiceProvider = StateNotifierProvider<InvoiceNotifier, InvoiceState>((ref) {
  return InvoiceNotifier(ref.watch(apiClientProvider));
});
