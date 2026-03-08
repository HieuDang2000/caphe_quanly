import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../repositories/printer_repository.dart';

class PrinterState {
  final List<Printer> printers;
  final PrinterConfig? config;
  final Printer? selectedPrinter;
  final bool isLoading;
  final bool initialized;
  final String? error;

  const PrinterState({
    this.printers = const [],
    this.config,
    this.selectedPrinter,
    this.isLoading = false,
    this.initialized = false,
    this.error,
  });

  PrinterState copyWith({
    List<Printer>? printers,
    PrinterConfig? config,
    Printer? selectedPrinter,
    bool? isLoading,
    bool? initialized,
    String? error,
  }) {
    return PrinterState(
      printers: printers ?? this.printers,
      config: config ?? this.config,
      selectedPrinter: selectedPrinter ?? this.selectedPrinter,
      isLoading: isLoading ?? this.isLoading,
      initialized: initialized ?? this.initialized,
      error: error,
    );
  }

  bool get hasSelectedPrinter => selectedPrinter != null;
}

class PrinterNotifier extends StateNotifier<PrinterState> {
  PrinterNotifier(this._repo) : super(const PrinterState()) {
    _init();
  }

  final PrinterRepository _repo;

  Future<void> _init() async {
    await loadInitial();
  }

  Future<void> loadInitial() async {
    if (state.initialized) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final config = await _repo.loadPrinterConfig();
      final printers = await Printing.listPrinters();
      final selected = _matchPrinter(printers, config);

      state = state.copyWith(
        printers: printers,
        config: config,
        selectedPrinter: selected,
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

  Future<void> refreshPrinters() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final printers = await Printing.listPrinters();
      final selected = _matchPrinter(printers, state.config);
      state = state.copyWith(
        printers: printers,
        selectedPrinter: selected,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> selectSystemPrinter(Printer printer, {String paperSize = '80mm'}) async {
    final config = PrinterConfig(
      id: printer.url,
      name: printer.name,
      type: 'system',
      paperSize: paperSize,
    );
    state = state.copyWith(
      config: config,
      selectedPrinter: printer,
      error: null,
    );
    await _repo.savePrinterConfig(config);
  }

  Future<void> clearSelection() async {
    state = state.copyWith(
      config: null,
      selectedPrinter: null,
      error: null,
    );
    await _repo.clearPrinterConfig();
  }

  Printer? _matchPrinter(List<Printer> printers, PrinterConfig? config) {
    if (config == null) return null;
    if (printers.isEmpty) return null;

    // Ưu tiên khớp theo id/url, sau đó tới name.
    final byId = printers.where((p) => p.url == config.id).toList();
    if (byId.isNotEmpty) return byId.first;

    final byName = printers.where((p) => p.name == config.name).toList();
    if (byName.isNotEmpty) return byName.first;

    return null;
  }
}

final printerProvider =
    StateNotifierProvider<PrinterNotifier, PrinterState>((ref) {
  return PrinterNotifier(ref.watch(printerRepositoryProvider));
});

