import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../config/app_theme.dart';
import '../../providers/reservation_provider.dart';
import '../../core/database/local_database.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/responsive_layout.dart';

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
      case 'confirmed':
        return AppTheme.successColor;
      case 'cancelled':
        return AppTheme.errorColor;
      case 'completed':
        return Colors.blue;
      default:
        return AppTheme.warningColor;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Chờ xác nhận';
      case 'confirmed':
        return 'Đã xác nhận';
      case 'cancelled':
        return 'Đã hủy';
      case 'completed':
        return 'Hoàn thành';
      default:
        return status;
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadReservations());
  }

  void _loadReservations() {
    ref.read(reservationProvider.notifier).load(date: _dateStr);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reservationProvider);
    final mobile = isMobile(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Đặt bàn')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addReservationDialog(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(mobile ? 8 : 12),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _selectedDate =
                          _selectedDate.subtract(const Duration(days: 1));
                    });
                    _loadReservations();
                  },
                ),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate:
                            DateTime.now().subtract(const Duration(days: 30)),
                        lastDate:
                            DateTime.now().add(const Duration(days: 90)),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                        _loadReservations();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Center(
                        child: Text(
                          DateFormat('EEEE, dd/MM/yyyy', 'vi')
                              .format(_selectedDate),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor),
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _selectedDate =
                          _selectedDate.add(const Duration(days: 1));
                    });
                    _loadReservations();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: state.isLoading
                ? const LoadingWidget()
                : state.error != null
                    ? Center(child: Text('Lỗi: ${state.error}'))
                    : state.reservations.isEmpty
                        ? const Center(child: Text('Chưa có đặt bàn'))
                        : ListView.builder(
                            padding: EdgeInsets.all(mobile ? 8 : 12),
                            itemCount: state.reservations.length,
                            itemBuilder: (_, index) {
                              final r = state.reservations[index];
                              final status =
                                  r['status'] as String? ?? 'pending';
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        _statusColor(status).withValues(alpha: 0.15),
                                    child: Icon(Icons.event_seat,
                                        color: _statusColor(status)),
                                  ),
                                  title: Text(
                                      r['customer']?['name'] ?? 'Khách',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          '${r['table']?['name'] ?? ''} • ${r['guests_count'] ?? 1} khách'),
                                      Text(
                                          '${r['start_time']} - ${r['end_time']}'),
                                      Container(
                                        margin:
                                            const EdgeInsets.only(top: 4),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                            color: _statusColor(status)
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        child: Text(_statusLabel(status),
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: _statusColor(status))),
                                      ),
                                    ],
                                  ),
                                  isThreeLine: true,
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (newStatus) async {
                                      final ok = await ref
                                          .read(reservationProvider.notifier)
                                          .updateStatus(
                                              r['id'] as int, newStatus);
                                      if (ok) _loadReservations();
                                    },
                                    itemBuilder: (_) => [
                                      if (status == 'pending')
                                        const PopupMenuItem(
                                            value: 'confirmed',
                                            child: Text('Xác nhận')),
                                      if (status != 'completed' &&
                                          status != 'cancelled')
                                        const PopupMenuItem(
                                            value: 'completed',
                                            child: Text('Hoàn thành')),
                                      if (status != 'cancelled')
                                        const PopupMenuItem(
                                            value: 'cancelled',
                                            child: Text('Hủy')),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  void _addReservationDialog() {
    final db = ref.read(localDatabaseProvider);
    final guestsC = TextEditingController(text: '2');
    final startC = TextEditingController(text: '10:00');
    final endC = TextEditingController(text: '12:00');
    final notesC = TextEditingController();
    int? selectedCustomerId;
    int? selectedTableId;
    List<Map<String, dynamic>> customers = [];
    List<Map<String, dynamic>> tables = [];

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          // Load customers and tables once
          if (customers.isEmpty) {
            db.queryAll('customers', orderBy: 'name ASC').then((c) {
              setDialogState(() => customers = c);
            });
          }
          if (tables.isEmpty) {
            db.queryWhere('layout_objects', where: "type = 'table'", whereArgs: []).then((t) {
              setDialogState(() => tables = t);
            });
          }

          return AlertDialog(
            title: const Text('Đặt bàn mới'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: selectedCustomerId,
                    decoration: const InputDecoration(labelText: 'Khách hàng'),
                    items: customers
                        .map((c) => DropdownMenuItem<int>(
                            value: c['id'] as int,
                            child: Text(c['name'] as String? ?? '')))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedCustomerId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: selectedTableId,
                    decoration: const InputDecoration(labelText: 'Bàn'),
                    items: tables
                        .map((t) => DropdownMenuItem<int>(
                            value: t['id'] as int,
                            child: Text(t['name'] as String? ?? '')))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedTableId = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                      controller: guestsC,
                      decoration:
                          const InputDecoration(labelText: 'Số khách'),
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  TextField(
                      controller: startC,
                      decoration: const InputDecoration(
                          labelText: 'Giờ bắt đầu (HH:mm)')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: endC,
                      decoration: const InputDecoration(
                          labelText: 'Giờ kết thúc (HH:mm)')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: notesC,
                      decoration:
                          const InputDecoration(labelText: 'Ghi chú'),
                      maxLines: 2),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Hủy')),
              ElevatedButton(
                onPressed: () async {
                  if (selectedCustomerId == null || selectedTableId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Vui lòng chọn khách hàng và bàn')));
                    return;
                  }
                  final ok = await ref
                      .read(reservationProvider.notifier)
                      .create({
                    'customer_id': selectedCustomerId,
                    'table_id': selectedTableId,
                    'reservation_date': _dateStr,
                    'start_time': startC.text,
                    'end_time': endC.text,
                    'guests_count': int.tryParse(guestsC.text) ?? 2,
                    'notes':
                        notesC.text.isNotEmpty ? notesC.text : null,
                  });
                  if (dialogCtx.mounted) {
                    Navigator.pop(dialogCtx);
                    if (ok) {
                      _loadReservations();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                              ref.read(reservationProvider).error ?? 'Lỗi')));
                    }
                  }
                },
                child: const Text('Đặt bàn'),
              ),
            ],
          );
        },
      ),
    );
  }
}
