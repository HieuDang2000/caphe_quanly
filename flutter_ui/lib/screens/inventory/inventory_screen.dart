import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../config/api_config.dart';
import '../../core/utils/formatters.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/loading_widget.dart';

final inventoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.get(ApiConfig.inventory);
  return List<Map<String, dynamic>>.from(res.data);
});

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = ref.watch(inventoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kho hàng'),
        actions: [
          IconButton(
            icon: const Icon(Icons.warning_amber),
            tooltip: 'Sắp hết',
            onPressed: () => _showLowStock(context, ref),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addItemDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: inventoryAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (items) => ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: items.length,
          itemBuilder: (_, index) {
            final item = items[index];
            final qty = (item['quantity'] as num).toDouble();
            final minQty = (item['min_quantity'] as num).toDouble();
            final isLow = qty <= minQty;

            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isLow ? AppTheme.errorColor.withValues(alpha: 0.15) : AppTheme.primaryColor.withValues(alpha: 0.15),
                  child: Icon(isLow ? Icons.warning : Icons.inventory_2, color: isLow ? AppTheme.errorColor : AppTheme.primaryColor),
                ),
                title: Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Row(
                  children: [
                    Text('${qty.toStringAsFixed(1)} ${item['unit']}'),
                    if (isLow) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: AppTheme.errorColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                        child: const Text('Sắp hết', style: TextStyle(color: AppTheme.errorColor, fontSize: 11)),
                      ),
                    ],
                  ],
                ),
                trailing: Text(Formatters.currency(item['cost_per_unit'] ?? 0), style: const TextStyle(fontSize: 12)),
                onTap: () => _showTransactionDialog(context, ref, item),
              ),
            );
          },
        ),
      ),
    );
  }

  void _addItemDialog(BuildContext context, WidgetRef ref) {
    final nameC = TextEditingController();
    final unitC = TextEditingController(text: 'kg');
    final qtyC = TextEditingController(text: '0');
    final minC = TextEditingController(text: '0');
    final costC = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Thêm nguyên liệu'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Tên')),
              const SizedBox(height: 12),
              TextField(controller: unitC, decoration: const InputDecoration(labelText: 'Đơn vị (kg, l, pcs...)')),
              const SizedBox(height: 12),
              TextField(controller: qtyC, decoration: const InputDecoration(labelText: 'Số lượng'), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              TextField(controller: minC, decoration: const InputDecoration(labelText: 'SL tối thiểu'), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              TextField(controller: costC, decoration: const InputDecoration(labelText: 'Giá/đơn vị'), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              final api = ref.read(apiClientProvider);
              await api.post(ApiConfig.inventory, data: {
                'name': nameC.text,
                'unit': unitC.text,
                'quantity': double.tryParse(qtyC.text) ?? 0,
                'min_quantity': double.tryParse(minC.text) ?? 0,
                'cost_per_unit': double.tryParse(costC.text) ?? 0,
              });
              if (context.mounted) {
                Navigator.pop(context);
                ref.invalidate(inventoryProvider);
              }
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }

  void _showTransactionDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> item) {
    final qtyC = TextEditingController();
    final reasonC = TextEditingController();
    String type = 'in';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${item['name']} - Nhập/Xuất kho'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Tồn kho: ${(item['quantity'] as num).toStringAsFixed(1)} ${item['unit']}'),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'in', label: Text('Nhập'), icon: Icon(Icons.add)),
                    ButtonSegment(value: 'out', label: Text('Xuất'), icon: Icon(Icons.remove)),
                    ButtonSegment(value: 'adjust', label: Text('Điều chỉnh'), icon: Icon(Icons.edit)),
                  ],
                  selected: {type},
                  onSelectionChanged: (v) => setDialogState(() => type = v.first),
                ),
                const SizedBox(height: 16),
                TextField(controller: qtyC, decoration: const InputDecoration(labelText: 'Số lượng'), keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                TextField(controller: reasonC, decoration: const InputDecoration(labelText: 'Lý do')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () async {
                final api = ref.read(apiClientProvider);
                await api.post('${ApiConfig.inventory}/transactions', data: {
                  'inventory_item_id': item['id'],
                  'type': type,
                  'quantity': double.tryParse(qtyC.text) ?? 0,
                  'reason': reasonC.text,
                });
                if (context.mounted) {
                  Navigator.pop(context);
                  ref.invalidate(inventoryProvider);
                }
              },
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLowStock(BuildContext context, WidgetRef ref) async {
    final api = ref.read(apiClientProvider);
    final res = await api.get('${ApiConfig.inventory}/low-stock');
    final items = List<Map<String, dynamic>>.from(res.data);

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nguyên liệu sắp hết'),
        content: items.isEmpty
            ? const Text('Tất cả nguyên liệu đều đủ!')
            : SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: items.map((item) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.warning, color: AppTheme.errorColor),
                    title: Text(item['name'] ?? ''),
                    subtitle: Text('Còn: ${(item['quantity'] as num).toStringAsFixed(1)} ${item['unit']} (tối thiểu: ${(item['min_quantity'] as num).toStringAsFixed(1)})'),
                  )).toList(),
                ),
              ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng'))],
      ),
    );
  }
}
