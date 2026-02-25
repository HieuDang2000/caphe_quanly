import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/order_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../services/receipt_printer.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/responsive_layout.dart';

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
  final Map<int, Set<int>> _selectedItemsByOrder = {};

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
      case 'paid':
        return AppTheme.primaryColor;
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
    final mobile = isMobile(context);

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
              const PopupMenuItem(value: 'pending', child: Text('Đang chờ')),
              const PopupMenuItem(value: 'paid', child: Text('Đã thanh toán')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: mobile ? 8 : 12, vertical: mobile ? 6 : 8),
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
                  : Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: mobile ? double.infinity : 800),
                        child: ListView.builder(
                          padding: EdgeInsets.all(mobile ? 8 : 12),
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
                          margin: EdgeInsets.only(bottom: mobile ? 6 : 8),
                          child: ExpansionTile(
                            initiallyExpanded: status != 'paid',
                            leading: CircleAvatar(
                              backgroundColor: _statusColor(status).withValues(alpha: 0.15),
                              child: Icon(Icons.receipt, color: _statusColor(status)),
                            ),
                            title: mobile
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${isTakeaway ? 'Bán mang đi' : order['table']?['name'] ?? ''} · ${order['order_number'] ?? ''}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (orderTime != null)
                                        Text(Formatters.shortDateTime(orderTime), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                    ],
                                  )
                                : Row(children: [
                                    Flexible(child: Text(isTakeaway ? 'Bán mang đi : ' : '${order['table']?['name'] ?? ''} : ', style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                    Text(order['order_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    if (orderTime != null) ...[
                                      const SizedBox(width: 8),
                                      Text(Formatters.shortDateTime(orderTime), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                    ],
                                  ]),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                                final isItemPaid = (item['is_paid'] == true);
                                final hasOpts = opts.isNotEmpty;
                                final hasNote = note != null && note.trim().isNotEmpty;
                                final optText = hasOpts
                                    ? opts.map((o) => o is Map ? '${o['name']} +${Formatters.currency(Formatters.toNum(o['extra_price']))}' : '').where((s) => s.isNotEmpty).join(' · ')
                                    : null;
                                final orderId = order['id'] as int;
                                final itemId = item['id'] as int;
                                final canSelect = status == 'pending' && !isItemPaid;
                                final selectedSet = _selectedItemsByOrder[orderId] ?? <int>{};
                                final isSelected = canSelect && selectedSet.contains(itemId);

                                return CheckboxListTile(
                                  dense: true,
                                  controlAffinity: ListTileControlAffinity.leading,
                                  value: canSelect ? isSelected : isItemPaid,
                                  onChanged: canSelect
                                      ? (checked) {
                                          setState(() {
                                            final current = _selectedItemsByOrder[orderId] ?? <int>{};
                                            if (checked == true) {
                                              current.add(itemId);
                                            } else {
                                              current.remove(itemId);
                                            }
                                            _selectedItemsByOrder[orderId] = current;
                                          });
                                        }
                                      : null,
                                  title: Row(
                                    children: [
                                      Expanded(child: Text(item['menu_item']?['name'] ?? '')),
                                      if (isItemPaid)
                                        Container(
                                          margin: const EdgeInsets.only(left: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.successColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            'Đã TT',
                                            style: TextStyle(fontSize: 11, color: AppTheme.successColor, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                    ],
                                  ),
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
                                  secondary: Text('x${item['quantity']} - ${Formatters.currency(item['subtotal'] ?? 0)}'),
                                );
                              }),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  spacing: 8,
                                  children: [
                                    if (status == 'pending') ...[
                                      ElevatedButton(
                                        onPressed: () => ref.read(orderProvider.notifier).updateStatus(order['id'], 'paid', statusFilter: _statusFilter, date: _selectedDate),
                                        child: const Text('Thanh toán toàn bộ'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () async {
                                          final orderId = order['id'] as int?;
                                          if (orderId == null) return;
                                          final selected = _selectedItemsByOrder[orderId] ?? <int>{};
                                          if (selected.isEmpty) return;
                                          await ref.read(orderProvider.notifier).payItems(orderId, selected.toList(), statusFilter: _statusFilter, date: _selectedDate);
                                          if (!mounted) return;
                                          setState(() {
                                            _selectedItemsByOrder[orderId] = <int>{};
                                          });
                                        },
                                        child: const Text('Thanh toán một phần'),
                                      ),
                                    ],
                                    if (status == 'paid')
                                      OutlinedButton(
                                        onPressed: () async {
                                          await ref.read(orderProvider.notifier).updateStatus(order['id'], 'pending', statusFilter: _statusFilter, date: _selectedDate);
                                          if (!mounted) return;
                                          setState(() {
                                            _selectedItemsByOrder.remove(order['id']);
                                          });
                                        },
                                        child: const Text('Về chờ xử lý'),
                                      ),
                                    ElevatedButton.icon(
                                      onPressed: () async {
                                        final orderId = order['id'] as int?;
                                        if (orderId == null) return;

                                        // Nếu đã có invoice gắn với order thì load lại, nếu chưa thì generate mới
                                        Map<String, dynamic>? invoice;
                                        final existingInvId = order['invoice']?['id'] as int?;
                                        if (existingInvId != null) {
                                          invoice = await ref.read(invoiceProvider.notifier).loadInvoice(existingInvId);
                                        } else {
                                          invoice = await ref.read(invoiceProvider.notifier).generateInvoice(orderId);
                                        }
                                        if (!mounted || invoice == null) return;

                                        await ReceiptPrinter.print80mm(invoice: invoice);
                                      },
                                      icon: const Icon(Icons.print),
                                      label: const Text('In hóa đơn'),
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
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
