import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/report_provider.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/responsive_layout.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DateTime? _timeRangeDate;
  TimeOfDay? _timeRangeFrom;
  TimeOfDay? _timeRangeTo;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(reportProvider.notifier).applyToday());
  }

  @override
  Widget build(BuildContext context) {
    final reportState = ref.watch(reportProvider);
    final mobile = isMobile(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Báo cáo')),
      body: reportState.isLoading
          ? const LoadingWidget()
          : RefreshIndicator(
              onRefresh: () => ref.read(reportProvider.notifier).reload(),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(mobile ? 12 : 16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFilters(reportState),
                    const SizedBox(height: 20),
                    if (reportState.dailySummary != null) _buildDailySummary(reportState),
                    const SizedBox(height: 20),
                    _buildSalesChart(reportState.salesData),
                    const SizedBox(height: 20),
                    _buildCategoryPieChart(reportState.categoryRevenue),
                    const SizedBox(height: 20),
                    _buildTopItemsList(reportState.topItems),
                    const SizedBox(height: 20),
                    _buildTableUsage(reportState.tableUsage),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFilters(ReportState state) {
    final mobile = isMobile(context);
    final notifier = ref.read(reportProvider.notifier);
    final now = DateTime.now();

    Future<void> pickDateRange() async {
      final initialStart = state.fromDate ?? DateTime(now.year, now.month, now.day);
      final initialEnd = state.toDate ?? initialStart;
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 2),
        lastDate: DateTime(now.year + 2),
        initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      );
      if (picked != null) {
        await notifier.applyDateRange(picked.start, picked.end);
      }
    }

    final isTimeRange = state.rangeType == 'time_range';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bộ lọc thời gian', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: mobile ? 8 : 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<String>(
                  value: state.rangeType,
                  onChanged: (value) async {
                    if (value == null || value == state.rangeType) return;
                    switch (value) {
                      case 'today':
                        await notifier.applyToday();
                        break;
                      case 'date_range':
                        await pickDateRange();
                        break;
                      case 'month':
                        final month = state.month ?? now.month;
                        final year = state.year ?? now.year;
                        await notifier.applyMonth(month, year);
                        break;
                      case 'year':
                        final year = state.year ?? now.year;
                        await notifier.applyYear(year);
                        break;
                      case 'time_range':
                        final baseDate = DateTime(now.year, now.month, now.day);
                        final fromTime = const TimeOfDay(hour: 8, minute: 0);
                        final toTime = const TimeOfDay(hour: 22, minute: 0);
                        setState(() {
                          _timeRangeDate = baseDate;
                          _timeRangeFrom = fromTime;
                          _timeRangeTo = toTime;
                        });
                        final from = DateTime(baseDate.year, baseDate.month, baseDate.day, fromTime.hour, fromTime.minute);
                        final to = DateTime(baseDate.year, baseDate.month, baseDate.day, toTime.hour, toTime.minute);
                        await notifier.applyTimeRange(from, to);
                        break;
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: 'today', child: Text('Hôm nay')),
                    DropdownMenuItem(value: 'date_range', child: Text('Khoảng ngày')),
                    DropdownMenuItem(value: 'month', child: Text('Tháng')),
                    DropdownMenuItem(value: 'year', child: Text('Năm')),
                    DropdownMenuItem(value: 'time_range', child: Text('Khung giờ')),
                  ],
                ),
                if (state.rangeType == 'today')
                  Text(
                    'Hôm nay',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (state.rangeType == 'date_range')
                  OutlinedButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: const Text('Chọn khoảng ngày'),
                    onPressed: pickDateRange,
                  ),
                if (state.rangeType == 'month') ...[
                  DropdownButton<int>(
                    value: state.month ?? now.month,
                    onChanged: (m) async {
                      if (m == null) return;
                      await notifier.applyMonth(m, state.year ?? now.year);
                    },
                    items: List.generate(
                      12,
                      (index) => DropdownMenuItem(
                        value: index + 1,
                        child: Text('Tháng ${index + 1}'),
                      ),
                    ),
                  ),
                  DropdownButton<int>(
                    value: state.year ?? now.year,
                    onChanged: (y) async {
                      if (y == null) return;
                      await notifier.applyMonth(state.month ?? now.month, y);
                    },
                    items: List.generate(
                      5,
                      (index) {
                        final year = now.year - 2 + index;
                        return DropdownMenuItem(
                          value: year,
                          child: Text('$year'),
                        );
                      },
                    ),
                  ),
                ],
                if (state.rangeType == 'year')
                  DropdownButton<int>(
                    value: state.year ?? now.year,
                    onChanged: (y) async {
                      if (y == null) return;
                      await notifier.applyYear(y);
                    },
                    items: List.generate(
                      5,
                      (index) {
                        final year = now.year - 2 + index;
                        return DropdownMenuItem(
                          value: year,
                          child: Text('$year'),
                        );
                      },
                    ),
                  ),
              ],
            ),
            if (isTimeRange) ...[
              const SizedBox(height: 12),
              // Khung giờ nhanh: 06-12, 12-18, 18-23
              Wrap(
                spacing: mobile ? 8 : 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Khung giờ nhanh:',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      final baseDate = _timeRangeDate ?? DateTime(now.year, now.month, now.day);
                      const fromTime = TimeOfDay(hour: 6, minute: 0);
                      const toTime = TimeOfDay(hour: 12, minute: 0);
                      setState(() {
                        _timeRangeDate = baseDate;
                        _timeRangeFrom = fromTime;
                        _timeRangeTo = toTime;
                      });
                      final from = DateTime(baseDate.year, baseDate.month, baseDate.day, fromTime.hour, fromTime.minute);
                      final to = DateTime(baseDate.year, baseDate.month, baseDate.day, toTime.hour, toTime.minute);
                      await notifier.applyTimeRange(from, to);
                    },
                    child: const Text('06:00 - 12:00'),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      final baseDate = _timeRangeDate ?? DateTime(now.year, now.month, now.day);
                      const fromTime = TimeOfDay(hour: 12, minute: 0);
                      const toTime = TimeOfDay(hour: 18, minute: 0);
                      setState(() {
                        _timeRangeDate = baseDate;
                        _timeRangeFrom = fromTime;
                        _timeRangeTo = toTime;
                      });
                      final from = DateTime(baseDate.year, baseDate.month, baseDate.day, fromTime.hour, fromTime.minute);
                      final to = DateTime(baseDate.year, baseDate.month, baseDate.day, toTime.hour, toTime.minute);
                      await notifier.applyTimeRange(from, to);
                    },
                    child: const Text('12:00 - 18:00'),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      final baseDate = _timeRangeDate ?? DateTime(now.year, now.month, now.day);
                      const fromTime = TimeOfDay(hour: 18, minute: 0);
                      const toTime = TimeOfDay(hour: 23, minute: 0);
                      setState(() {
                        _timeRangeDate = baseDate;
                        _timeRangeFrom = fromTime;
                        _timeRangeTo = toTime;
                      });
                      final from = DateTime(baseDate.year, baseDate.month, baseDate.day, fromTime.hour, fromTime.minute);
                      final to = DateTime(baseDate.year, baseDate.month, baseDate.day, toTime.hour, toTime.minute);
                      await notifier.applyTimeRange(from, to);
                    },
                    child: const Text('18:00 - 23:00'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Khung giờ tùy chọn
              Wrap(
                spacing: mobile ? 8 : 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.event),
                    label: Text(
                      _timeRangeDate != null
                          ? Formatters.date(_timeRangeDate!)
                          : 'Chọn ngày',
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(now.year - 2),
                        lastDate: DateTime(now.year + 2),
                        initialDate: _timeRangeDate ?? DateTime(now.year, now.month, now.day),
                      );
                      if (picked != null) {
                        setState(() {
                          _timeRangeDate = picked;
                        });
                      }
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.access_time),
                    label: Text(
                      _timeRangeFrom != null
                          ? _timeRangeFrom!.format(context)
                          : 'Giờ bắt đầu',
                    ),
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _timeRangeFrom ?? TimeOfDay.now(),
                      );
                      if (picked != null) {
                        setState(() {
                          _timeRangeFrom = picked;
                        });
                      }
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.access_time_filled),
                    label: Text(
                      _timeRangeTo != null
                          ? _timeRangeTo!.format(context)
                          : 'Giờ kết thúc',
                    ),
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _timeRangeTo ?? TimeOfDay.now(),
                      );
                      if (picked != null) {
                        setState(() {
                          _timeRangeTo = picked;
                        });
                      }
                    },
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (_timeRangeDate == null || _timeRangeFrom == null || _timeRangeTo == null) {
                        return;
                      }
                      final d = _timeRangeDate!;
                      final from = DateTime(d.year, d.month, d.day, _timeRangeFrom!.hour, _timeRangeFrom!.minute);
                      final to = DateTime(d.year, d.month, d.day, _timeRangeTo!.hour, _timeRangeTo!.minute);
                      await notifier.applyTimeRange(from, to);
                    },
                    child: const Text('Áp dụng'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _buildRangeLabel(ReportState state) {
    switch (state.rangeType) {
      case 'today':
        if (state.fromDate != null) return Formatters.date(state.fromDate!);
        return null;
      case 'date_range':
        if (state.fromDate != null && state.toDate != null) {
          final from = Formatters.date(state.fromDate!);
          final to = Formatters.date(state.toDate!);
          if (from == to) return from;
          return '$from - $to';
        }
        return null;
      case 'month':
        if (state.month != null && state.year != null) {
          return 'Tháng ${state.month}/${state.year}';
        }
        return null;
      case 'year':
        if (state.year != null) {
          return 'Năm ${state.year}';
        }
        return null;
      case 'time_range':
        if (state.fromDateTime != null && state.toDateTime != null) {
          final from = Formatters.dateTime(state.fromDateTime!);
          final to = Formatters.dateTime(state.toDateTime!);
          return '$from - $to';
        }
        return null;
      default:
        return null;
    }
  }

  Widget _buildDailySummary(ReportState state) {
    final summary = state.dailySummary!;
    final discrepancy = state.discrepancyStats;
    final title = state.rangeType == 'today' ? 'Tổng hợp hôm nay' : 'Tổng hợp';
    final rangeLabel = _buildRangeLabel(state);

    final discrepancyCount = Formatters.toNum(discrepancy?['discrepancy_orders_count']).toInt();
    final deletedItemCount = Formatters.toNum(discrepancy?['deleted_item_orders_count']).toInt();

    final mobile = isMobile(context);
    final spacing = mobile ? 8.0 : 12.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (rangeLabel != null) ...[
          const SizedBox(height: 4),
          Text(rangeLabel, style: Theme.of(context).textTheme.bodySmall),
        ],
        SizedBox(height: spacing),
        Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            _SummaryCard(title: 'Doanh thu', value: Formatters.currency(summary['total_revenue'] ?? 0), icon: Icons.attach_money, color: AppTheme.primaryColor),
            _SummaryCard(title: 'Đơn hàng', value: '${summary['total_orders'] ?? 0}', icon: Icons.receipt, color: Colors.blue),
            _SummaryCard(title: 'Hoàn thành', value: '${summary['completed_orders'] ?? 0}', icon: Icons.check_circle, color: AppTheme.successColor),
            _SummaryCard(title: 'Chờ xử lý', value: '${summary['pending_orders'] ?? 0}', icon: Icons.pending, color: AppTheme.warningColor),
            _SummaryCard(title: 'Đơn hủy', value: '${summary['cancelled_orders'] ?? 0}', icon: Icons.cancel, color: Colors.redAccent),
            if (discrepancy != null) ...[
              _SummaryCard(title: 'Đơn chênh lệch', value: '$discrepancyCount', icon: Icons.report, color: Colors.deepOrange),
              _SummaryCard(title: 'Đơn có xóa món', value: '$deletedItemCount', icon: Icons.delete_sweep, color: Colors.purple),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildSalesChart(Map<String, dynamic>? salesData) {
    if (salesData == null) return const SizedBox.shrink();
    final dailySales = List<Map<String, dynamic>>.from(salesData['daily_sales'] ?? []);
    if (dailySales.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Doanh thu theo ngày', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  barGroups: dailySales.asMap().entries.map((entry) {
                    return BarChartGroupData(x: entry.key, barRods: [
                      BarChartRodData(
                        toY: Formatters.toNum(entry.value['revenue']).toDouble() / 1000,
                        color: AppTheme.primaryColor,
                        width: 16,
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                      ),
                    ]);
                  }).toList(),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, _) => Text('${v.toInt()}k', style: const TextStyle(fontSize: 10)))),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx < dailySales.length) {
                          final date = dailySales[idx]['date'] as String;
                          return Text(date.substring(8), style: const TextStyle(fontSize: 10));
                        }
                        return const Text('');
                      },
                    )),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPieChart(List<Map<String, dynamic>> categories) {
    if (categories.isEmpty) return const SizedBox.shrink();
    final colors = [AppTheme.primaryColor, AppTheme.secondaryColor, AppTheme.accentColor, Colors.teal, Colors.indigo, Colors.pink];
    final totalRevenue = categories.fold<num>(0, (sum, c) => sum + Formatters.toNum(c['revenue']));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Doanh thu theo danh mục', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sections: categories.asMap().entries.map((entry) {
                          final pct = totalRevenue > 0 ? Formatters.toNum(entry.value['revenue']) / totalRevenue * 100 : 0;
                          return PieChartSectionData(
                            value: Formatters.toNum(entry.value['revenue']).toDouble(),
                            color: colors[entry.key % colors.length],
                            title: '${pct.toStringAsFixed(0)}%',
                            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            radius: 60,
                          );
                        }).toList(),
                        sectionsSpace: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: categories.asMap().entries.map((entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 12, height: 12, color: colors[entry.key % colors.length]),
                          const SizedBox(width: 6),
                          Text(entry.value['name'] ?? '', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopItemsList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Món bán chạy nhất', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(),
            ...items.asMap().entries.map((entry) => ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: AppTheme.primaryColor,
                child: Text('${entry.key + 1}', style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
              title: Text(entry.value['name'] ?? ''),
              subtitle: Text('Số lượng: ${entry.value['total_quantity']}'),
              trailing: Text(Formatters.currency(entry.value['total_revenue'] ?? 0), style: const TextStyle(fontWeight: FontWeight.bold)),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildTableUsage(List<Map<String, dynamic>> tables) {
    if (tables.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sử dụng bàn', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(),
            ...tables.map((t) => ListTile(
              dense: true,
              leading: const Icon(Icons.table_restaurant, color: AppTheme.primaryColor),
              title: Text(t['name'] ?? ''),
              subtitle: Text('${t['usage_count']} lần sử dụng'),
              trailing: Text(Formatters.currency(t['revenue'] ?? 0)),
            )),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140, maxWidth: 220),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: color.withValues(alpha: 0.15), child: Icon(icon, color: color)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
