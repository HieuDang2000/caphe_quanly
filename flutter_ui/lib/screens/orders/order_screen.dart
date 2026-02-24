import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/order_provider.dart';
import '../../providers/menu_provider.dart';
import '../../providers/layout_provider.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/loading_widget.dart';

class OrderScreen extends ConsumerStatefulWidget {
  const OrderScreen({super.key});

  @override
  ConsumerState<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends ConsumerState<OrderScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() {
      ref.read(layoutProvider.notifier).loadFloors();
      ref.read(menuProvider.notifier).loadCategories();
      ref.read(menuProvider.notifier).loadItems();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderState = ref.watch(orderProvider);
    final menuState = ref.watch(menuProvider);
    final layoutState = ref.watch(layoutProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đặt món'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.table_restaurant), text: 'Chọn bàn'),
            Tab(icon: Icon(Icons.restaurant_menu), text: 'Chọn món'),
          ],
        ),
      ),
      drawer: const AppDrawer(),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Chọn bàn
          _buildTableSelector(layoutState),
          // Tab 2: Chọn món
          _buildMenuPicker(menuState, orderState),
        ],
      ),
      bottomNavigationBar: orderState.cartItems.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -2))],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${orderState.cartItems.length} món', style: const TextStyle(fontSize: 14)),
                          Text(Formatters.currency(orderState.cartTotal), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _confirmOrder(orderState),
                      icon: const Icon(Icons.send),
                      label: const Text('Đặt món'),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildTableSelector(LayoutState layoutState) {
    if (layoutState.isLoading) return const LoadingWidget();
    final selectedId = ref.watch(orderProvider).selectedTableId;
    String? selectedTableName;
    if (selectedId != null) {
      final match = layoutState.objects.where((o) => o['id'] == selectedId);
      selectedTableName = match.isEmpty ? 'Bàn' : (match.first['name'] as String? ?? 'Bàn');
    }
    final isTakeaway = selectedId == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // "Bán mang đi" + trạng thái đang chọn
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    ref.read(orderProvider.notifier).selectTable(null);
                    _tabController.animateTo(1);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: isTakeaway ? AppTheme.primaryColor : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isTakeaway ? AppTheme.primaryColor : Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.takeout_dining,
                          size: 28,
                          color: isTakeaway ? Colors.white : AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Bán mang đi',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isTakeaway ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  selectedTableName != null ? 'Đang chọn: $selectedTableName' : 'Đang chọn: Mang đi',
                  style: Theme.of(context).textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        // Chọn tầng
        if (layoutState.floors.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: layoutState.floors.length,
              itemBuilder: (_, index) {
                final floor = layoutState.floors[index];
                final isSelected = floor['id'] == layoutState.selectedFloorId;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(floor['name']),
                    selected: isSelected,
                    selectedColor: AppTheme.primaryColor,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : null),
                    onSelected: (_) => ref.read(layoutProvider.notifier).selectFloor(floor['id']),
                  ),
                );
              },
            ),
          ),
        // Sơ đồ layout (chọn bàn)
        Expanded(
          child: InteractiveViewer(
            boundaryMargin: const EdgeInsets.all(500),
            minScale: 0.3,
            maxScale: 3.0,
            child: SizedBox(
              width: 2000,
              height: 2000,
              child: Stack(
                children: layoutState.objects.map((obj) {
                  final type = obj['type'] as String?;
                  final id = obj['id'];
                  final isTable = type == 'table';
                  final isSelected = isTable && id == selectedId;
                  final child = _buildLayoutObject(obj, isSelected: isSelected);
                  if (isTable) {
                    return Positioned(
                      left: (obj['position_x'] as num?)?.toDouble() ?? 0,
                      top: (obj['position_y'] as num?)?.toDouble() ?? 0,
                      child: GestureDetector(
                        onTap: () {
                          ref.read(orderProvider.notifier).selectTable(id as int);
                          _tabController.animateTo(1);
                        },
                        child: child,
                      ),
                    );
                  }
                  return Positioned(
                    left: (obj['position_x'] as num?)?.toDouble() ?? 0,
                    top: (obj['position_y'] as num?)?.toDouble() ?? 0,
                    child: child,
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLayoutObject(Map<String, dynamic> obj, {bool isSelected = false}) {
    final type = obj['type'] as String? ?? 'table';
    final w = (obj['width'] as num?)?.toDouble() ?? 80;
    final h = (obj['height'] as num?)?.toDouble() ?? 80;
    final name = obj['name'] as String? ?? '';
    final rotationDeg = (obj['rotation'] as num?)?.toDouble() ?? 0.0;
    final rotationRad = rotationDeg * math.pi / 180;
    final showNameAlways = ['wall', 'window', 'door', 'reception'].contains(type);

    Color color;
    IconData icon;
    switch (type) {
      case 'table':
        color = isSelected ? AppTheme.primaryColor : AppTheme.primaryColor;
        icon = Icons.table_restaurant;
        break;
      case 'wall':
        color = Colors.brown.shade700;
        icon = Icons.fence;
        break;
      case 'window':
        color = Colors.lightBlue.shade300;
        icon = Icons.window;
        break;
      case 'door':
        color = Colors.brown.shade300;
        icon = Icons.door_front_door;
        break;
      case 'reception':
        color = Colors.amber.shade700;
        icon = Icons.desk;
        break;
      default:
        color = Colors.grey;
        icon = Icons.square;
    }

    final isTable = type == 'table';
    final textWidget = (showNameAlways || h > 40)
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              name,
              style: TextStyle(
                fontSize: showNameAlways ? 11 : 10,
                color: isSelected && isTable ? Colors.white : color,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: isTable ? 2 : 1,
            ),
          )
        : null;

    final content = Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: (isSelected && isTable ? AppTheme.primaryColor : color).withValues(alpha: 0.2),
        border: Border.all(
          color: isSelected && isTable ? AppTheme.primaryColor : color,
          width: isSelected && isTable ? 3 : 2,
        ),
        borderRadius: BorderRadius.circular(isTable ? 8 : 4),
      ),
      child: isTable
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: isSelected ? Colors.white : color, size: 24),
                if (textWidget != null) textWidget,
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 16),
                if (textWidget != null) ...[const SizedBox(width: 4), Flexible(child: textWidget)],
              ],
            ),
    );

    return Transform.rotate(
      angle: rotationRad,
      child: content,
    );
  }

  Widget _buildMenuPicker(MenuState menuState, OrderState orderState) {
    return Column(
      children: [
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
        Expanded(
          child: menuState.isLoading
              ? const LoadingWidget()
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: menuState.items.length,
                  itemBuilder: (_, index) {
                    final item = menuState.items[index];
                    if (item['is_available'] == false) return const SizedBox.shrink();
                    final inCart = orderState.cartItems.where((c) => c['menu_item_id'] == item['id']);
                    final qty = inCart.isNotEmpty ? inCart.first['quantity'] as int : 0;

                    return Card(
                      child: ListTile(
                        title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(Formatters.currency(item['price'] ?? 0)),
                        trailing: qty > 0
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline),
                                    onPressed: () => ref.read(orderProvider.notifier).updateCartQuantity(item['id'], qty - 1),
                                  ),
                                  Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
                                    onPressed: () => ref.read(orderProvider.notifier).updateCartQuantity(item['id'], qty + 1),
                                  ),
                                ],
                              )
                            : IconButton(
                                icon: const Icon(Icons.add_circle, color: AppTheme.primaryColor),
                                onPressed: () => ref.read(orderProvider.notifier).addToCart(item),
                              ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _confirmOrder(OrderState orderState) {
    final notesController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận đặt món'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...orderState.cartItems.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('${item['name']} x${item['quantity']} - ${Formatters.currency(Formatters.toNum(item['price']) * (item['quantity'] as num))}'),
            )),
            const Divider(),
            Text('Tổng: ${Formatters.currency(orderState.cartTotal)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(controller: notesController, decoration: const InputDecoration(labelText: 'Ghi chú', hintText: 'VD: Ít đường, nhiều đá...'), maxLines: 2),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final order = await ref.read(orderProvider.notifier).submitOrder(notes: notesController.text);
              if (order != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã tạo đơn ${order['order_number']}')));
                context.go('/orders/list');
              }
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }
}
