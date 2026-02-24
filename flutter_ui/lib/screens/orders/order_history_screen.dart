import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/order_history_provider.dart';
import '../../widgets/loading_widget.dart';

String _todayVietnam() {
  final vn = DateTime.now().toUtc().add(const Duration(hours: 7));
  return '${vn.year}-${vn.month.toString().padLeft(2, '0')}-${vn.day.toString().padLeft(2, '0')}';
}

String _actionLabel(String action) {
  switch (action) {
    case 'created':
      return 'Tạo đơn';
    case 'items_added':
      return 'Thêm món';
    case 'updated':
      return 'Cập nhật';
    case 'status_changed':
      return 'Đổi trạng thái';
    default:
      return action;
  }
}

class OrderHistoryScreen extends ConsumerStatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  ConsumerState<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends ConsumerState<OrderHistoryScreen> {
  late String _selectedDate;
  String? _actionFilter;

  @override
  void initState() {
    super.initState();
    _selectedDate = _todayVietnam();
    Future.microtask(() {
      ref.read(orderHistoryProvider.notifier).loadActivities(date: _selectedDate, action: _actionFilter);
    });
  }

  Future<void> _pickDate() async {
    final d = DateTime.tryParse(_selectedDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: d ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().toUtc().add(const Duration(hours: 7)),
    );
    if (picked == null || !mounted) return;
    final dateStr = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    setState(() => _selectedDate = dateStr);
    ref.read(orderHistoryProvider.notifier).loadActivities(date: dateStr, action: _actionFilter);
  }

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(orderHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Chọn ngày',
            onPressed: _pickDate,
          ),
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Lọc thao tác',
            onSelected: (action) {
              setState(() => _actionFilter = action);
              ref.read(orderHistoryProvider.notifier).loadActivities(date: _selectedDate, action: action);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('Tất cả')),
              const PopupMenuItem(value: 'created', child: Text('Tạo đơn')),
              const PopupMenuItem(value: 'items_added', child: Text('Thêm món')),
              const PopupMenuItem(value: 'updated', child: Text('Cập nhật')),
              const PopupMenuItem(value: 'status_changed', child: Text('Đổi trạng thái')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 20, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      _selectedDate == _todayVietnam() ? 'Hôm nay' : Formatters.date(DateTime.parse(_selectedDate)),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: historyState.isLoading
                ? const LoadingWidget()
                : RefreshIndicator(
                    onRefresh: () => ref.read(orderHistoryProvider.notifier).loadActivities(date: _selectedDate, action: _actionFilter),
                    child: historyState.activities.isEmpty
                        ? const Center(child: Text('Chưa có thao tác nào'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: historyState.activities.length,
                            itemBuilder: (_, index) {
                              final a = historyState.activities[index];
                              final order = a['order'] as Map<String, dynamic>?;
                              final user = a['user'] as Map<String, dynamic>?;
                              final orderNumber = order?['order_number'] ?? '#${a['order_id']}';
                              DateTime? createdAt;
                              try {
                                if (a['created_at'] != null) createdAt = DateTime.parse(a['created_at'].toString());
                              } catch (_) {}
                              final action = a['action'] as String? ?? '';
                              final description = a['description'] as String? ?? '';

                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                                    child: Icon(_actionIcon(action), color: AppTheme.primaryColor, size: 20),
                                  ),
                                  title: Text(
                                    _actionLabel(action),
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (description.isNotEmpty) Text(description, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          if (createdAt != null)
                                            Text(Formatters.shortDateTime(createdAt), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                          const SizedBox(width: 8),
                                          Text(user?['name'] ?? '—', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                          const SizedBox(width: 8),
                                          Text('Đơn $orderNumber', style: TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.w500)),
                                        ],
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    final orderId = a['order_id'];
                                    if (orderId != null) context.push('/orders/list');
                                  },
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case 'created':
        return Icons.add_circle;
      case 'items_added':
        return Icons.add_shopping_cart;
      case 'updated':
        return Icons.edit;
      case 'status_changed':
        return Icons.swap_horiz;
      default:
        return Icons.history;
    }
  }
}
