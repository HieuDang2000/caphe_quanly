import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/menu_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/layout_provider.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/responsive_layout.dart';

class OrderMenuPicker extends ConsumerStatefulWidget {
  const OrderMenuPicker({super.key});

  @override
  ConsumerState<OrderMenuPicker> createState() => _OrderMenuPickerState();
}

class _OrderMenuPickerState extends ConsumerState<OrderMenuPicker> {
  String _menuSearchQuery = '';
  final Map<int, TextEditingController> _noteControllers = {};
  final Map<int, Set<int>> _selectedOptionIdsByItem = {};
  final Map<int, bool> _isAddingByItem = {};

  @override
  void dispose() {
    for (final controller in _noteControllers.values) {
      controller.dispose();
    }
    _noteControllers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final menuState = ref.watch(menuProvider);
    final orderState = ref.watch(orderProvider);
    final layoutState = ref.watch(layoutProvider);

    final isTableMode = orderState.selectedTableId != null;

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
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        int crossAxisCount;
                        if (width < kMobileMaxWidth) {
                          crossAxisCount = 2;
                        } else if (width < kTabletMaxWidth) {
                          crossAxisCount = 4;
                        } else {
                          crossAxisCount = 6;
                        }

                        // Tính toán tỉ lệ linh động dựa trên bề rộng cột để tăng chiều cao item,
                        // tránh bị overflow khi nội dung nhiều.
                        const spacing = 8.0;
                        final totalSpacing = (crossAxisCount - 1) * spacing;
                        final itemWidth = (width - totalSpacing) / crossAxisCount;
                        const minItemHeight = 180.0;
                        final childAspectRatio = itemWidth / minItemHeight;

                        return GridView.builder(
                          padding: const EdgeInsets.all(8),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            mainAxisSpacing: spacing,
                            crossAxisSpacing: spacing,
                            childAspectRatio: childAspectRatio,
                          ),
                          itemCount: filteredItems.length,
                          itemBuilder: (_, index) {
                            final item = filteredItems[index];
                            if (item['is_available'] == false) return const SizedBox.shrink();
                            final itemId = item['id'] as int;
                            final inCart = orderState.cartItems.where((c) => c['menu_item_id'] == item['id']);
                            final cartEntry = !isTableMode && inCart.isNotEmpty ? inCart.first : null;
                            final qty = cartEntry != null ? Formatters.toNum(cartEntry['quantity']).toInt() : 0;
                            final itemNote = cartEntry != null ? cartEntry['notes'] as String? : null;
                            final existingOpts = cartEntry != null ? (cartEntry['options'] as List?)?.cast<Map<String, dynamic>>() : null;
                            final basePrice = Formatters.toNum(item['price']);
                            final itemOpts = (item['options'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                            // Khởi tạo tick option theo cart hiện tại (nếu có) khi chưa chọn gì.
                            final existingOptIds = (existingOpts ?? [])
                                .map((o) => Formatters.toNum(o['id']).toInt())
                                .where((id) => id > 0)
                                .toList();
                            final currentSelected = _selectedOptionIdsByItem[itemId] ?? <int>{};
                            if (currentSelected.isEmpty && existingOptIds.isNotEmpty) {
                              _selectedOptionIdsByItem[itemId] = existingOptIds.toSet();
                            }
                            final selectedIds = _selectedOptionIdsByItem[itemId] ?? <int>{};
                            final selectedOpts = itemOpts
                                .where((o) => selectedIds.contains(Formatters.toNum(o['id']).toInt()))
                                .toList();
                            final optsExtra = selectedOpts.fold<double>(0, (s, o) => s + Formatters.toNum(o['extra_price']));
                            final displayPrice = basePrice + optsExtra;

                            final noteController = _noteControllers[itemId] ??
                                TextEditingController(text: itemNote ?? '');
                            _noteControllers[itemId] = noteController;

                            final isAdding = _isAddingByItem[itemId] ?? false;

                            Future<void> handleAdd() async {
                              if (isAdding) return;
                              setState(() {
                                _isAddingByItem[itemId] = true;
                              });
                              try {
                                if (isTableMode) {
                                  final tableId = orderState.selectedTableId;
                                  if (tableId == null) return;
                                  final trimmed = noteController.text.trim();
                                  final note = trimmed.isEmpty ? null : trimmed;
                                  final selectedIds = _selectedOptionIdsByItem[itemId] ?? <int>{};
                                  final selectedOptions = itemOpts
                                      .where((o) =>
                                          selectedIds.contains(Formatters.toNum(o['id']).toInt()))
                                      .map((o) => {
                                            'id': o['id'],
                                            'name': o['name'],
                                            'extra_price': o['extra_price'],
                                          })
                                      .toList();
                                  final existingItems =
                                      (orderState.currentOrder?['items'] as List?)
                                              ?.cast<Map<String, dynamic>>() ??
                                          <Map<String, dynamic>>[];
                                  final newItems = [
                                    ...existingItems,
                                    {
                                      'menu_item_id': itemId,
                                      'name': item['name'],
                                      'price': basePrice,
                                      'quantity': 1,
                                      'notes': note,
                                      'options': selectedOptions,
                                    },
                                  ];
                                  await ref
                                      .read(orderProvider.notifier)
                                      .saveTableOrderItems(tableId, newItems);
                                  noteController.clear();
                                } else if (qty > 0) {
                                  ref.read(orderProvider.notifier).updateCartQuantity(
                                        itemId,
                                        qty + 1,
                                        options: existingOpts,
                                        notes: itemNote,
                                      );
                                } else {
                                  final trimmed = noteController.text.trim();
                                  final note = trimmed.isEmpty ? null : trimmed;
                                  final selectedIds = _selectedOptionIdsByItem[itemId] ?? <int>{};
                                  final selectedOptions = itemOpts
                                      .where((o) =>
                                          selectedIds.contains(Formatters.toNum(o['id']).toInt()))
                                      .map((o) => {
                                            'id': o['id'],
                                            'name': o['name'],
                                            'extra_price': o['extra_price'],
                                          })
                                      .toList();
                                  ref.read(orderProvider.notifier).addToCart(
                                        item,
                                        notes: note,
                                        quantity: 1,
                                        options: selectedOptions.isEmpty ? null : selectedOptions,
                                      );
                                  noteController.clear();
                                }
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    _isAddingByItem[itemId] = false;
                                  });
                                }
                              }
                            }

                            return Card(
                              child: InkWell(
                                onTap: isAdding ? null : () => handleAdd(),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['name'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        selectedOpts.isEmpty
                                            ? Formatters.currency(basePrice)
                                            : Formatters.currency(displayPrice),
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      if (itemOpts.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Wrap(
                                            spacing: 4,
                                            runSpacing: 2,
                                            children: itemOpts.map((o) {
                                              final optId = Formatters.toNum(o['id']).toInt();
                                              final checked = selectedIds.contains(optId);
                                              final label =
                                                  '${o['name']} +${Formatters.currency(o['extra_price'])}';
                                              return FilterChip(
                                                label: Text(
                                                  label,
                                                  style: const TextStyle(fontSize: 11),
                                                ),
                                                selected: checked,
                                                selectedColor: AppTheme.primaryColor.withOpacity(0.12),
                                                checkmarkColor: AppTheme.primaryColor,
                                                onSelected: (v) {
                                                  setState(() {
                                                    final set = _selectedOptionIdsByItem[itemId] ?? <int>{};
                                                    if (v) {
                                                      set.add(optId);
                                                    } else {
                                                      set.remove(optId);
                                                    }
                                                    _selectedOptionIdsByItem[itemId] = set;
                                                  });
                                                },
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      const SizedBox(height: 3),
                                      const Spacer(),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: noteController,
                                              decoration: const InputDecoration(
                                                hintText: 'Ghi chú',
                                                isDense: true,
                                                hintStyle: TextStyle(fontSize: 12),
                                                border: OutlineInputBorder(),
                                                contentPadding: EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                                              ),
                                              maxLines: 1,
                                              onChanged: (v) {
                                                if (isTableMode) return;
                                                final trimmed = v.trim();
                                                final newNote = trimmed.isEmpty ? null : trimmed;
                                                if (cartEntry != null) {
                                                  ref.read(orderProvider.notifier).updateCartItemNote(
                                                        itemId,
                                                        newNote,
                                                        options: existingOpts,
                                                        notes: itemNote,
                                                      );
                                                }
                                              },
                                            ),
                                          ),
                                          if (isAdding)
                                            Padding(
                                              padding: const EdgeInsets.only(left: 8),
                                              child: SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: const CircularProgressIndicator(strokeWidth: 2),
                                              ),
                                            )
                                          else if (isTableMode)
                                            IconButton(
                                              icon: const Icon(Icons.add_circle, color: AppTheme.primaryColor),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              onPressed: () {
                                                handleAdd();
                                              },
                                            )
                                          else if (qty > 0) ...[
                                            IconButton(
                                              icon: const Icon(Icons.remove_circle_outline, size: 20),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              onPressed: () => ref.read(orderProvider.notifier).updateCartQuantity(
                                                    itemId,
                                                    qty - 1,
                                                    options: existingOpts,
                                                    notes: itemNote,
                                                  ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 2),
                                              child: Text(
                                                '$qty',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.add_circle_outline, size: 20),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              onPressed: () {
                                                handleAdd();
                                              },
                                            ),
                                          ] else
                                            IconButton(
                                              icon: const Icon(Icons.add_circle, color: AppTheme.primaryColor),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              onPressed: () {
                                                handleAdd();
                                              },
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

}

