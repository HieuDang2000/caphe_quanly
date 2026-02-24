import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/invoice_provider.dart';
import '../../widgets/loading_widget.dart';

class InvoiceScreen extends ConsumerStatefulWidget {
  final int orderId;
  const InvoiceScreen({super.key, required this.orderId});

  @override
  ConsumerState<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends ConsumerState<InvoiceScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(invoiceProvider.notifier).generateInvoice(widget.orderId));
  }

  @override
  Widget build(BuildContext context) {
    final invoiceState = ref.watch(invoiceProvider);
    final invoice = invoiceState.invoice;

    return Scaffold(
      appBar: AppBar(title: const Text('Hóa đơn')),
      body: invoiceState.isLoading
          ? const LoadingWidget()
          : invoice == null
              ? const Center(child: Text('Không thể tạo hóa đơn'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(invoice['invoice_number'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  _statusBadge(invoice['payment_status'] ?? 'unpaid'),
                                ],
                              ),
                              const Divider(),
                              if (invoice['order'] != null) ...[
                                Text('Đơn: ${invoice['order']['order_number']}'),
                                if (invoice['order']['table'] != null) Text('Bàn: ${invoice['order']['table']['name']}'),
                                if (invoice['order']['user'] != null) Text('NV: ${invoice['order']['user']['name']}'),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Chi tiết', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const Divider(),
                              if (invoice['order']?['items'] != null)
                                ...List<Map<String, dynamic>>.from(invoice['order']['items']).map((item) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Expanded(child: Text(item['menu_item']?['name'] ?? '')),
                                      Text('x${item['quantity']}'),
                                      const SizedBox(width: 16),
                                      Text(Formatters.currency(item['subtotal'] ?? 0)),
                                    ],
                                  ),
                                )),
                              const Divider(),
                              _totalRow('Tạm tính', invoice['subtotal'] ?? 0),
                              _totalRow('VAT (${invoice['tax_rate']}%)', invoice['tax_amount'] ?? 0),
                              if ((invoice['discount_amount'] ?? 0) > 0)
                                _totalRow('Giảm giá', -(invoice['discount_amount'] ?? 0)),
                              const Divider(),
                              _totalRow('Tổng cộng', invoice['total'] ?? 0, isBold: true),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (invoice['payment_status'] != 'paid')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => context.push('/payment/${invoice['id']}'),
                            icon: const Icon(Icons.payment),
                            label: const Text('Thanh toán'),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _totalRow(String label, num amount, {bool isBold = false}) {
    final style = TextStyle(
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      fontSize: isBold ? 18 : 14,
      color: isBold ? AppTheme.primaryColor : null,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(Formatters.currency(amount), style: style)],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final color = status == 'paid' ? AppTheme.successColor : status == 'partial' ? AppTheme.warningColor : AppTheme.errorColor;
    final text = status == 'paid' ? 'Đã thanh toán' : status == 'partial' ? 'Thanh toán một phần' : 'Chưa thanh toán';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}
