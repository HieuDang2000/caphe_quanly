import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/receipt_template_repository.dart';

class ReceiptTemplateState {
  final ReceiptTemplate template;
  final bool isLoading;
  final bool initialized;
  final String? error;

  const ReceiptTemplateState({
    required this.template,
    this.isLoading = false,
    this.initialized = false,
    this.error,
  });

  ReceiptTemplateState copyWith({
    ReceiptTemplate? template,
    bool? isLoading,
    bool? initialized,
    String? error,
  }) {
    return ReceiptTemplateState(
      template: template ?? this.template,
      isLoading: isLoading ?? this.isLoading,
      initialized: initialized ?? this.initialized,
      error: error,
    );
  }
}

class ReceiptTemplateNotifier extends StateNotifier<ReceiptTemplateState> {
  ReceiptTemplateNotifier(this._repo)
      : super(ReceiptTemplateState(template: ReceiptTemplate.defaults())) {
    _init();
  }

  final ReceiptTemplateRepository _repo;

  Future<void> _init() async {
    await loadInitial();
  }

  Future<void> loadInitial() async {
    if (state.initialized) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final tpl = await _repo.loadReceiptTemplate();
      state = state.copyWith(
        template: tpl ?? ReceiptTemplate.defaults(),
        isLoading: false,
        initialized: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        initialized: true,
        error: e.toString(),
      );
    }
  }

  void updateTemplate(ReceiptTemplate template) {
    state = state.copyWith(template: template, error: null);
  }

  Future<void> save() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.saveReceiptTemplate(state.template);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> resetToDefaults() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.clearReceiptTemplate();
      state = state.copyWith(
        template: ReceiptTemplate.defaults(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }
}

final receiptTemplateProvider =
    StateNotifierProvider<ReceiptTemplateNotifier, ReceiptTemplateState>((ref) {
  return ReceiptTemplateNotifier(ref.watch(receiptTemplateRepositoryProvider));
});

