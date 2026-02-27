import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/order_provider.dart';
import '../../providers/layout_provider.dart';
import '../../services/receipt_printer.dart';

class OrderCartBar extends ConsumerStatefulWidget {
  const OrderCartBar({super.key, this.isBottomBar = false});

  final bool isBottomBar;

  @override
  ConsumerState<OrderCartBar> createState() => _OrderCartBarState();
}

class _OrderCartBarState extends ConsumerState<OrderCartBar> {
  bool _expanded = true;
  int? _lastOrderId;
  final Set<int> _selectedTableItemIds = {};
  final Set<int> _selectedItemIdsForInvoice = {};
  final Set<int> _deletingTableItemIds = {};

  @override
  Widget build(BuildContext context) {
    final orderState = ref.watch(orderProvider);
    final layoutState = ref.watch(layoutProvider);

    final selectedId = orderState.selectedTableId;
    final isTableMode = selectedId != null;
    final tableItems =
        (orderState.currentOrder?['items'] as List?)?.cast<Map<String, dynamic>>() ??
            const <Map<String, dynamic>>[];
    final orderId = isTableMode ? (orderState.currentOrder?['id'] as int?) : null;
    final orderStatus = isTableMode ? (orderState.currentOrder?['status'] as String? ?? 'pending') : null;
    if (orderId != null && orderId != _lastOrderId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _lastOrderId = orderId;
            _selectedTableItemIds.clear();
            _selectedItemIdsForInvoice.clear();
          });
        }
      });
    }
    String displayLabel;
    IconData displayIcon;
    if (selectedId == null) {
      displayLabel = 'Bán mang đi';
      displayIcon = Icons.shopping_bag_outlined;
    } else {
      final match = layoutState.objects.where((o) => Formatters.toNum(o['id']).toInt() == selectedId);
      displayLabel = match.isEmpty ? 'Bàn $selectedId' : (match.first['name'] as String? ?? 'Bàn');
      displayIcon = Icons.table_restaurant;
    }

    // Ẩn sidebar chỉ khi bán mang đi và giỏ đang trống.
    if (!isTableMode && orderState.cartItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final itemCount = isTableMode ? tableItems.length : orderState.cartItems.length;
    final totalAmount = isTableMode
        ? tableItems
            .where((i) => i['is_paid'] != true)
            .fold<double>(0, (sum, i) => sum + Formatters.toNum(i['subtotal']))
        : orderState.cartTotal;

    final compactRow = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(displayIcon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayLabel,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$itemCount món · ${Formatters.currency(totalAmount)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          if (selectedId == null)
            ElevatedButton.icon(
              onPressed: () => _confirmPayment(orderState),
              icon: const Icon(Icons.payment, size: 18),
              label: const Text('Thanh toán'),
            )
          else
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up),
              onPressed: () => _openBottomSheet(context),
            ),
        ],
      ),
    );

    if (widget.isBottomBar) {
      return Material(
        elevation: 8,
        color: Colors.white,
        child: SafeArea(
          child: InkWell(
            onTap: () => _openBottomSheet(context),
            child: compactRow,
          ),
        ),
      );
    }

    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Row(
                children: [
                  Icon(displayIcon, size: 20, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Đang đặt:',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        Text(
                          displayLabel,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$itemCount món',
                            style: const TextStyle(fontSize: 13),
                          ),
                          Text(
                            Formatters.currency(totalAmount),
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
                    if (selectedId == null)
                      ElevatedButton.icon(
                        onPressed: () => _confirmPayment(orderState),
                        icon: const Icon(Icons.payment, size: 18),
                        label: const Text('Thanh toán'),
                      ),
                  ],
                ),
              ),
            ),
            if (_expanded) ...[
              const Divider(height: 1),
              if (isTableMode && orderState.isLoading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  itemCount: itemCount,
                  itemBuilder: (_, index) {
                    if (isTableMode) {
                      final item = tableItems[index];
                      final itemId = item['id'] as int?;
                      final qty = Formatters.toNum(item['quantity']).toInt();
                      final subtotal = Formatters.toNum(item['subtotal']);
                      final note = item['notes'] as String?;
                      final opts = (item['options'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
                      final optText = opts.isNotEmpty
                          ? opts
                              .map((o) => '${o['name']} +${Formatters.currency(o['extra_price'])}')
                              .join(' · ')
                          : null;
                      final hasNote = note != null && note.trim().isNotEmpty;
                      final isItemPaid = item['is_paid'] == true;
                      final canSelect = orderStatus == 'pending' && itemId != null && !isItemPaid;
                      final isSelected = canSelect && _selectedTableItemIds.contains(itemId);
                      final paidStyle = TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: Colors.grey.shade600,
                      );
                      final paidSubtitleStyle = TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: Colors.grey.shade500,
                        fontStyle: hasNote ? FontStyle.italic : FontStyle.normal,
                      );
                      final isSelectedForInvoice = itemId != null && _selectedItemIdsForInvoice.contains(itemId);
                      final isDeleting = itemId != null && _deletingTableItemIds.contains(itemId);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                          side: isSelectedForInvoice ? BorderSide(color: AppTheme.primaryColor, width: 1.5) : BorderSide.none,
                        ),
                        child: InkWell(
                          onTap: itemId != null
                              ? () => setState(() {
                                    if (_selectedItemIdsForInvoice.contains(itemId)) {
                                      _selectedItemIdsForInvoice.remove(itemId);
                                    } else {
                                      _selectedItemIdsForInvoice.add(itemId);
                                    }
                                  })
                              : null,
                          borderRadius: BorderRadius.circular(4),
                          child: ListTile(
                          dense: true,
                          leading: canSelect
                              ? Checkbox(
                                  value: isSelected,
                                  onChanged: (v) => setState(() {
                                    if (v == true) {
                                      _selectedTableItemIds.add(itemId);
                                    } else {
                                      _selectedTableItemIds.remove(itemId);
                                    }
                                  }),
                                )
                              : null,
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item['menu_item']?['name']?.toString() ?? (item['name']?.toString() ?? ''),
                                  style: isItemPaid ? paidStyle : const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              if (isSelectedForInvoice)
                                Icon(Icons.check_circle, size: 18, color: AppTheme.primaryColor),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (optText != null)
                                Text(
                                  optText,
                                  style: isItemPaid ? paidSubtitleStyle : TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (hasNote)
                                Text(
                                  note,
                                  style: isItemPaid ? paidSubtitleStyle : TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                Formatters.currency(subtotal),
                                style: isItemPaid
                                    ? TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade600, decoration: TextDecoration.lineThrough, decorationColor: Colors.grey.shade600)
                                    : const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                              if (!isItemPaid) ...[
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                                  onPressed: isDeleting ? null : () => _updateTableItemQuantity(item, qty - 1),
                                ),
                                Text(
                                  '$qty',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, size: 20),
                                  onPressed: isDeleting ? null : () => _updateTableItemQuantity(item, qty + 1),
                                ),
                                if (isDeleting)
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                else
                                  IconButton(
                                    icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade400),
                                    onPressed: itemId == null
                                        ? null
                                        : () async {
                                            setState(() {
                                              _deletingTableItemIds.add(itemId);
                                            });
                                            await _removeTableItem(item);
                                            if (!mounted) return;
                                            setState(() {
                                              _deletingTableItemIds.remove(itemId);
                                            });
                                          },
                                  ),
                              ],
                            ],
                          ),
                        ),
                        ),
                      );
                    } else {
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
                    }
                  },
                  ),
                ),
              if (isTableMode && orderId != null && !orderState.isLoading)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () async {
                          final currentOrder = ref.read(orderProvider).currentOrder;
                          if (currentOrder == null) return;

                          // Không chọn item nào => in toàn bộ item trong order.
                          if (_selectedItemIdsForInvoice.isEmpty) {
                            final orderItems =
                                (currentOrder['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                            if (orderItems.isEmpty) return;
                            final subtotal = orderItems.fold<double>(
                              0,
                              (s, i) => s + Formatters.toNum(i['subtotal']),
                            );
                            final fullOrder = Map<String, dynamic>.from(currentOrder);
                            fullOrder['items'] = orderItems;
                            final invoice = <String, dynamic>{
                              'invoice_number': currentOrder['invoice']?['invoice_number'] ??
                                  '${currentOrder['order_number'] ?? ''}',
                              'created_at': currentOrder['invoice']?['created_at'] ??
                                  DateTime.now().toIso8601String(),
                              'subtotal': subtotal,
                              'total': subtotal,
                              'discount_amount': 0,
                              'order': fullOrder,
                            };
                            await ReceiptPrinter.print80mm(invoice: invoice);
                          } else {
                            final orderItems =
                                (currentOrder['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                            final selectedItems = orderItems
                                .where((i) => _selectedItemIdsForInvoice.contains(i['id']))
                                .toList();
                            if (selectedItems.isEmpty) return;
                            final partialSubtotal = selectedItems.fold<double>(
                              0,
                              (s, i) => s + Formatters.toNum(i['subtotal']),
                            );
                            final partialOrder = Map<String, dynamic>.from(currentOrder);
                            partialOrder['items'] = selectedItems;
                            final partialInvoice = <String, dynamic>{
                              'invoice_number': currentOrder['invoice']?['invoice_number'] ??
                                  '${currentOrder['order_number'] ?? ''}-partial',
                              'created_at': currentOrder['invoice']?['created_at'] ??
                                  DateTime.now().toIso8601String(),
                              'subtotal': partialSubtotal,
                              'total': partialSubtotal,
                              'discount_amount': 0,
                              'order': partialOrder,
                            };
                            await ReceiptPrinter.print80mm(invoice: partialInvoice);
                          }
                        },
                        icon: const Icon(Icons.print, size: 22),
                        label: const Text('In hóa đơn'),
                      ),
                      const SizedBox(height: 8),
                      if (orderStatus == 'pending') ...[
                        ElevatedButton(
                          onPressed: () async {
                            await ref.read(orderProvider.notifier).updateStatus(orderId, 'paid');
                            if (!mounted) return;
                            ref.read(orderProvider.notifier).clearCurrentOrder();
                            if (mounted) setState(() => _selectedTableItemIds.clear());
                          },
                          child: const Text('Thanh toán toàn bộ'),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: tableItems.any((i) => i['is_paid'] != true)
                              ? () async {
                                  await _showPartialPaymentDialog(orderId, tableItems);
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.warningColor,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Thanh toán một phần'),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (orderStatus == 'paid') ...[
                        OutlinedButton(
                          onPressed: () async {
                            await ref.read(orderProvider.notifier).updateStatus(orderId, 'pending');
                            if (!mounted) return;
                            final tableId = ref.read(orderProvider).selectedTableId;
                            if (tableId != null) {
                              await ref.read(orderProvider.notifier).loadTableActiveOrder(tableId);
                            }
                            if (mounted) setState(() => _selectedTableItemIds.clear());
                          },
                          child: const Text('Về chờ xử lý'),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (isTableMode) ...[
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _showMoveTableDialog(selectedId),
                                child: const Text('Chuyển bàn'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _showMergeTableDialog(selectedId),
                                child: const Text('Gộp bàn'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => _confirmDeleteTable(selectedId),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade600,
                          ),
                          child: const Text('Xóa đơn của bàn này'),
                        ),
                        const SizedBox(height: 8),
                      ],
                      
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showPartialPaymentDialog(int orderId, List<Map<String, dynamic>> tableItems) async {
    final unpaidItems = tableItems.where((i) => i['is_paid'] != true).toList();
    if (unpaidItems.isEmpty) return;

    final result = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (ctx) {
        final quantities = <int, int>{};
        for (final item in unpaidItems) {
          final id = Formatters.toNum(item['id']).toInt();
          final qty = Formatters.toNum(item['quantity']).toInt();
          if (id <= 0 || qty <= 0) continue;
          quantities[id] = 0;
        }

        return AlertDialog(
          title: const Text('Thanh toán một phần'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: unpaidItems.map((item) {
                      final id = Formatters.toNum(item['id']).toInt();
                      final name = item['menu_item']?['name']?.toString() ?? (item['name']?.toString() ?? '');
                      final originalQty = Formatters.toNum(item['quantity']).toInt();
                      if (id <= 0 || originalQty <= 0) {
                        return const SizedBox.shrink();
                      }
                      final opts = (item['options'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
                      final note = item['notes'] as String?;
                      final hasNote = note != null && note.trim().isNotEmpty;
                      final optText = opts.isNotEmpty
                          ? opts
                              .map((o) => '${o['name']} +${Formatters.currency(Formatters.toNum(o['extra_price']))}')
                              .join(' · ')
                          : null;
                      final payQty = quantities[id] ?? 0;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        'SL gốc: $originalQty',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                  if (optText != null)
                                    Text(
                                      optText,
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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
                            ),
                            const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                                  onPressed: payQty > 0
                                      ? () {
                                          setState(() {
                                            final current = quantities[id] ?? 0;
                                            quantities[id] = current > 0 ? current - 1 : 0;
                                          });
                                        }
                                      : null,
                                ),
                                Text(
                                  '$payQty',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, size: 20),
                                  onPressed: payQty < originalQty
                                      ? () {
                                          setState(() {
                                            final current = quantities[id] ?? 0;
                                            if (current < originalQty) {
                                              quantities[id] = current + 1;
                                            }
                                          });
                                        }
                                      : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                final itemsToPay = <Map<String, dynamic>>[];
                quantities.forEach((id, qty) {
                  if (qty > 0) {
                    itemsToPay.add({
                      'item_id': id,
                      'quantity': qty,
                    });
                  }
                });
                Navigator.of(ctx).pop(itemsToPay);
              },
              child: const Text('Xác nhận'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    final itemsToPay = (result ?? []).cast<Map<String, dynamic>>();
    if (itemsToPay.isEmpty) return;

    // Chuẩn bị dữ liệu in hóa đơn từ lựa chọn hiện tại.
    final qtyByItemId = <int, int>{};
    for (final p in itemsToPay) {
      final itemId = Formatters.toNum(p['item_id']).toInt();
      final qty = Formatters.toNum(p['quantity']).toInt();
      if (itemId > 0 && qty > 0) {
        qtyByItemId[itemId] = (qtyByItemId[itemId] ?? 0) + qty;
      }
    }
    final itemsToPrint = <Map<String, dynamic>>[];
    for (final it in unpaidItems) {
      final id = Formatters.toNum(it['id']).toInt();
      final payQty = qtyByItemId[id] ?? 0;
      if (payQty <= 0) continue;
      final originalQty = Formatters.toNum(it['quantity']).toInt();
      final originalSubtotal = Formatters.toNum(it['subtotal']);
      final unit = originalQty > 0 ? (originalSubtotal / originalQty) : 0;
      itemsToPrint.add({
        ...it,
        'quantity': payQty,
        'subtotal': unit * payQty,
        // In trước khi gọi API, nên giữ trạng thái chưa thanh toán.
        'is_paid': false,
      });
    }

    if (itemsToPrint.isNotEmpty) {
      final currentOrder = ref.read(orderProvider).currentOrder;
      if (currentOrder != null) {
        final partialSubtotal = itemsToPrint.fold<double>(
          0,
          (s, i) => s + Formatters.toNum(i['subtotal']),
        );
        final partialOrder = Map<String, dynamic>.from(currentOrder);
        partialOrder['items'] = itemsToPrint;
        final partialInvoice = <String, dynamic>{
          'invoice_number': currentOrder['invoice']?['invoice_number'] ??
              '${currentOrder['order_number'] ?? ''}-partial',
          'created_at': DateTime.now().toIso8601String(),
          'subtotal': partialSubtotal,
          'total': partialSubtotal,
          'discount_amount': 0,
          'order': partialOrder,
        };
        await ReceiptPrinter.print80mm(invoice: partialInvoice);
      }
    }

    await ref.read(orderProvider.notifier).payItemsWithQuantities(orderId, itemsToPay);
    await ref.read(orderProvider.notifier).loadOrderById(orderId);
    if (mounted) {
      setState(() {
        _selectedTableItemIds.clear();
      });
    }
  }

  void _openBottomSheet(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.7;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => SizedBox(
        height: height,
        child: const OrderCartBar(isBottomBar: false),
      ),
    );
  }

  void _confirmPayment(OrderState orderState) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận thanh toán'),
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
                final orderId = order['id'] as int?;
                if (orderId != null) {
                  await notifier.updateStatus(orderId, 'paid');
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Đã thanh toán đơn ${order['order_number']}')),
                  );
                  context.go('/orders/list');
                }
              }
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateTableItemQuantity(Map<String, dynamic> item, int newQuantity) async {
    final orderState = ref.read(orderProvider);
    final tableId = orderState.selectedTableId;
    if (tableId == null) return;

    final currentItems =
        (orderState.currentOrder?['items'] as List?)?.cast<Map<String, dynamic>>() ??
            <Map<String, dynamic>>[];

    final updatedItems = <Map<String, dynamic>>[];
    final targetId = item['id'];

    for (final it in currentItems) {
      if (it['id'] != targetId) {
        updatedItems.add(it);
        continue;
      }
      if (newQuantity <= 0) {
        // Bỏ item này ra khỏi order.
        continue;
      }
      updatedItems.add({
        ...it,
        'quantity': newQuantity,
      });
    }

    // Map sang payload tối giản cho API, chỉ gửi các item chưa thanh toán (is_paid != true)
    final payloadItems = updatedItems
        .where((it) => it['is_paid'] != true)
        .map<Map<String, dynamic>>((it) {
      final opts = (it['options'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      return {
        'menu_item_id': it['menu_item_id'],
        'quantity': it['quantity'],
        'notes': it['notes'],
        'options': opts,
      };
    }).toList();

    await ref.read(orderProvider.notifier).saveTableOrderItems(tableId, payloadItems);
  }

  Future<void> _removeTableItem(Map<String, dynamic> item) async {
    await _updateTableItemQuantity(item, 0);
  }

  Future<void> _showMoveTableDialog(int sourceTableId) async {
    final layoutState = ref.read(layoutProvider);
    final tables = layoutState.objects
        .where((o) => (o['type'] as String?) == 'table' && Formatters.toNum(o['id']).toInt() != sourceTableId)
        .toList();
    if (tables.isEmpty) return;

    final targetId = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Chuyển bàn'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: tables.length,
              itemBuilder: (_, index) {
                final t = tables[index];
                final id = Formatters.toNum(t['id']).toInt();
                final name = (t['name'] as String?) ?? 'Bàn $id';
                return ListTile(
                  title: Text(name),
                  subtitle: Text('ID: $id'),
                  onTap: () => Navigator.of(ctx).pop(id),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Hủy'),
            ),
          ],
        );
      },
    );

    if (targetId == null || !mounted) return;
    await ref.read(orderProvider.notifier).moveTable(sourceTableId, targetId);
  }

  Future<void> _showMergeTableDialog(int sourceTableId) async {
    final layoutState = ref.read(layoutProvider);
    final tables = layoutState.objects
        .where((o) => (o['type'] as String?) == 'table' && Formatters.toNum(o['id']).toInt() != sourceTableId)
        .toList();
    if (tables.isEmpty) return;

    final targetId = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Gộp bàn'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: tables.length,
              itemBuilder: (_, index) {
                final t = tables[index];
                final id = Formatters.toNum(t['id']).toInt();
                final name = (t['name'] as String?) ?? 'Bàn $id';
                return ListTile(
                  title: Text(name),
                  subtitle: Text('ID: $id'),
                  onTap: () => Navigator.of(ctx).pop(id),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Hủy'),
            ),
          ],
        );
      },
    );

    if (targetId == null || !mounted) return;
    await ref.read(orderProvider.notifier).mergeTables(sourceTableId, targetId);
  }

  Future<void> _confirmDeleteTable(int tableId) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa đơn của bàn'),
        content: const Text(
          'Thao tác này sẽ hủy toàn bộ các đơn đang chờ của bàn này và giữ lại trong lịch sử. Bàn vẫn tồn tại trong sơ đồ. Bạn có chắc muốn tiếp tục?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa đơn'),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) return;

    await ref.read(orderProvider.notifier).clearTableOrders(tableId);
  }
}

