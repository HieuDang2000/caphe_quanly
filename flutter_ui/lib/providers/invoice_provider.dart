import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/invoice_repository.dart';

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
  final InvoiceRepository _repo;
  InvoiceNotifier(this._repo) : super(const InvoiceState());

  Future<Map<String, dynamic>?> generateInvoice(int orderId) async {
    state = state.copyWith(isLoading: true);
    try {
      final invoice = await _repo.generateInvoice(orderId);
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
      final invoice = await _repo.getInvoice(id, forceRefresh: true);
      state = InvoiceState(invoice: invoice);
      return invoice;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<bool> addPayment(int invoiceId, {required double amount, required String method, String? reference}) async {
    try {
      final invoice = await _repo.addPayment(invoiceId,
          amount: amount, method: method, reference: reference);
      if (invoice != null) {
        state = state.copyWith(invoice: invoice);
      }
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<List<int>> downloadInvoicePdf(int invoiceId, {bool receipt80mm = false}) async {
    return _repo.downloadPdf(invoiceId, receipt80mm: receipt80mm);
  }
}

final invoiceProvider = StateNotifierProvider<InvoiceNotifier, InvoiceState>((ref) {
  return InvoiceNotifier(ref.watch(invoiceRepositoryProvider));
});
