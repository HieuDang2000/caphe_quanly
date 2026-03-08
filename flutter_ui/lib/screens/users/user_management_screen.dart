import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../providers/user_provider.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/responsive_layout.dart';

class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(userManagementProvider);
    final mobile = isMobile(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Users'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Thêm user',
            onPressed: () => _addUserDialog(context, ref, state.roles),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(userManagementProvider.notifier).load(),
          ),
        ],
      ),
      body: state.isLoading
          ? const LoadingWidget()
          : state.error != null
              ? Center(child: Text('Lỗi: ${state.error}'))
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(userManagementProvider.notifier).load(),
                  child: ListView.builder(
                    padding: EdgeInsets.all(mobile ? 8 : 12),
                    itemCount: state.users.length,
                    itemBuilder: (_, index) {
                      final user = state.users[index];
                      final isActive = user['is_active'] ?? true;
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                isActive ? AppTheme.primaryColor : Colors.grey,
                            child: Text(
                              (user['name'] ?? 'U')[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(user['name'] ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              '${user['email']} • ${user['role']?['display_name'] ?? ''}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isActive)
                                const Chip(
                                    label: Text('Khóa',
                                        style: TextStyle(fontSize: 11)),
                                    backgroundColor: Color(0xFFFFCDD2)),
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _editUserDialog(
                                    context, ref, user, state.roles),
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

  void _addUserDialog(BuildContext context, WidgetRef ref,
      List<Map<String, dynamic>> roles) {
    final nameC = TextEditingController();
    final emailC = TextEditingController();
    final phoneC = TextEditingController();
    final passwordC = TextEditingController();
    int? selectedRoleId = roles.isNotEmpty ? roles.first['id'] as int? : null;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Thêm user mới'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nameC,
                    decoration: const InputDecoration(labelText: 'Tên')),
                const SizedBox(height: 12),
                TextField(
                    controller: emailC,
                    decoration: const InputDecoration(
                        labelText: 'Tên đăng nhập (email)')),
                const SizedBox(height: 12),
                TextField(
                    controller: phoneC,
                    decoration: const InputDecoration(labelText: 'SĐT'),
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                TextField(
                    controller: passwordC,
                    decoration: const InputDecoration(labelText: 'Mật khẩu'),
                    obscureText: true),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: selectedRoleId,
                  decoration: const InputDecoration(labelText: 'Vai trò'),
                  items: roles
                      .map((r) => DropdownMenuItem<int>(
                          value: r['id'] as int,
                          child: Text(r['display_name'] as String? ?? '')))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedRoleId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () async {
                if (nameC.text.isEmpty || emailC.text.isEmpty) return;
                final ok =
                    await ref.read(userManagementProvider.notifier).create({
                  'name': nameC.text.trim(),
                  'email': emailC.text.trim(),
                  'phone': phoneC.text.isNotEmpty ? phoneC.text.trim() : null,
                  'password': passwordC.text,
                  'role_id': selectedRoleId,
                  'is_active': true,
                });
                if (context.mounted) {
                  Navigator.pop(context);
                  if (!ok) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            ref.read(userManagementProvider).error ?? 'Lỗi')));
                  }
                }
              },
              child: const Text('Thêm'),
            ),
          ],
        ),
      ),
    );
  }

  void _editUserDialog(BuildContext context, WidgetRef ref,
      Map<String, dynamic> user, List<Map<String, dynamic>> roles) {
    final nameC = TextEditingController(text: user['name']);
    final emailC = TextEditingController(text: user['email']);
    final phoneC = TextEditingController(text: user['phone'] ?? '');
    bool isActive = user['is_active'] ?? true;
    int? selectedRoleId = user['role_id'] as int?;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Chỉnh sửa - ${user['name']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nameC,
                    decoration: const InputDecoration(labelText: 'Tên')),
                const SizedBox(height: 12),
                TextField(
                    controller: emailC,
                    decoration: const InputDecoration(
                        labelText: 'Tên đăng nhập (email)')),
                const SizedBox(height: 12),
                TextField(
                    controller: phoneC,
                    decoration: const InputDecoration(labelText: 'SĐT')),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: selectedRoleId,
                  decoration: const InputDecoration(labelText: 'Vai trò'),
                  items: roles
                      .map((r) => DropdownMenuItem<int>(
                          value: r['id'] as int,
                          child:
                              Text(r['display_name'] as String? ?? '')))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedRoleId = v),
                ),
                SwitchListTile(
                  title: const Text('Hoạt động'),
                  value: isActive,
                  onChanged: (v) => setDialogState(() => isActive = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy')),
            TextButton(
              onPressed: () async {
                final ok = await ref
                    .read(userManagementProvider.notifier)
                    .delete(user['id'] as int);
                if (context.mounted) {
                  Navigator.pop(context);
                  if (!ok) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            ref.read(userManagementProvider).error ?? 'Lỗi')));
                  }
                }
              },
              child: const Text('Xóa',
                  style: TextStyle(color: AppTheme.errorColor)),
            ),
            ElevatedButton(
              onPressed: () async {
                final ok = await ref
                    .read(userManagementProvider.notifier)
                    .update(user['id'] as int, {
                  'name': nameC.text,
                  'email': emailC.text,
                  'phone': phoneC.text.isNotEmpty ? phoneC.text : null,
                  'role_id': selectedRoleId,
                  'is_active': isActive,
                });
                if (context.mounted) {
                  Navigator.pop(context);
                  if (!ok) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            ref.read(userManagementProvider).error ?? 'Lỗi')));
                  }
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
