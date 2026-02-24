import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../config/api_config.dart';
import '../../widgets/loading_widget.dart';

final userListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.get(ApiConfig.users);
  return List<Map<String, dynamic>>.from(res.data);
});

class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(userListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý Users')),
      body: usersAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (users) => ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: users.length,
          itemBuilder: (_, index) {
            final user = users[index];
            final isActive = user['is_active'] ?? true;
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isActive ? AppTheme.primaryColor : Colors.grey,
                  child: Text(
                    (user['name'] ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(user['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${user['email']} • ${user['role']?['display_name'] ?? ''}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isActive)
                      const Chip(label: Text('Khóa', style: TextStyle(fontSize: 11)), backgroundColor: Color(0xFFFFCDD2)),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _editUserDialog(context, ref, user),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _editUserDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> user) {
    final nameC = TextEditingController(text: user['name']);
    final emailC = TextEditingController(text: user['email']);
    final phoneC = TextEditingController(text: user['phone'] ?? '');
    bool isActive = user['is_active'] ?? true;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Chỉnh sửa - ${user['name']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Tên')),
                const SizedBox(height: 12),
                TextField(controller: emailC, decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 12),
                TextField(controller: phoneC, decoration: const InputDecoration(labelText: 'SĐT')),
                SwitchListTile(
                  title: const Text('Hoạt động'),
                  value: isActive,
                  onChanged: (v) => setDialogState(() => isActive = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
            TextButton(
              onPressed: () async {
                final api = ref.read(apiClientProvider);
                await api.delete('${ApiConfig.users}/${user['id']}');
                if (context.mounted) {
                  Navigator.pop(context);
                  ref.invalidate(userListProvider);
                }
              },
              child: const Text('Xóa', style: TextStyle(color: AppTheme.errorColor)),
            ),
            ElevatedButton(
              onPressed: () async {
                final api = ref.read(apiClientProvider);
                await api.put('${ApiConfig.users}/${user['id']}', data: {
                  'name': nameC.text,
                  'email': emailC.text,
                  'phone': phoneC.text.isNotEmpty ? phoneC.text : null,
                  'is_active': isActive,
                });
                if (context.mounted) {
                  Navigator.pop(context);
                  ref.invalidate(userListProvider);
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}
