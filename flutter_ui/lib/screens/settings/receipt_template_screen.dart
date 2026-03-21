import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../providers/receipt_template_provider.dart';
import '../../repositories/receipt_template_repository.dart';

class ReceiptTemplateScreen extends ConsumerStatefulWidget {
  const ReceiptTemplateScreen({super.key});

  @override
  ConsumerState<ReceiptTemplateScreen> createState() => _ReceiptTemplateScreenState();
}

class _ReceiptTemplateScreenState extends ConsumerState<ReceiptTemplateScreen> {
  final _shopNameCtrl = TextEditingController();
  final _shopAddressCtrl = TextEditingController();
  final _shopPhoneCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _footer1Ctrl = TextEditingController();
  final _footer2Ctrl = TextEditingController();

  String? _lastHydratedFingerprint;
  bool _isDirty = false;

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _shopAddressCtrl.dispose();
    _shopPhoneCtrl.dispose();
    _titleCtrl.dispose();
    _footer1Ctrl.dispose();
    _footer2Ctrl.dispose();
    super.dispose();
  }

  String _fingerprint(ReceiptTemplate tpl) {
    // Stable enough for detecting external updates from provider/db.
    return tpl.toJson().toString();
  }

  void _hydrateFromTemplate(ReceiptTemplate tpl) {
    _shopNameCtrl.text = tpl.shopName;
    _shopAddressCtrl.text = tpl.shopAddress;
    _shopPhoneCtrl.text = tpl.shopPhone;
    _titleCtrl.text = tpl.receiptTitle;
    _footer1Ctrl.text = tpl.footerLine1;
    _footer2Ctrl.text = tpl.footerLine2;
    _lastHydratedFingerprint = _fingerprint(tpl);
  }

  ReceiptTemplate _readForm() {
    return ReceiptTemplate(
      shopName: _shopNameCtrl.text.trim(),
      shopAddress: _shopAddressCtrl.text.trim(),
      shopPhone: _shopPhoneCtrl.text.trim(),
      receiptTitle: _titleCtrl.text.trim(),
      footerLine1: _footer1Ctrl.text.trim(),
      footerLine2: _footer2Ctrl.text.trim(),
    );
  }

  Future<void> _save() async {
    final notifier = ref.read(receiptTemplateProvider.notifier);
    notifier.updateTemplate(_readForm());
    try {
      await notifier.save();
      _isDirty = false;
      _lastHydratedFingerprint = _fingerprint(ref.read(receiptTemplateProvider).template);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu nội dung in.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lưu thất bại: $e')),
      );
    }
  }

  Future<void> _reset() async {
    final notifier = ref.read(receiptTemplateProvider.notifier);
    try {
      await notifier.resetToDefaults();
      final tpl = ref.read(receiptTemplateProvider).template;
      _isDirty = false;
      _hydrateFromTemplate(tpl);
      setState(() {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã khôi phục mặc định.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Khôi phục thất bại: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(receiptTemplateProvider);
    final fp = _fingerprint(state.template);
    final needsHydrate = _lastHydratedFingerprint != fp;
    if (needsHydrate && !_isDirty) {
      _hydrateFromTemplate(state.template);
    } else if (_lastHydratedFingerprint == null) {
      _hydrateFromTemplate(state.template);
    }

    final preview = _readForm();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý nội dung in'),
        actions: [
          TextButton.icon(
            onPressed: state.isLoading ? null : _reset,
            icon: const Icon(Icons.restart_alt),
            label: const Text('Mặc định'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: state.isLoading ? null : _save,
            icon: const Icon(Icons.save),
            label: const Text('Lưu'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;
            final form = _FormCard(
              shopNameCtrl: _shopNameCtrl,
              shopAddressCtrl: _shopAddressCtrl,
              shopPhoneCtrl: _shopPhoneCtrl,
              titleCtrl: _titleCtrl,
              footer1Ctrl: _footer1Ctrl,
              footer2Ctrl: _footer2Ctrl,
              isLoading: state.isLoading,
              onChanged: () {
                _isDirty = true;
                setState(() {});
              },
            );

            final previewCard = _PreviewCard(template: preview);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: form),
                            const SizedBox(width: 16),
                            SizedBox(width: 380, child: previewCard),
                          ],
                        )
                      : Column(
                          children: [
                            form,
                            const SizedBox(height: 16),
                            previewCard,
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.shopNameCtrl,
    required this.shopAddressCtrl,
    required this.shopPhoneCtrl,
    required this.titleCtrl,
    required this.footer1Ctrl,
    required this.footer2Ctrl,
    required this.isLoading,
    required this.onChanged,
  });

  final TextEditingController shopNameCtrl;
  final TextEditingController shopAddressCtrl;
  final TextEditingController shopPhoneCtrl;
  final TextEditingController titleCtrl;
  final TextEditingController footer1Ctrl;
  final TextEditingController footer2Ctrl;
  final bool isLoading;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Thông tin hiển thị trên hoá đơn', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _Field(
              controller: shopNameCtrl,
              label: 'Tên quán',
              icon: Icons.storefront,
              enabled: !isLoading,
              onChanged: (_) => onChanged(),
            ),
            const SizedBox(height: 10),
            _Field(
              controller: shopAddressCtrl,
              label: 'Địa chỉ',
              icon: Icons.location_on,
              enabled: !isLoading,
              onChanged: (_) => onChanged(),
            ),
            const SizedBox(height: 10),
            _Field(
              controller: shopPhoneCtrl,
              label: 'Điện thoại',
              icon: Icons.phone,
              enabled: !isLoading,
              onChanged: (_) => onChanged(),
            ),
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 14),
            _Field(
              controller: titleCtrl,
              label: 'Tiêu đề hoá đơn',
              icon: Icons.receipt_long,
              enabled: !isLoading,
              onChanged: (_) => onChanged(),
            ),
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 14),
            _Field(
              controller: footer1Ctrl,
              label: 'Chân trang (dòng 1)',
              icon: Icons.favorite,
              enabled: !isLoading,
              onChanged: (_) => onChanged(),
            ),
            const SizedBox(height: 10),
            _Field(
              controller: footer2Ctrl,
              label: 'Chân trang (dòng 2)',
              icon: Icons.celebration,
              enabled: !isLoading,
              onChanged: (_) => onChanged(),
            ),
            if (isLoading) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 10),
                  Text('Đang xử lý...', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.template});

  final ReceiptTemplate template;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Xem trước', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
              ),
              padding: const EdgeInsets.all(16),
              child: DefaultTextStyle(
                style: theme.textTheme.bodySmall ?? const TextStyle(),
                child: Column(
                  children: [
                    Text(template.shopName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(template.shopAddress, textAlign: TextAlign.center),
                    Text('ĐT: ${template.shopPhone}', textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    Text(
                      template.receiptTitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Divider(color: theme.dividerColor.withValues(alpha: 0.6)),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('... (danh sách món) ...', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                    ),
                    const SizedBox(height: 10),
                    Divider(color: theme.dividerColor.withValues(alpha: 0.6)),
                    const SizedBox(height: 10),
                    Text(template.footerLine1, textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(template.footerLine2, textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

