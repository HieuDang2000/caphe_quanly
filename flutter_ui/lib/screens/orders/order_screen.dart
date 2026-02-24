import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/order_provider.dart';
import '../../providers/menu_provider.dart';
import '../../providers/layout_provider.dart';
import '../../widgets/loading_widget.dart';

class OrderScreen extends ConsumerStatefulWidget {
  const OrderScreen({super.key});

  @override
  ConsumerState<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends ConsumerState<OrderScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _cartBarExpanded = false;
  final TransformationController _layoutTransformCtrl = TransformationController();
  bool _initialScaleApplied = false;
  String _menuSearchQuery = '';

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
    _layoutTransformCtrl.dispose();
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
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Chọn bàn
          _buildTableSelector(layoutState),
          // Tab 2: Chọn món
          _buildMenuPicker(menuState, orderState, layoutState),
        ],
      ),
      bottomNavigationBar: orderState.cartItems.isNotEmpty
          ? Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -2))],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => setState(() => _cartBarExpanded = !_cartBarExpanded),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                            Icon(_cartBarExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up),
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
                    if (_cartBarExpanded) ...[
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
                            final extra = opts.fold<double>(0, (s, o) => s + Formatters.toNum(o is Map ? o['extra_price'] : 0));
                            final unitPrice = basePrice + extra;
                            final note = item['notes'] as String?;
                            final optsList = opts.cast<Map<String, dynamic>>();
                            final optText = optsList.isNotEmpty
                                ? optsList.map((o) => '${o['name']} +${Formatters.currency(o['extra_price'])}').join(' · ')
                                : null;
                            final hasNote = note != null && note.trim().isNotEmpty;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 4),
                              child: ListTile(
                                dense: true,
                                title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (optText != null) Text(optText, style: TextStyle(fontSize: 11, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    if (hasNote) Text(note, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('${Formatters.currency(unitPrice * qty)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                                      onPressed: () => ref.read(orderProvider.notifier).updateCartQuantity(
                                            item['menu_item_id'],
                                            qty - 1,
                                            options: optsList.isEmpty ? null : optsList,
                                            notes: note,
                                          ),
                                    ),
                                    Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, size: 20),
                                      onPressed: () => ref.read(orderProvider.notifier).updateCartQuantity(
                                            item['menu_item_id'],
                                            qty + 1,
                                            options: optsList.isEmpty ? null : optsList,
                                            notes: note,
                                          ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade400),
                                      onPressed: () => ref.read(orderProvider.notifier).removeFromCart(
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
        // Sơ đồ layout – fit bounding box thực tế của các object vào viewport
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (!_initialScaleApplied &&
                  constraints.maxWidth > 0 &&
                  constraints.maxHeight > 0 &&
                  layoutState.objects.isNotEmpty) {
                _initialScaleApplied = true;
                double minX = double.infinity, minY = double.infinity;
                double maxX = 0, maxY = 0;
                for (final obj in layoutState.objects) {
                  final x = Formatters.toNum(obj['position_x']).toDouble();
                  final y = Formatters.toNum(obj['position_y']).toDouble();
                  final w = (obj['width'] != null ? Formatters.toNum(obj['width']).toDouble() : 80);
                  final h = (obj['height'] != null ? Formatters.toNum(obj['height']).toDouble() : 80);
                  if (x < minX) minX = x;
                  if (y < minY) minY = y;
                  if (x + w > maxX) maxX = x + w;
                  if (y + h > maxY) maxY = y + h;
                }
                const padding = 60.0;
                minX = math.max(0, minX - padding);
                minY = math.max(0, minY - padding);
                maxX += padding;
                maxY += padding;
                final contentW = maxX - minX;
                final contentH = maxY - minY;
                final scaleX = constraints.maxWidth / contentW;
                final scaleY = constraints.maxHeight / contentH;
                final s = math.min(scaleX, scaleY).clamp(0.3, 2.0);
                _layoutTransformCtrl.value = Matrix4.identity()
                  ..scale(s)
                  ..translate(-minX, -minY);
              }
              return InteractiveViewer(
                transformationController: _layoutTransformCtrl,
                constrained: false,
                boundaryMargin: const EdgeInsets.all(300),
                minScale: 0.15,
                maxScale: 3.0,
                child: SizedBox(
                  width: 2000,
                  height: 4000,
                  child: Stack(
                    children: layoutState.objects.map((obj) {
                      final type = obj['type'] as String?;
                      final id = obj['id'];
                      final isTable = type == 'table';
                      final isSelected = isTable && id == selectedId;
                      final child = _buildLayoutObject(obj, isSelected: isSelected);
                      if (isTable) {
                        return Positioned(
                          left: Formatters.toNum(obj['position_x']).toDouble(),
                          top: Formatters.toNum(obj['position_y']).toDouble(),
                          child: GestureDetector(
                            onTap: () {
                              ref.read(orderProvider.notifier).selectTable(Formatters.toNum(id).toInt());
                              _tabController.animateTo(1);
                            },
                            child: child,
                          ),
                        );
                      }
                      return Positioned(
                        left: Formatters.toNum(obj['position_x']).toDouble(),
                        top: Formatters.toNum(obj['position_y']).toDouble(),
                        child: child,
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLayoutObject(Map<String, dynamic> obj, {bool isSelected = false}) {
    final type = obj['type'] as String? ?? 'table';
    final w = obj['width'] != null ? Formatters.toNum(obj['width']).toDouble() : 80.0;
    final h = obj['height'] != null ? Formatters.toNum(obj['height']).toDouble() : 80.0;
    final name = obj['name'] as String? ?? '';
    final rotationDeg = Formatters.toNum(obj['rotation']).toDouble();
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

  Widget _buildMenuPicker(MenuState menuState, OrderState orderState, LayoutState layoutState) {
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
              : Builder(builder: (_) {
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
                        onTap: () => _showAddOrEditItemDialog(item: item, existingQty: qty, existingNote: itemNote, existingOptions: existingOpts),
                        title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(hasItemOpts && (existingOpts ?? []).isEmpty ? 'Từ ${Formatters.currency(displayPrice)}' : Formatters.currency(displayPrice)),
                            if (hasItemOpts && (existingOpts ?? []).isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  itemOpts.map((o) => '${o['name']} +${Formatters.currency(o['extra_price'])}').join(' · '),
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            if ((existingOpts ?? []).isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  (existingOpts ?? []).map((o) => '${o['name']} +${Formatters.currency(o['extra_price'])}').join(' · '),
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
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
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
                                    onPressed: () => ref.read(orderProvider.notifier).updateCartQuantity(item['id'], qty - 1, options: existingOpts, notes: itemNote),
                                  ),
                                  Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
                                    onPressed: () => _showAddOrEditItemDialog(item: item, existingQty: 0, existingNote: null, existingOptions: null),
                                  ),
                                ],
                              )
                            : IconButton(
                                icon: const Icon(Icons.add_circle, color: AppTheme.primaryColor),
                                onPressed: () => _showAddOrEditItemDialog(item: item, existingQty: 0, existingNote: null, existingOptions: null),
                              ),
                      ),
                    );
                  },
                );
                }),
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
    int quantity = existingQty > 0 ? existingQty : 1;
    final noteController = TextEditingController(text: existingNote ?? '');
    final itemOptions = (item['options'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    List<Map<String, dynamic>> selectedOptions = existingOptions != null
        ? List.from(existingOptions)
        : [];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final basePrice = Formatters.toNum(item['price']);
          final optionsExtra = selectedOptions.fold<double>(0, (s, o) => s + Formatters.toNum(o['extra_price']));
          final unitPrice = basePrice + optionsExtra;
          final lineTotal = unitPrice * quantity;

          return AlertDialog(
            title: Text(existingQty > 0 ? 'Sửa món' : 'Thêm món'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  Text(Formatters.currency(unitPrice), style: TextStyle(color: Colors.grey.shade600)),
                  if (selectedOptions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Tổng dòng: ${Formatters.currency(lineTotal)}', style: const TextStyle(fontWeight: FontWeight.w500)),
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
                        final isSelected = selectedOptions.any((s) => Formatters.toNum(s['id']).toInt() == Formatters.toNum(id).toInt());
                        return FilterChip(
                          label: Text('$name +${Formatters.currency(extra)}'),
                          selected: isSelected,
                          selectedColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                          onSelected: (v) {
                            setDialogState(() {
                              if (v) {
                                selectedOptions = [...selectedOptions, {'id': id, 'name': name, 'extra_price': extra}];
                              } else {
                                selectedOptions = selectedOptions.where((s) => Formatters.toNum(s['id']).toInt() != Formatters.toNum(id).toInt()).toList();
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
                        onPressed: quantity <= 1 ? null : () => setDialogState(() => quantity = quantity - 1),
                      ),
                      Text('$quantity', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                  final note = noteController.text.trim().isEmpty ? null : noteController.text.trim();
                  if (existingQty > 0) {
                    ref.read(orderProvider.notifier).updateCartQuantity(item['id'], quantity, options: existingOptions, notes: existingNote);
                    ref.read(orderProvider.notifier).updateCartItemNote(item['id'], note, options: existingOptions, notes: existingNote);
                    ref.read(orderProvider.notifier).updateCartItemOptions(item['id'], selectedOptions, currentOptions: existingOptions, currentNotes: existingNote);
                  } else {
                    ref.read(orderProvider.notifier).addToCart(item, notes: note, quantity: quantity, options: selectedOptions);
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
                final extra = opts.fold<double>(0, (s, o) => s + Formatters.toNum(o is Map ? o['extra_price'] : 0));
                final unitPrice = base + extra;
                final lineTotal = unitPrice * Formatters.toNum(item['quantity']);
                final note = item['notes'] as String?;
                final hasNote = note != null && note.trim().isNotEmpty;
                final optNames = opts.map((o) => o is Map ? (o['name'] as String?) : null).whereType<String>().toList();
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
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                          ),
                        ),
                    ],
                  ),
                );
              }),
              const Divider(),
              Text('Tổng: ${Formatters.currency(orderState.cartTotal)}', style: const TextStyle(fontWeight: FontWeight.bold)),
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
              final order = await ref.read(orderProvider.notifier).submitOrder();
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
