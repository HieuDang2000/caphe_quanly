import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/order_provider.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/loading_widget.dart';

class OrderListScreen extends ConsumerStatefulWidget {
  const OrderListScreen({super.key});

  @override
  ConsumerState<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends ConsumerState<OrderListScreen> {
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(orderProvider.notifier).startPolling();
      ref.read(orderProvider.notifier).loadOrders();
    });
  }

  @override
  void dispose() {
    ref.read(orderProvider.notifier).stopPolling();
    super.dispose();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return AppTheme.warningColor;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return AppTheme.successColor;
      case 'cancelled':
        return AppTheme.errorColor;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderState = ref.watch(orderProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đơn hàng'),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (status) {
              setState(() => _statusFilter = status);
              ref.read(orderProvider.notifier).loadOrders(status: status);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('Tất cả')),
              const PopupMenuItem(value: 'pending', child: Text('Chờ xử lý')),
              const PopupMenuItem(value: 'in_progress', child: Text('Đang pha chế')),
              const PopupMenuItem(value: 'completed', child: Text('Hoàn thành')),
              const PopupMenuItem(value: 'cancelled', child: Text('Đã hủy')),
            ],
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: orderState.isLoading
          ? const LoadingWidget()
          : RefreshIndicator(
              onRefresh: () => ref.read(orderProvider.notifier).loadOrders(status: _statusFilter),
              child: orderState.orders.isEmpty
                  ? const Center(child: Text('Chưa có đơn hàng'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: orderState.orders.length,
                      itemBuilder: (_, index) {
                        final order = orderState.orders[index];
                        final status = order['status'] as String? ?? 'pending';
                        final items = List<Map<String, dynamic>>.from(order['items'] ?? []);

                        return Card(
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: _statusColor(status).withValues(alpha: 0.15),
                              child: Icon(Icons.receipt, color: _statusColor(status)),
                            ),
                            title: Text(order['order_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (order['table'] != null) Text('${order['table']['name']}'),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(color: _statusColor(status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                                      child: Text(Formatters.orderStatus(status), style: TextStyle(fontSize: 12, color: _statusColor(status), fontWeight: FontWeight.w600)),
                                    ),
                                    const Spacer(),
                                    Text(Formatters.currency(order['total'] ?? 0), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                                  ],
                                ),
                              ],
                            ),
                            children: [
                              ...items.map((item) => ListTile(
                                dense: true,
                                title: Text(item['menu_item']?['name'] ?? ''),
                                trailing: Text('x${item['quantity']} - ${Formatters.currency(item['subtotal'] ?? 0)}'),
                              )),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    if (status == 'pending')
                                      ElevatedButton(
                                        onPressed: () => ref.read(orderProvider.notifier).updateStatus(order['id'], 'in_progress'),
                                        child: const Text('Bắt đầu'),
                                      ),
                                    if (status == 'in_progress')
                                      ElevatedButton(
                                        onPressed: () => ref.read(orderProvider.notifier).updateStatus(order['id'], 'completed'),
                                        child: const Text('Hoàn thành'),
                                      ),
                                    if (status == 'pending' || status == 'in_progress')
                                      OutlinedButton(
                                        onPressed: () => ref.read(orderProvider.notifier).updateStatus(order['id'], 'cancelled'),
                                        child: const Text('Hủy', style: TextStyle(color: AppTheme.errorColor)),
                                      ),
                                    if (status == 'completed' && order['invoice'] == null)
                                      ElevatedButton.icon(
                                        onPressed: () => context.push('/invoice/${order['id']}'),
                                        icon: const Icon(Icons.receipt_long),
                                        label: const Text('Tạo HĐ'),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
