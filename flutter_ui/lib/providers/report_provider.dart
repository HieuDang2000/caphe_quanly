import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/report_repository.dart';

class ReportState {
  final Map<String, dynamic>? salesData;
  final List<Map<String, dynamic>> topItems;
  final List<Map<String, dynamic>> categoryRevenue;
  final List<Map<String, dynamic>> tableUsage;
  final Map<String, dynamic>? dailySummary;
  final Map<String, dynamic>? discrepancyStats;
  final bool isLoading;
  final String? error;

  /// Kiểu khoảng thời gian hiện tại: today, date_range, month, year, time_range.
  final String rangeType;
  final DateTime? fromDate;
  final DateTime? toDate;
  final int? month;
  final int? year;
  final DateTime? fromDateTime;
  final DateTime? toDateTime;

  const ReportState({
    this.salesData,
    this.topItems = const [],
    this.categoryRevenue = const [],
    this.tableUsage = const [],
    this.dailySummary,
    this.discrepancyStats,
    this.isLoading = false,
    this.error,
    this.rangeType = 'today',
    this.fromDate,
    this.toDate,
    this.month,
    this.year,
    this.fromDateTime,
    this.toDateTime,
  });

  ReportState copyWith({
    Map<String, dynamic>? salesData,
    List<Map<String, dynamic>>? topItems,
    List<Map<String, dynamic>>? categoryRevenue,
    List<Map<String, dynamic>>? tableUsage,
    Map<String, dynamic>? dailySummary,
    Map<String, dynamic>? discrepancyStats,
    bool? isLoading,
    String? error,
    String? rangeType,
    DateTime? fromDate,
    DateTime? toDate,
    int? month,
    int? year,
    DateTime? fromDateTime,
    DateTime? toDateTime,
  }) {
    return ReportState(
      salesData: salesData ?? this.salesData,
      topItems: topItems ?? this.topItems,
      categoryRevenue: categoryRevenue ?? this.categoryRevenue,
      tableUsage: tableUsage ?? this.tableUsage,
      dailySummary: dailySummary ?? this.dailySummary,
      discrepancyStats: discrepancyStats ?? this.discrepancyStats,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      rangeType: rangeType ?? this.rangeType,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      month: month ?? this.month,
      year: year ?? this.year,
      fromDateTime: fromDateTime ?? this.fromDateTime,
      toDateTime: toDateTime ?? this.toDateTime,
    );
  }
}

class ReportNotifier extends StateNotifier<ReportState> {
  final ReportRepository _repo;

  ReportNotifier(this._repo) : super(const ReportState());

  static String _formatDate(DateTime date) {
    return date.toIso8601String().substring(0, 10);
  }

  Future<void> loadAll({String? from, String? to}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait([
        _repo.salesData(from: from, to: to),
        _repo.topItems(from: from, to: to),
        _repo.categoryRevenue(from: from, to: to),
        _repo.tableUsage(from: from, to: to),
        _repo.summary(from: from, to: to),
        _repo.discrepancyStats(from: from, to: to),
      ]);

      state = state.copyWith(
        salesData: results[0] as Map<String, dynamic>,
        topItems: results[1] as List<Map<String, dynamic>>,
        categoryRevenue: results[2] as List<Map<String, dynamic>>,
        tableUsage: results[3] as List<Map<String, dynamic>>,
        dailySummary: results[4] as Map<String, dynamic>,
        discrepancyStats: results[5] as Map<String, dynamic>,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> applyToday() async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day);
    final to = from.add(const Duration(days: 1));

    state = state.copyWith(
      rangeType: 'today',
      fromDate: from,
      toDate: to.subtract(const Duration(milliseconds: 1)),
      month: now.month,
      year: now.year,
      fromDateTime: null,
      toDateTime: null,
    );

    await loadAll(from: _formatDate(from), to: _formatDate(to));
  }

  Future<void> applyDateRange(DateTime from, DateTime to) async {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day).add(const Duration(days: 1));

    state = state.copyWith(
      rangeType: 'date_range',
      fromDate: start,
      toDate: end.subtract(const Duration(milliseconds: 1)),
      month: null,
      year: null,
      fromDateTime: null,
      toDateTime: null,
    );

    await loadAll(from: _formatDate(start), to: _formatDate(end));
  }

  Future<void> applyMonth(int month, int year) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);

    state = state.copyWith(
      rangeType: 'month',
      fromDate: start,
      toDate: end.subtract(const Duration(milliseconds: 1)),
      month: month,
      year: year,
      fromDateTime: null,
      toDateTime: null,
    );

    await loadAll(from: _formatDate(start), to: _formatDate(end));
  }

  Future<void> applyYear(int year) async {
    final start = DateTime(year, 1, 1);
    final end = DateTime(year + 1, 1, 1);

    state = state.copyWith(
      rangeType: 'year',
      fromDate: start,
      toDate: end.subtract(const Duration(milliseconds: 1)),
      month: null,
      year: year,
      fromDateTime: null,
      toDateTime: null,
    );

    await loadAll(from: _formatDate(start), to: _formatDate(end));
  }

  Future<void> applyTimeRange(DateTime from, DateTime to) async {
    var start = from;
    var end = to;
    if (end.isBefore(start)) {
      final tmp = start;
      start = end;
      end = tmp;
    }

    state = state.copyWith(
      rangeType: 'time_range',
      fromDateTime: start,
      toDateTime: end,
      fromDate: start,
      toDate: end,
      month: null,
      year: null,
    );

    await loadAll(from: start.toIso8601String(), to: end.toIso8601String());
  }

  Future<void> reload() async {
    final s = state;
    switch (s.rangeType) {
      case 'today':
        await applyToday();
        break;
      case 'date_range':
        if (s.fromDate != null && s.toDate != null) {
          await applyDateRange(s.fromDate!, s.toDate!);
        } else {
          await applyToday();
        }
        break;
      case 'month':
        if (s.month != null && s.year != null) {
          await applyMonth(s.month!, s.year!);
        } else {
          await applyToday();
        }
        break;
      case 'year':
        if (s.year != null) {
          await applyYear(s.year!);
        } else {
          await applyToday();
        }
        break;
      case 'time_range':
        if (s.fromDateTime != null && s.toDateTime != null) {
          await applyTimeRange(s.fromDateTime!, s.toDateTime!);
        } else {
          await applyToday();
        }
        break;
      default:
        await applyToday();
        break;
    }
  }
}

final reportProvider = StateNotifierProvider<ReportNotifier, ReportState>((ref) {
  return ReportNotifier(ref.watch(reportRepositoryProvider));
});
