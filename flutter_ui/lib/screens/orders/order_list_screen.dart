import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/order_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../services/receipt_printer.dart';
import '../../widgets/loading_widget.dart';

/// Ngày hôm nay theo giờ Việt Nam (UTC+7), định dạng YYYY-MM-DD.
String _todayVietnam() {
  final vn = DateTime.now().toUtc().add(const Duration(hours: 7));
  return '${vn.year}-${vn.month.toString().padLeft(2, '0')}-${vn.day.toString().padLeft(2, '0')}';
}

class OrderListScreen extends ConsumerStatefulWidget {
  const OrderListScreen({super.key});

  @override
  ConsumerState<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends ConsumerState<OrderListScreen> {
  String? _statusFilter;
  late String _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = _todayVietnam();
    Future.microtask(() {
      ref.read(orderProvider.notifier).startPolling();
      ref.read(orderProvider.notifier).loadOrders(status: _statusFilter, date: _selectedDate);
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
      case 'paid':
        return AppTheme.primaryColor;
      case 'cancelled':
        return AppTheme.errorColor;
      default:
        return Colors.grey;
    }
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
    ref.read(orderProvider.notifier).loadOrders(status: _statusFilter, date: dateStr);
  }

  @override
  Widget build(BuildContext context) {
    final orderState = ref.watch(orderProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đơn hàng'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Chọn ngày',
            onPressed: _pickDate,
          ),
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (status) {
              setState(() => _statusFilter = status);
              ref.read(orderProvider.notifier).loadOrders(status: status, date: _selectedDate);
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
            child: orderState.isLoading
                ? const LoadingWidget()
                : RefreshIndicator(
                    onRefresh: () => ref.read(orderProvider.notifier).loadOrders(status: _statusFilter, date: _selectedDate),
                    child: orderState.orders.isEmpty
                  ? const Center(child: Text('Chưa có đơn hàng'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: orderState.orders.length,
                      itemBuilder: (_, index) {
                        final order = orderState.orders[index];
                        final status = order['status'] as String? ?? 'pending';
                        final items = List<Map<String, dynamic>>.from(order['items'] ?? []);
                        final isTakeaway = order['table_id'] == null && order['table'] == null;
                        DateTime? orderTime;
                        try {
                          if (order['created_at'] != null) orderTime = DateTime.parse(order['created_at'].toString());
                        } catch (_) {}

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
                                Row(
                                  children: [
                                    Text(isTakeaway ? 'Bán mang đi' : '${order['table']?['name'] ?? ''}'),
                                    if (orderTime != null) ...[
                                      const SizedBox(width: 8),
                                      Text(Formatters.shortDateTime(orderTime), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                    ],
                                  ],
                                ),
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
                              ...items.map((item) {
                                final opts = item['options'] as List? ?? [];
                                final note = item['notes'] as String?;
                                final hasOpts = opts.isNotEmpty;
                                final hasNote = note != null && note.trim().isNotEmpty;
                                final optText = hasOpts
                                    ? opts.map((o) => o is Map ? '${o['name']} +${Formatters.currency(Formatters.toNum(o['extra_price']))}' : '').where((s) => s.isNotEmpty).join(' · ')
                                    : null;
                                return ListTile(
                                  dense: true,
                                  title: Text(item['menu_item']?['name'] ?? ''),
                                  subtitle: (hasOpts || hasNote)
                                      ? Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (optText != null && optText.isNotEmpty)
                                              Text(optText, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                            if (hasNote)
                                              Text('Ghi chú: $note', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
                                          ],
                                        )
                                      : null,
                                  trailing: Text('x${item['quantity']} - ${Formatters.currency(item['subtotal'] ?? 0)}'),
                                );
                              }),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    if (status == 'pending')
                                      ElevatedButton(
                                        onPressed: () => ref.read(orderProvider.notifier).updateStatus(order['id'], 'in_progress', statusFilter: _statusFilter, date: _selectedDate),
                                        child: const Text('Bắt đầu'),
                                      ),
                                    if (status == 'in_progress')
                                      ElevatedButton(
                                        onPressed: () => ref.read(orderProvider.notifier).updateStatus(order['id'], 'completed', statusFilter: _statusFilter, date: _selectedDate),
                                        child: const Text('Hoàn thành'),
                                      ),
                                    if (status == 'pending' || status == 'in_progress')
                                      OutlinedButton(
                                        onPressed: () => ref.read(orderProvider.notifier).updateStatus(order['id'], 'cancelled', statusFilter: _statusFilter, date: _selectedDate),
                                        child: const Text('Hủy', style: TextStyle(color: AppTheme.errorColor)),
                                      ),
                                    if (status == 'completed') ...[
                                      OutlinedButton(
                                        onPressed: () => ref.read(orderProvider.notifier).updateStatus(order['id'], 'in_progress', statusFilter: _statusFilter, date: _selectedDate),
                                        child: const Text('Về đang pha chế'),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          final invoice = await ref.read(invoiceProvider.notifier).generateInvoice(order['id'] as int);
                                          if (!mounted || invoice == null) return;
                                          context.push('/payment/${invoice['id']}');
                                        },
                                        icon: const Icon(Icons.payment),
                                        label: const Text('Thanh toán'),
                                      ),
                                    ],
                                    if (status == 'paid' && order['invoice'] != null) ...[
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          final invId = order['invoice']['id'] as int?;
                                          if (invId == null) return;
                                          final invoice = await ref.read(invoiceProvider.notifier).loadInvoice(invId);
                                          if (!mounted || invoice == null) return;
                                          final saved = await ReceiptPrinter.saveA4ToFile(invoice: invoice);
                                          if (mounted && saved) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Đã lưu hoá đơn A4')),
                                            );
                                          }
                                        },
                                        icon: const Icon(Icons.picture_as_pdf),
                                        label: const Text('Tải PDF A4'),
                                      ),
                                      // ElevatedButton.icon(
                                      //   onPressed: () async {
                                      //     final invId = order['invoice']['id'] as int?;
                                      //     if (invId == null) return;
                                      //     final invoice = await ref.read(invoiceProvider.notifier).loadInvoice(invId);
                                      //     if (!mounted || invoice == null) return;
                                      //     final saved = await ReceiptPrinter.save80mmToFile(invoice: invoice);
                                      //     if (mounted && saved) {
                                      //       ScaffoldMessenger.of(context).showSnackBar(
                                      //         const SnackBar(content: Text('Đã lưu hoá đơn 80mm')),
                                      //       );
                                      //     }
                                      //   },
                                      //   icon: const Icon(Icons.receipt_long),
                                      //   label: const Text('Tải 80mm'),
                                      // ),
                                      OutlinedButton.icon(
                                        onPressed: () async {
                                          final invId = order['invoice']['id'] as int?;
                                          if (invId == null) return;
                                          final invoice = await ref.read(invoiceProvider.notifier).loadInvoice(invId);
                                          if (!mounted || invoice == null) return;
                                          await ReceiptPrinter.print80mm(invoice: invoice);
                                        },
                                        icon: const Icon(Icons.print),
                                        label: const Text('In hóa đơn'),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
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
}
