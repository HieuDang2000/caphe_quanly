import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/invoice_provider.dart';
import '../../widgets/loading_widget.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final int invoiceId;
  const PaymentScreen({super.key, required this.invoiceId});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  String _method = 'cash';

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(invoiceProvider.notifier).loadInvoice(widget.invoiceId);
      final invoice = ref.read(invoiceProvider).invoice;
      if (invoice != null) {
        final remaining = (invoice['total'] as num) - _paidAmount(invoice);
        _amountController.text = remaining.toStringAsFixed(0);
      }
    });
  }

  double _paidAmount(Map<String, dynamic> invoice) {
    final payments = List<Map<String, dynamic>>.from(invoice['payments'] ?? []);
    return payments.fold(0.0, (sum, p) => sum + (p['amount'] as num));
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Số tiền không hợp lệ')));
      return;
    }
    final success = await ref.read(invoiceProvider.notifier).addPayment(
      widget.invoiceId,
      amount: amount,
      method: _method,
      reference: _referenceController.text.isNotEmpty ? _referenceController.text : null,
    );
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanh toán thành công!')));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoiceState = ref.watch(invoiceProvider);
    final invoice = invoiceState.invoice;

    return Scaffold(
      appBar: AppBar(title: const Text('Thanh toán')),
      body: invoiceState.isLoading
          ? const LoadingWidget()
          : invoice == null
              ? const Center(child: Text('Không tìm thấy hóa đơn'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        color: AppTheme.primaryColor,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              const Text('Tổng cần thanh toán', style: TextStyle(color: Colors.white70, fontSize: 14)),
                              const SizedBox(height: 8),
                              Text(Formatters.currency(invoice['total'] ?? 0), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                              if (_paidAmount(invoice) > 0) ...[
                                const SizedBox(height: 4),
                                Text('Đã thanh toán: ${Formatters.currency(_paidAmount(invoice))}', style: const TextStyle(color: Colors.white70)),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text('Phương thức thanh toán', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _MethodChip(label: 'Tiền mặt', icon: Icons.money, value: 'cash', selected: _method, onTap: (v) => setState(() => _method = v)),
                          const SizedBox(width: 8),
                          _MethodChip(label: 'Thẻ', icon: Icons.credit_card, value: 'card', selected: _method, onTap: (v) => setState(() => _method = v)),
                          const SizedBox(width: 8),
                          _MethodChip(label: 'CK', icon: Icons.account_balance, value: 'transfer', selected: _method, onTap: (v) => setState(() => _method = v)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _amountController,
                        decoration: const InputDecoration(labelText: 'Số tiền', prefixText: '₫ '),
                        keyboardType: TextInputType.number,
                      ),
                      if (_method != 'cash') ...[
                        const SizedBox(height: 16),
                        TextFormField(controller: _referenceController, decoration: const InputDecoration(labelText: 'Mã tham chiếu')),
                      ],
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _pay,
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                        child: const Text('Xác nhận thanh toán', style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final String selected;
  final ValueChanged<String> onTap;

  const _MethodChip({required this.label, required this.icon, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.grey),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontWeight: FontWeight.w600, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
