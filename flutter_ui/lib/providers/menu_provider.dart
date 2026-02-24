import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../config/api_config.dart';

class MenuState {
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> items;
  final int? selectedCategoryId;
  final bool isLoading;
  final String? error;

  const MenuState({
    this.categories = const [],
    this.items = const [],
    this.selectedCategoryId,
    this.isLoading = false,
    this.error,
  });

  MenuState copyWith({
    List<Map<String, dynamic>>? categories,
    List<Map<String, dynamic>>? items,
    int? selectedCategoryId,
    bool? isLoading,
    String? error,
  }) {
    return MenuState(
      categories: categories ?? this.categories,
      items: items ?? this.items,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class MenuNotifier extends StateNotifier<MenuState> {
  final ApiClient _api;
  MenuNotifier(this._api) : super(const MenuState());

  Future<void> loadCategories() async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await _api.get(ApiConfig.categories);
      state = state.copyWith(categories: List<Map<String, dynamic>>.from(res.data), isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadItems({int? categoryId}) async {
    state = state.copyWith(isLoading: true, selectedCategoryId: categoryId);
    try {
      final params = categoryId != null ? {'category_id': categoryId.toString()} : null;
      final res = await _api.get(ApiConfig.menuItems, queryParameters: params != null ? Map<String, dynamic>.from(params) : null);
      state = state.copyWith(items: List<Map<String, dynamic>>.from(res.data), isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> saveItem(Map<String, dynamic> data, {int? id}) async {
    try {
      if (id != null) {
        await _api.put('${ApiConfig.menuItems}/$id', data: data);
      } else {
        await _api.post(ApiConfig.menuItems, data: data);
      }
      await loadItems(categoryId: state.selectedCategoryId);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> deleteItem(int id) async {
    try {
      await _api.delete('${ApiConfig.menuItems}/$id');
      state = state.copyWith(items: state.items.where((i) => i['id'] != id).toList());
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> uploadImage(int itemId, String filePath) async {
    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(filePath),
      });
      await _api.upload('${ApiConfig.menuItems}/$itemId/image', formData);
      await loadItems(categoryId: state.selectedCategoryId);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> saveCategory(Map<String, dynamic> data, {int? id}) async {
    try {
      if (id != null) {
        await _api.put('${ApiConfig.categories}/$id', data: data);
      } else {
        await _api.post(ApiConfig.categories, data: data);
      }
      await loadCategories();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> deleteCategory(int id) async {
    try {
      await _api.delete('${ApiConfig.categories}/$id');
      await loadCategories();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

final menuProvider = StateNotifierProvider<MenuNotifier, MenuState>((ref) {
  return MenuNotifier(ref.watch(apiClientProvider));
});
