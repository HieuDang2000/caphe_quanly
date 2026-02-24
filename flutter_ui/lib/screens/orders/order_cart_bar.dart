import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/order_provider.dart';

class OrderCartBar extends ConsumerStatefulWidget {
  const OrderCartBar({super.key});

  @override
  ConsumerState<OrderCartBar> createState() => _OrderCartBarState();
}

class _OrderCartBarState extends ConsumerState<OrderCartBar> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final orderState = ref.watch(orderProvider);

    if (orderState.cartItems.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${orderState.cartItems.length} món',
                              style: const TextStyle(fontSize: 14)),
                          Text(
                            Formatters.currency(orderState.cartTotal),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(_expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _confirmOrder(orderState),
                      icon: const Icon(Icons.send, size: 18),
                      label: const Text('Đặt món'),
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded) ...[
              const Divider(height: 1),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  itemCount: orderState.cartItems.length,
                  itemBuilder: (_, index) {
                    final item = orderState.cartItems[index];
                    final qty = Formatters.toNum(item['quantity']).toInt();
                    final basePrice = Formatters.toNum(item['price']);
                    final opts = item['options'] as List? ?? [];
                    final extra = opts.fold<double>(
                      0,
                      (s, o) => s + Formatters.toNum(o is Map ? o['extra_price'] : 0),
                    );
                    final unitPrice = basePrice + extra;
                    final note = item['notes'] as String?;
                    final optsList = opts.cast<Map<String, dynamic>>();
                    final optText = optsList.isNotEmpty
                        ? optsList
                            .map((o) => '${o['name']} +${Formatters.currency(o['extra_price'])}')
                            .join(' · ')
                        : null;
                    final hasNote = note != null && note.trim().isNotEmpty;
                    final notifier = ref.read(orderProvider.notifier);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 4),
                      child: ListTile(
                        dense: true,
                        title: Text(
                          item['name'],
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (optText != null)
                              Text(
                                optText,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (hasNote)
                              Text(
                                note,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${Formatters.currency(unitPrice * qty)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, size: 20),
                              onPressed: () => notifier.updateCartQuantity(
                                item['menu_item_id'],
                                qty - 1,
                                options: optsList.isEmpty ? null : optsList,
                                notes: note,
                              ),
                            ),
                            Text(
                              '$qty',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, size: 20),
                              onPressed: () => notifier.updateCartQuantity(
                                item['menu_item_id'],
                                qty + 1,
                                options: optsList.isEmpty ? null : optsList,
                                notes: note,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: Colors.red.shade400,
                              ),
                              onPressed: () => notifier.removeFromCart(
                                item['menu_item_id'],
                                options: optsList.isEmpty ? null : optsList,
                                notes: note,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmOrder(OrderState orderState) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận đặt món'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...orderState.cartItems.map((item) {
                final base = Formatters.toNum(item['price']);
                final opts = item['options'] as List? ?? [];
                final extra =
                    opts.fold<double>(0, (s, o) => s + Formatters.toNum(o is Map ? o['extra_price'] : 0));
                final unitPrice = base + extra;
                final lineTotal = unitPrice * Formatters.toNum(item['quantity']);
                final note = item['notes'] as String?;
                final hasNote = note != null && note.trim().isNotEmpty;
                final optNames = opts
                    .map((o) => o is Map ? (o['name'] as String?) : null)
                    .whereType<String>()
                    .toList();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item['name']} x${item['quantity']} - ${Formatters.currency(lineTotal)}',
                      ),
                      if (optNames.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 8, top: 2),
                          child: Text(
                            optNames.join(', '),
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ),
                      if (hasNote)
                        Padding(
                          padding: const EdgeInsets.only(left: 8, top: 2),
                          child: Text(
                            note,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
              const Divider(),
              Text(
                'Tổng: ${Formatters.currency(orderState.cartTotal)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final notifier = ref.read(orderProvider.notifier);
              final order = await notifier.submitOrder();
              if (order != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Đã tạo đơn ${order['order_number']}')),
                );
                if (mounted) context.go('/orders/list');
              }
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }
}

