import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/menu_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/layout_provider.dart';
import '../../widgets/loading_widget.dart';

class OrderMenuPicker extends ConsumerStatefulWidget {
  const OrderMenuPicker({super.key});

  @override
  ConsumerState<OrderMenuPicker> createState() => _OrderMenuPickerState();
}

class _OrderMenuPickerState extends ConsumerState<OrderMenuPicker> {
  String _menuSearchQuery = '';

  @override
  Widget build(BuildContext context) {
    final menuState = ref.watch(menuProvider);
    final orderState = ref.watch(orderProvider);
    final layoutState = ref.watch(layoutProvider);

    final selectedId = orderState.selectedTableId;
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(displayIcon, size: 20, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text('Đang đặt: ', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              Text(displayLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
            ],
          ),
        ),
        SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('Tất cả'),
                  selected: menuState.selectedCategoryId == null,
                  selectedColor: AppTheme.primaryColor,
                  labelStyle: TextStyle(color: menuState.selectedCategoryId == null ? Colors.white : null),
                  onSelected: (_) => ref.read(menuProvider.notifier).loadItems(),
                ),
              ),
              ...menuState.categories.map((cat) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat['name']),
                      selected: menuState.selectedCategoryId == cat['id'],
                      selectedColor: AppTheme.primaryColor,
                      labelStyle: TextStyle(color: menuState.selectedCategoryId == cat['id'] ? Colors.white : null),
                      onSelected: (_) => ref.read(menuProvider.notifier).loadItems(categoryId: cat['id']),
                    ),
                  )),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Tìm món...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _menuSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() => _menuSearchQuery = ''),
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: (v) => setState(() => _menuSearchQuery = v),
          ),
        ),
        Expanded(
          child: menuState.isLoading
              ? const LoadingWidget()
              : Builder(
                  builder: (_) {
                    final query = _menuSearchQuery.trim().toLowerCase();
                    final filteredItems = query.isEmpty
                        ? menuState.items
                        : menuState.items.where((item) {
                            final name = (item['name'] as String? ?? '').toLowerCase();
                            return name.contains(query);
                          }).toList();
                    return ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: filteredItems.length,
                      itemBuilder: (_, index) {
                        final item = filteredItems[index];
                        if (item['is_available'] == false) return const SizedBox.shrink();
                        final inCart = orderState.cartItems.where((c) => c['menu_item_id'] == item['id']);
                        final cartEntry = inCart.isEmpty ? null : inCart.first;
                        final qty = cartEntry != null ? Formatters.toNum(cartEntry['quantity']).toInt() : 0;
                        final itemNote = cartEntry != null ? cartEntry['notes'] as String? : null;
                        final existingOpts = cartEntry != null ? (cartEntry['options'] as List?)?.cast<Map<String, dynamic>>() : null;
                        final hasNote = itemNote != null && itemNote.trim().isNotEmpty;
                        final basePrice = Formatters.toNum(item['price']);
                        final itemOpts = (item['options'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                        final hasItemOpts = itemOpts.isNotEmpty;
                        final optsExtra = (existingOpts ?? []).fold<double>(0, (s, o) => s + Formatters.toNum(o['extra_price']));
                        final displayPrice = basePrice + optsExtra;

                        return Card(
                          child: ListTile(
                            onTap: () => _showAddOrEditItemDialog(
                              item: item,
                              existingQty: qty,
                              existingNote: itemNote,
                              existingOptions: existingOpts,
                            ),
                            title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  hasItemOpts && (existingOpts ?? []).isEmpty
                                      ? 'Từ ${Formatters.currency(displayPrice)}'
                                      : Formatters.currency(displayPrice),
                                ),
                                if (hasItemOpts && (existingOpts ?? []).isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      itemOpts
                                          .map((o) => '${o['name']} +${Formatters.currency(o['extra_price'])}')
                                          .join(' · '),
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                if ((existingOpts ?? []).isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      (existingOpts ?? [])
                                          .map((o) => '${o['name']} +${Formatters.currency(o['extra_price'])}')
                                          .join(' · '),
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                if (hasNote)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      itemNote,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: qty > 0
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline),
                                        onPressed: () => ref.read(orderProvider.notifier).updateCartQuantity(
                                              item['id'],
                                              qty - 1,
                                              options: existingOpts,
                                              notes: itemNote,
                                            ),
                                      ),
                                      Text('$qty',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold, fontSize: 16)),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline),
                                        onPressed: () => _showAddOrEditItemDialog(
                                          item: item,
                                          existingQty: 0,
                                          existingNote: null,
                                          existingOptions: null,
                                        ),
                                      ),
                                    ],
                                  )
                                : IconButton(
                                    icon:
                                        const Icon(Icons.add_circle, color: AppTheme.primaryColor),
                                    onPressed: () => _showAddOrEditItemDialog(
                                      item: item,
                                      existingQty: 0,
                                      existingNote: null,
                                      existingOptions: null,
                                    ),
                                  ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showAddOrEditItemDialog({
    required Map<String, dynamic> item,
    required int existingQty,
    String? existingNote,
    List<Map<String, dynamic>>? existingOptions,
  }) {
    final orderNotifier = ref.read(orderProvider.notifier);

    int quantity = existingQty > 0 ? existingQty : 1;
    final noteController = TextEditingController(text: existingNote ?? '');
    final itemOptions = (item['options'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    List<Map<String, dynamic>> selectedOptions =
        existingOptions != null ? List.from(existingOptions) : [];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final basePrice = Formatters.toNum(item['price']);
          final optionsExtra =
              selectedOptions.fold<double>(0, (s, o) => s + Formatters.toNum(o['extra_price']));
          final unitPrice = basePrice + optionsExtra;
          final lineTotal = unitPrice * quantity;

          return AlertDialog(
            title: Text(existingQty > 0 ? 'Sửa món' : 'Thêm món'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['name'],
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  Text(Formatters.currency(unitPrice),
                      style: TextStyle(color: Colors.grey.shade600)),
                  if (selectedOptions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Tổng dòng: ${Formatters.currency(lineTotal)}',
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                    ),
                  const SizedBox(height: 16),
                  if (itemOptions.isNotEmpty) ...[
                    const Text('Tuỳ chọn:', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: itemOptions.map((opt) {
                        final id = opt['id'];
                        final name = opt['name'] as String? ?? '';
                        final extra = Formatters.toNum(opt['extra_price']).toInt();
                        final isSelected = selectedOptions
                            .any((s) => Formatters.toNum(s['id']).toInt() == Formatters.toNum(id).toInt());
                        return FilterChip(
                          label: Text('$name +${Formatters.currency(extra)}'),
                          selected: isSelected,
                          selectedColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                          onSelected: (v) {
                            setDialogState(() {
                              if (v) {
                                selectedOptions = [
                                  ...selectedOptions,
                                  {'id': id, 'name': name, 'extra_price': extra}
                                ];
                              } else {
                                selectedOptions = selectedOptions
                                    .where((s) =>
                                        Formatters.toNum(s['id']).toInt() !=
                                        Formatters.toNum(id).toInt())
                                    .toList();
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      const Text('Số lượng: '),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: quantity <= 1
                            ? null
                            : () => setDialogState(() => quantity = quantity - 1),
                      ),
                      Text('$quantity',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => setDialogState(() => quantity = quantity + 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú cho món',
                      hintText: 'VD: Ít đường, nhiều đá...',
                    ),
                    maxLines: 2,
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
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  final note =
                      noteController.text.trim().isEmpty ? null : noteController.text.trim();
                  if (existingQty > 0) {
                    orderNotifier.updateCartQuantity(
                      item['id'],
                      quantity,
                      options: existingOptions,
                      notes: existingNote,
                    );
                    orderNotifier.updateCartItemNote(
                      item['id'],
                      note,
                      options: existingOptions,
                      notes: existingNote,
                    );
                    orderNotifier.updateCartItemOptions(
                      item['id'],
                      selectedOptions,
                      currentOptions: existingOptions,
                      currentNotes: existingNote,
                    );
                  } else {
                    orderNotifier.addToCart(
                      item,
                      notes: note,
                      quantity: quantity,
                      options: selectedOptions,
                    );
                  }
                },
                child: Text(existingQty > 0 ? 'Cập nhật' : 'Thêm vào giỏ'),
              ),
            ],
          );
        },
      ),
    );
  }
}

