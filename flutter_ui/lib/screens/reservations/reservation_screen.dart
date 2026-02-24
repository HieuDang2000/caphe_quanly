import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../config/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../config/api_config.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/loading_widget.dart';

final reservationListProvider = FutureProvider.family<List<Map<String, dynamic>>, String?>((ref, date) async {
  final api = ref.watch(apiClientProvider);
  final params = <String, dynamic>{};
  if (date != null) params['date'] = date;
  final res = await api.get(ApiConfig.reservations, queryParameters: params);
  return List<Map<String, dynamic>>.from(res.data);
});

class ReservationScreen extends ConsumerStatefulWidget {
  const ReservationScreen({super.key});

  @override
  ConsumerState<ReservationScreen> createState() => _ReservationScreenState();
}

class _ReservationScreenState extends ConsumerState<ReservationScreen> {
  DateTime _selectedDate = DateTime.now();

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed': return AppTheme.successColor;
      case 'cancelled': return AppTheme.errorColor;
      case 'completed': return Colors.blue;
      default: return AppTheme.warningColor;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending': return 'Chờ xác nhận';
      case 'confirmed': return 'Đã xác nhận';
      case 'cancelled': return 'Đã hủy';
      case 'completed': return 'Hoàn thành';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reservationsAsync = ref.watch(reservationListProvider(_dateStr));

    return Scaffold(
      appBar: AppBar(title: const Text('Đặt bàn')),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addReservationDialog(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1))),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 30)),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                      );
                      if (picked != null) setState(() => _selectedDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Center(
                        child: Text(
                          DateFormat('EEEE, dd/MM/yyyy', 'vi').format(_selectedDate),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1))),
                ),
              ],
            ),
          ),
          Expanded(
            child: reservationsAsync.when(
              loading: () => const LoadingWidget(),
              error: (e, _) => Center(child: Text('Lỗi: $e')),
              data: (reservations) => reservations.isEmpty
                  ? const Center(child: Text('Chưa có đặt bàn'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: reservations.length,
                      itemBuilder: (_, index) {
                        final r = reservations[index];
                        final status = r['status'] as String? ?? 'pending';
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _statusColor(status).withValues(alpha: 0.15),
                              child: Icon(Icons.event_seat, color: _statusColor(status)),
                            ),
                            title: Text(r['customer']?['name'] ?? 'Khách', style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${r['table']?['name'] ?? ''} • ${r['guests_count'] ?? 1} khách'),
                                Text('${r['start_time']} - ${r['end_time']}'),
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: _statusColor(status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                                  child: Text(_statusLabel(status), style: TextStyle(fontSize: 12, color: _statusColor(status))),
                                ),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: PopupMenuButton<String>(
                              onSelected: (newStatus) async {
                                final api = ref.read(apiClientProvider);
                                await api.put('${ApiConfig.reservations}/${r['id']}/status', data: {'status': newStatus});
                                ref.invalidate(reservationListProvider(_dateStr));
                              },
                              itemBuilder: (_) => [
                                if (status == 'pending') const PopupMenuItem(value: 'confirmed', child: Text('Xác nhận')),
                                if (status != 'completed' && status != 'cancelled') const PopupMenuItem(value: 'completed', child: Text('Hoàn thành')),
                                if (status != 'cancelled') const PopupMenuItem(value: 'cancelled', child: Text('Hủy')),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _addReservationDialog() {
    final customerIdC = TextEditingController();
    final tableIdC = TextEditingController();
    final guestsC = TextEditingController(text: '2');
    final startC = TextEditingController(text: '10:00');
    final endC = TextEditingController(text: '12:00');
    final notesC = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Đặt bàn mới'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: customerIdC, decoration: const InputDecoration(labelText: 'Customer ID'), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              TextField(controller: tableIdC, decoration: const InputDecoration(labelText: 'Table ID'), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              TextField(controller: guestsC, decoration: const InputDecoration(labelText: 'Số khách'), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              TextField(controller: startC, decoration: const InputDecoration(labelText: 'Giờ bắt đầu (HH:mm)')),
              const SizedBox(height: 12),
              TextField(controller: endC, decoration: const InputDecoration(labelText: 'Giờ kết thúc (HH:mm)')),
              const SizedBox(height: 12),
              TextField(controller: notesC, decoration: const InputDecoration(labelText: 'Ghi chú'), maxLines: 2),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              final api = ref.read(apiClientProvider);
              await api.post(ApiConfig.reservations, data: {
                'customer_id': int.tryParse(customerIdC.text),
                'table_id': int.tryParse(tableIdC.text),
                'reservation_date': _dateStr,
                'start_time': startC.text,
                'end_time': endC.text,
                'guests_count': int.tryParse(guestsC.text) ?? 2,
                'notes': notesC.text.isNotEmpty ? notesC.text : null,
              });
              if (mounted) {
                Navigator.pop(context);
                ref.invalidate(reservationListProvider(_dateStr));
              }
            },
            child: const Text('Đặt bàn'),
          ),
        ],
      ),
    );
  }
}
