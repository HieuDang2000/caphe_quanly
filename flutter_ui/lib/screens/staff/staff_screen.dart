import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../config/api_config.dart';
import '../../core/utils/formatters.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/responsive_layout.dart';

final staffListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.get(ApiConfig.staff);
  return List<Map<String, dynamic>>.from(res.data);
});

final shiftsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.get('${ApiConfig.staff}/shifts');
  final data = res.data is Map ? (res.data as Map)['data'] : res.data;
  return List<Map<String, dynamic>>.from(data ?? []);
});

final attendancesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.get('${ApiConfig.staff}/attendances');
  final data = res.data is Map ? (res.data as Map)['data'] : res.data;
  return List<Map<String, dynamic>>.from(data ?? []);
});

class StaffScreen extends ConsumerStatefulWidget {
  const StaffScreen({super.key});

  @override
  ConsumerState<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends ConsumerState<StaffScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý nhân viên'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Nhân viên'),
            Tab(text: 'Ca làm'),
            Tab(text: 'Chấm công'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _StaffListTab(),
          _ShiftsTab(),
          _AttendanceTab(),
        ],
      ),
    );
  }
}

class _StaffListTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(staffListProvider);

    return staffAsync.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (staff) => ListView.builder(
        padding: EdgeInsets.all(isMobile(context) ? 8 : 12),
        itemCount: staff.length,
        itemBuilder: (_, index) {
          final s = staff[index];
          final profile = s['staff_profile'] as Map<String, dynamic>?;
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.primaryColor,
                child: Text((s['name'] ?? 'U')[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
              ),
              title: Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${s['role']?['display_name'] ?? ''} • ${profile?['position'] ?? 'Chưa phân công'}'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (profile?['salary'] != null) Text(Formatters.currency(profile!['salary']), style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(s['phone'] ?? '', style: const TextStyle(fontSize: 12)),
                ],
              ),
              onTap: () => _showProfileDialog(context, ref, s),
            ),
          );
        },
      ),
    );
  }

  void _showProfileDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> staff) {
    final profile = staff['staff_profile'] as Map<String, dynamic>?;
    final posController = TextEditingController(text: profile?['position'] ?? '');
    final salaryController = TextEditingController(text: profile?['salary']?.toString() ?? '');
    final addressController = TextEditingController(text: profile?['address'] ?? '');
    final emergencyController = TextEditingController(text: profile?['emergency_contact'] ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Hồ sơ - ${staff['name']}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: posController, decoration: const InputDecoration(labelText: 'Vị trí')),
              const SizedBox(height: 12),
              TextField(controller: salaryController, decoration: const InputDecoration(labelText: 'Lương'), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Địa chỉ'), maxLines: 2),
              const SizedBox(height: 12),
              TextField(controller: emergencyController, decoration: const InputDecoration(labelText: 'Liên hệ khẩn cấp')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              final api = ref.read(apiClientProvider);
              await api.put('${ApiConfig.staff}/${staff['id']}/profile', data: {
                'position': posController.text,
                'salary': double.tryParse(salaryController.text) ?? 0,
                'address': addressController.text,
                'emergency_contact': emergencyController.text,
              });
              if (context.mounted) {
                Navigator.pop(context);
                ref.invalidate(staffListProvider);
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}

class _ShiftsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shiftsAsync = ref.watch(shiftsProvider);

    return shiftsAsync.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (shifts) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: ElevatedButton.icon(
              onPressed: () => _addShiftDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Thêm ca'),
            ),
          ),
          Expanded(
            child: shifts.isEmpty
                ? const Center(child: Text('Chưa có ca làm'))
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: shifts.length,
                    itemBuilder: (_, i) {
                      final shift = shifts[i];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.schedule, color: AppTheme.primaryColor),
                          title: Text(shift['user']?['name'] ?? ''),
                          subtitle: Text('${shift['shift_date']} | ${shift['start_time']} - ${shift['end_time']}'),
                          trailing: Chip(label: Text(shift['status'] ?? 'scheduled', style: const TextStyle(fontSize: 12))),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _addShiftDialog(BuildContext context, WidgetRef ref) {
    final userIdController = TextEditingController();
    final dateController = TextEditingController();
    final startController = TextEditingController(text: '08:00');
    final endController = TextEditingController(text: '16:00');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Thêm ca làm'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: userIdController, decoration: const InputDecoration(labelText: 'User ID'), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              TextField(controller: dateController, decoration: const InputDecoration(labelText: 'Ngày (YYYY-MM-DD)')),
              const SizedBox(height: 12),
              TextField(controller: startController, decoration: const InputDecoration(labelText: 'Giờ bắt đầu (HH:mm)')),
              const SizedBox(height: 12),
              TextField(controller: endController, decoration: const InputDecoration(labelText: 'Giờ kết thúc (HH:mm)')),
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
              final api = ref.read(apiClientProvider);
              try {
                await api.post('${ApiConfig.staff}/shifts', data: {
                  'user_id': int.tryParse(userIdController.text),
                  'shift_date': dateController.text,
                  'start_time': startController.text,
                  'end_time': endController.text,
                });
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                  ref.invalidate(shiftsProvider);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã tạo ca làm')));
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                }
              }
            },
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
  }
}

class _AttendanceTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendancesAsync = ref.watch(attendancesProvider);

    return attendancesAsync.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (attendances) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await ref.read(apiClientProvider).post('${ApiConfig.staff}/check-in');
                      if (context.mounted) {
                        ref.invalidate(attendancesProvider);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Check-in thành công!')));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                      }
                    }
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Check In'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await ref.read(apiClientProvider).post('${ApiConfig.staff}/check-out');
                      if (context.mounted) {
                        ref.invalidate(attendancesProvider);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Check-out thành công!')));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                      }
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Check Out'),
                ),
              ],
            ),
          ),
          Expanded(
            child: attendances.isEmpty
                ? const Center(child: Text('Chưa có bản ghi chấm công'))
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: attendances.length,
                    itemBuilder: (_, i) {
                      final att = attendances[i];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.fingerprint, color: AppTheme.primaryColor),
                          title: Text(att['user']?['name'] ?? ''),
                          subtitle: Text('In: ${att['check_in'] ?? '-'}\nOut: ${att['check_out'] ?? '-'}'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
