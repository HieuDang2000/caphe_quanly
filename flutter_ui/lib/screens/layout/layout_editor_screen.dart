import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/layout_provider.dart';
import '../../widgets/loading_widget.dart';

class LayoutEditorScreen extends ConsumerStatefulWidget {
  const LayoutEditorScreen({super.key});

  @override
  ConsumerState<LayoutEditorScreen> createState() => _LayoutEditorScreenState();
}

class _LayoutEditorScreenState extends ConsumerState<LayoutEditorScreen> {
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(layoutProvider.notifier).loadFloors());
  }

  static const Map<String, String> _typeLabel = {
    'table': 'Bàn',
    'wall': 'Tường',
    'window': 'Cửa sổ',
    'door': 'Cửa',
    'reception': 'Quầy',
  };

  String _suggestedNameForType(String type) {
    final objects = ref.read(layoutProvider).objects;
    final count = objects.where((o) => o['type'] == type).length;
    return '${_typeLabel[type] ?? type} ${count + 1}';
  }

  void _addObject(String type, String name) {
    final floorId = ref.read(layoutProvider).selectedFloorId;
    if (floorId == null) return;

    final defaults = {
      'table': {'width': 80.0, 'height': 80.0, 'properties': {'seats': 4, 'shape': 'square'}},
      'wall': {'width': 200.0, 'height': 20.0, 'properties': {'color': '#8B4513'}},
      'window': {'width': 100.0, 'height': 20.0, 'properties': {'color': '#87CEEB'}},
      'door': {'width': 60.0, 'height': 20.0, 'properties': {'color': '#DEB887'}},
      'reception': {'width': 120.0, 'height': 60.0, 'properties': {'color': '#CD853F'}},
    };

    ref.read(layoutProvider.notifier).addObject({
      'floor_id': floorId,
      'type': type,
      'name': name,
      'position_x': 100,
      'position_y': 100,
      'rotation': 0,
      ...defaults[type] ?? {},
    });
  }

  void _showAddObjectNameDialog(String type) {
    final suggested = _suggestedNameForType(type);
    final controller = TextEditingController(text: suggested);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Thêm ${_typeLabel[type] ?? type}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Tên (để phân biệt)',
            hintText: suggested,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim().isEmpty ? suggested : controller.text.trim();
              Navigator.of(dialogContext).pop();
              _addObject(type, name);
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveLayout() async {
    final objects = ref.read(layoutProvider).objects;
    final batch = objects.map((o) => {
      'id': o['id'],
      'position_x': o['position_x'],
      'position_y': o['position_y'],
      'rotation': (o['rotation'] as num?)?.toDouble() ?? 0.0,
    }).toList();

    await ref.read(layoutProvider.notifier).batchUpdate(batch);
    setState(() => _hasChanges = false);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu layout')));
  }

  @override
  Widget build(BuildContext context) {
    final layoutState = ref.watch(layoutProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sơ đồ quán'),
        actions: [
          if (_hasChanges)
            IconButton(icon: const Icon(Icons.save), onPressed: _saveLayout, tooltip: 'Lưu'),
          PopupMenuButton<String>(
            icon: const Icon(Icons.add),
            onSelected: (type) {
              _showAddObjectNameDialog(type);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'table', child: ListTile(leading: Icon(Icons.table_restaurant), title: Text('Thêm bàn'))),
              const PopupMenuItem(value: 'wall', child: ListTile(leading: Icon(Icons.fence), title: Text('Thêm tường'))),
              const PopupMenuItem(value: 'window', child: ListTile(leading: Icon(Icons.window), title: Text('Thêm cửa sổ'))),
              const PopupMenuItem(value: 'door', child: ListTile(leading: Icon(Icons.door_front_door), title: Text('Thêm cửa'))),
              const PopupMenuItem(value: 'reception', child: ListTile(leading: Icon(Icons.desk), title: Text('Thêm quầy'))),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (layoutState.floors.isNotEmpty)
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
            child: layoutState.isLoading
                ? const LoadingWidget()
                : InteractiveViewer(
                    constrained: false,
                    boundaryMargin: const EdgeInsets.all(200),
                    minScale: 0.2,
                    maxScale: 3.0,
                    child: SizedBox(
                      width: 2000,
                      height: 4000,
                      child: Stack(
                        children: layoutState.objects.map((obj) {
                          return Positioned(
                            left: Formatters.toNum(obj['position_x']).toDouble(),
                            top: Formatters.toNum(obj['position_y']).toDouble(),
                            child: GestureDetector(
                              onPanUpdate: (details) {
                                final newX = Formatters.toNum(obj['position_x']).toDouble() + details.delta.dx;
                                final newY = Formatters.toNum(obj['position_y']).toDouble() + details.delta.dy;
                                ref.read(layoutProvider.notifier).updateLocalPosition(obj['id'], newX, newY);
                                setState(() => _hasChanges = true);
                              },
                              onLongPress: () => _showObjectMenu(obj),
                              child: _buildObject(obj),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildObject(Map<String, dynamic> obj) {
    final type = obj['type'] as String;
    final w = Formatters.toNum(obj['width']).toDouble();
    final h = Formatters.toNum(obj['height']).toDouble();
    final name = obj['name'] as String? ?? '';
    final rotationDeg = Formatters.toNum(obj['rotation']).toDouble();
    final rotationRad = rotationDeg * math.pi / 180;
    final showNameAlways = ['wall', 'window', 'door', 'reception'].contains(type);

    Color color;
    IconData icon;
    switch (type) {
      case 'table':
        color = AppTheme.primaryColor;
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
              style: TextStyle(fontSize: showNameAlways ? 11 : 10, color: color, fontWeight: FontWeight.bold),
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
        color: color.withValues(alpha: 0.2),
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(isTable ? 8 : 4),
      ),
      child: isTable
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 24),
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

  void _showObjectMenu(Map<String, dynamic> obj) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(obj['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Loại: ${obj['type']}'),
            ),
            const Divider(height: 0),
            ListTile(
              leading: const Icon(Icons.rotate_right),
              title: const Text('Xoay 90°'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                final current = (obj['rotation'] as num?)?.toDouble() ?? 0.0;
                final next = (current + 90) % 360;
                ref.read(layoutProvider.notifier).updateLocalRotation(obj['id'], next);
                setState(() => _hasChanges = true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Đổi tên'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _renameObject(obj);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: AppTheme.errorColor),
              title: const Text('Xóa', style: TextStyle(color: AppTheme.errorColor)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                ref.read(layoutProvider.notifier).deleteObject(obj['id']);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _renameObject(Map<String, dynamic> obj) {
    final controller = TextEditingController(text: obj['name']);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đổi tên'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Tên mới')),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              ref.read(layoutProvider.notifier).updateObject(obj['id'], {'name': controller.text});
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
