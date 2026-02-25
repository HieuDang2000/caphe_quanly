import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/menu_repository.dart';

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

  static const _undefined = Object();

  MenuState copyWith({
    List<Map<String, dynamic>>? categories,
    List<Map<String, dynamic>>? items,
    Object? selectedCategoryId = _undefined,
    bool? isLoading,
    String? error,
  }) {
    return MenuState(
      categories: categories ?? this.categories,
      items: items ?? this.items,
      selectedCategoryId: selectedCategoryId == _undefined ? this.selectedCategoryId : selectedCategoryId as int?,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class MenuNotifier extends StateNotifier<MenuState> {
  final MenuRepository _repo;
  MenuNotifier(this._repo) : super(const MenuState());

  Future<void> loadCategories() async {
    state = state.copyWith(isLoading: true);
    try {
      final data = await _repo.getCategories();
      state = state.copyWith(categories: data, isLoading: false);
      // Background refresh: repo already fires async API call; when we
      // force-refresh we pick up the latest data.
      _repo.getCategories(forceRefresh: true).then((fresh) {
        if (mounted) state = state.copyWith(categories: fresh);
      }).catchError((_) {});
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadItems({int? categoryId}) async {
    state = state.copyWith(isLoading: true, selectedCategoryId: categoryId);
    try {
      final data = await _repo.getItems(categoryId: categoryId);
      state = state.copyWith(items: data, isLoading: false);
      _repo.getItems(categoryId: categoryId).then((fresh) {
        if (mounted) state = state.copyWith(items: fresh);
      }).catchError((_) {});
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> saveItem(Map<String, dynamic> data, {int? id}) async {
    try {
      await _repo.saveItem(data, id: id);
      await loadItems(categoryId: state.selectedCategoryId);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> deleteItem(int id) async {
    try {
      await _repo.deleteItem(id);
      state = state.copyWith(items: state.items.where((i) => i['id'] != id).toList());
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> uploadImage(int itemId, String filePath) async {
    try {
      await _repo.uploadImage(itemId, filePath);
      await loadItems(categoryId: state.selectedCategoryId);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> saveCategory(Map<String, dynamic> data, {int? id}) async {
    try {
      await _repo.saveCategory(data, id: id);
      await loadCategories();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> deleteCategory(int id) async {
    try {
      await _repo.deleteCategory(id);
      await loadCategories();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

final menuProvider = StateNotifierProvider<MenuNotifier, MenuState>((ref) {
  return MenuNotifier(ref.watch(menuRepositoryProvider));
});
