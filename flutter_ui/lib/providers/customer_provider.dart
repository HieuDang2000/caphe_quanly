import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/customer_repository.dart';

class CustomerState {
  final List<Map<String, dynamic>> customers;
  final bool isLoading;
  final String? error;

  const CustomerState({this.customers = const [], this.isLoading = false, this.error});

  CustomerState copyWith({List<Map<String, dynamic>>? customers, bool? isLoading, String? error}) {
    return CustomerState(
      customers: customers ?? this.customers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class CustomerNotifier extends StateNotifier<CustomerState> {
  final CustomerRepository _repo;

  CustomerNotifier(this._repo) : super(const CustomerState()) {
    load();
  }

  Future<void> load({String? search, String? tier}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _repo.getCustomers(search: search, tier: tier);
      state = state.copyWith(customers: data, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> create(Map<String, dynamic> data) async {
    try {
      await _repo.createCustomer(data);
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> update(int id, Map<String, dynamic> data) async {
    try {
      await _repo.updateCustomer(id, data);
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> delete(int id) async {
    try {
      await _repo.deleteCustomer(id);
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> addPoints(int customerId, int points) async {
    try {
      await _repo.addPoints(customerId, points);
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> redeemPoints(int customerId, int points) async {
    try {
      await _repo.redeemPoints(customerId, points);
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

final customerProvider = StateNotifierProvider<CustomerNotifier, CustomerState>((ref) {
  return CustomerNotifier(ref.watch(customerRepositoryProvider));
});
