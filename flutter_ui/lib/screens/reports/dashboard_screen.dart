import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/report_provider.dart';
import '../../widgets/loading_widget.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(reportProvider.notifier).loadAll());
  }

  @override
  Widget build(BuildContext context) {
    final reportState = ref.watch(reportProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Báo cáo')),
      body: reportState.isLoading
          ? const LoadingWidget()
          : RefreshIndicator(
              onRefresh: () => ref.read(reportProvider.notifier).loadAll(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (reportState.dailySummary != null) _buildDailySummary(reportState.dailySummary!),
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

  Widget _buildDailySummary(Map<String, dynamic> summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tổng hợp hôm nay', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Row(
          children: [
            _SummaryCard(title: 'Doanh thu', value: Formatters.currency(summary['total_revenue'] ?? 0), icon: Icons.attach_money, color: AppTheme.primaryColor),
            const SizedBox(width: 12),
            _SummaryCard(title: 'Đơn hàng', value: '${summary['total_orders'] ?? 0}', icon: Icons.receipt, color: Colors.blue),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _SummaryCard(title: 'Hoàn thành', value: '${summary['completed_orders'] ?? 0}', icon: Icons.check_circle, color: AppTheme.successColor),
            const SizedBox(width: 12),
            _SummaryCard(title: 'Chờ xử lý', value: '${summary['pending_orders'] ?? 0}', icon: Icons.pending, color: AppTheme.warningColor),
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
    return Expanded(
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
