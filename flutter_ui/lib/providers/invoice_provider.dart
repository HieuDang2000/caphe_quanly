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

  Future<void> loadInvoice(int id) async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await _api.get('${ApiConfig.invoices}/$id');
      state = InvoiceState(invoice: Map<String, dynamic>.from(res.data));
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
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
}

final invoiceProvider = StateNotifierProvider<InvoiceNotifier, InvoiceState>((ref) {
  return InvoiceNotifier(ref.watch(apiClientProvider));
});
