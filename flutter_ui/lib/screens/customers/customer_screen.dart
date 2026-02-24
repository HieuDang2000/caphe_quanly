import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../config/api_config.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/loading_widget.dart';

final customerListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.get(ApiConfig.customers);
  return List<Map<String, dynamic>>.from(res.data);
});

class CustomerScreen extends ConsumerWidget {
  const CustomerScreen({super.key});

  Color _tierColor(String tier) {
    switch (tier) {
      case 'platinum': return Colors.purple;
      case 'gold': return Colors.amber;
      case 'silver': return Colors.grey;
      default: return AppTheme.primaryColor;
    }
  }

  String _tierLabel(String tier) {
    switch (tier) {
      case 'platinum': return 'Bạch kim';
      case 'gold': return 'Vàng';
      case 'silver': return 'Bạc';
      default: return 'Thường';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customerListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Khách hàng thân thiết')),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addCustomerDialog(context, ref),
        child: const Icon(Icons.person_add),
      ),
      body: customersAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (customers) => ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: customers.length,
          itemBuilder: (_, index) {
            final c = customers[index];
            final tier = c['tier'] as String? ?? 'regular';
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _tierColor(tier).withValues(alpha: 0.15),
                  child: Icon(Icons.person, color: _tierColor(tier)),
                ),
                title: Text(c['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${c['phone'] ?? '-'} • ${_tierLabel(tier)}'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${c['points'] ?? 0} điểm', style: TextStyle(fontWeight: FontWeight.bold, color: _tierColor(tier))),
                    const Text('điểm tích lũy', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
                onTap: () => _showCustomerDetail(context, ref, c),
              ),
            );
          },
        ),
      ),
    );
  }

  void _addCustomerDialog(BuildContext context, WidgetRef ref) {
    final nameC = TextEditingController();
    final phoneC = TextEditingController();
    final emailC = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Thêm khách hàng'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Tên')),
            const SizedBox(height: 12),
            TextField(controller: phoneC, decoration: const InputDecoration(labelText: 'SĐT'), keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            TextField(controller: emailC, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              final api = ref.read(apiClientProvider);
              await api.post(ApiConfig.customers, data: {
                'name': nameC.text,
                'phone': phoneC.text.isNotEmpty ? phoneC.text : null,
                'email': emailC.text.isNotEmpty ? emailC.text : null,
              });
              if (context.mounted) {
                Navigator.pop(context);
                ref.invalidate(customerListProvider);
              }
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }

  void _showCustomerDetail(BuildContext context, WidgetRef ref, Map<String, dynamic> customer) {
    final pointsC = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: _tierColor(customer['tier'] ?? 'regular'),
                    child: const Icon(Icons.person, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(customer['name'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('${customer['phone'] ?? '-'} • ${_tierLabel(customer['tier'] ?? 'regular')}'),
                        Text('${customer['points'] ?? 0} điểm', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(controller: pointsC, decoration: const InputDecoration(labelText: 'Số điểm'), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final points = int.tryParse(pointsC.text);
                        if (points == null || points <= 0) return;
                        final api = ref.read(apiClientProvider);
                        await api.post('${ApiConfig.customers}/${customer['id']}/points', data: {'points': points});
                        if (context.mounted) {
                          Navigator.pop(context);
                          ref.invalidate(customerListProvider);
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Tích điểm'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final points = int.tryParse(pointsC.text);
                        if (points == null || points <= 0) return;
                        final api = ref.read(apiClientProvider);
                        await api.post('${ApiConfig.customers}/${customer['id']}/redeem', data: {'points': points});
                        if (context.mounted) {
                          Navigator.pop(context);
                          ref.invalidate(customerListProvider);
                        }
                      },
                      icon: const Icon(Icons.redeem),
                      label: const Text('Đổi điểm'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
