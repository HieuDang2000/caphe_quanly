import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/inventory_repository.dart';

class InventoryState {
  final List<Map<String, dynamic>> items;
  final bool isLoading;
  final String? error;

  const InventoryState({this.items = const [], this.isLoading = false, this.error});

  InventoryState copyWith({List<Map<String, dynamic>>? items, bool? isLoading, String? error}) {
    return InventoryState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class InventoryNotifier extends StateNotifier<InventoryState> {
  final InventoryRepository _repo;

  InventoryNotifier(this._repo) : super(const InventoryState()) {
    load();
  }

  Future<void> load({bool lowStockOnly = false}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _repo.getItems(lowStockOnly: lowStockOnly);
      state = state.copyWith(items: data, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> create(Map<String, dynamic> data) async {
    try {
      await _repo.createItem(data);
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> update(int id, Map<String, dynamic> data) async {
    try {
      await _repo.updateItem(id, data);
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> delete(int id) async {
    try {
      await _repo.deleteItem(id);
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> addTransaction({
    required int itemId,
    required String type,
    required double quantity,
    String? reason,
  }) async {
    try {
      await _repo.addTransaction(itemId: itemId, type: type, quantity: quantity, reason: reason);
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  List<Map<String, dynamic>> get lowStockItems {
    return state.items.where((item) {
      final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
      final min = (item['min_quantity'] as num?)?.toDouble() ?? 0;
      return qty <= min;
    }).toList();
  }
}

final inventoryNotifierProvider = StateNotifierProvider<InventoryNotifier, InventoryState>((ref) {
  return InventoryNotifier(ref.watch(inventoryRepositoryProvider));
});
