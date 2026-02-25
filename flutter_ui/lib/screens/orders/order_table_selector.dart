import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/layout_provider.dart';
import '../../providers/order_provider.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/responsive_layout.dart';

class OrderTableSelector extends ConsumerStatefulWidget {
  const OrderTableSelector({super.key, required this.onNavigateToMenu});

  final VoidCallback onNavigateToMenu;

  @override
  ConsumerState<OrderTableSelector> createState() => _OrderTableSelectorState();
}

class _OrderTableSelectorState extends ConsumerState<OrderTableSelector> {
  final TransformationController _layoutTransformCtrl = TransformationController();
  bool _initialScaleApplied = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(orderProvider.notifier).loadActiveOrders();
    });
  }

  @override
  void dispose() {
    _layoutTransformCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layoutState = ref.watch(layoutProvider);
    final orderState = ref.watch(orderProvider);
    final activeTableIds = orderState.activeOrders
        .map((o) => Formatters.toNum(o['table_id']).toInt())
        .where((id) => id > 0)
        .toSet();

    if (layoutState.isLoading) return const LoadingWidget();

    final selectedId = orderState.selectedTableId;
    String? selectedTableName;
    if (selectedId != null) {
      final match = layoutState.objects.where((o) => o['id'] == selectedId);
      selectedTableName = match.isEmpty ? 'Bàn' : (match.first['name'] as String? ?? 'Bàn');
    }
    final isTakeaway = selectedId == null;

    final mobile = isMobile(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: mobile ? 8 : 12, vertical: mobile ? 6 : 8),
          child: mobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      onTap: () {
                        ref.read(orderProvider.notifier).selectTable(null);
                        widget.onNavigateToMenu();
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
                    const SizedBox(height: 8),
                    Text(
                      selectedTableName != null ? 'Đang chọn: $selectedTableName' : 'Đang chọn: Mang đi',
                      style: Theme.of(context).textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                )
              : Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    ref.read(orderProvider.notifier).selectTable(null);
                    widget.onNavigateToMenu();
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
                      final tableId = Formatters.toNum(id).toInt();
                      final isSelected = isTable && tableId == selectedId;
                      final hasActiveOrder = isTable && activeTableIds.contains(tableId);
                      final child = _buildLayoutObject(
                        obj,
                        isSelected: isSelected,
                        hasActiveOrder: hasActiveOrder,
                      );
                      if (isTable) {
                        return Positioned(
                          left: Formatters.toNum(obj['position_x']).toDouble(),
                          top: Formatters.toNum(obj['position_y']).toDouble(),
                          child: GestureDetector(
                            onTap: () {
                              ref.read(orderProvider.notifier).selectTable(Formatters.toNum(id).toInt());
                              widget.onNavigateToMenu();
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

  Widget _buildLayoutObject(
    Map<String, dynamic> obj, {
    bool isSelected = false,
    bool hasActiveOrder = false,
  }) {
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
        if (isSelected) {
          color = AppTheme.primaryColor;
        } else if (hasActiveOrder) {
          color = AppTheme.successColor;
        } else {
          color = AppTheme.primaryColor;
        }
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
}

