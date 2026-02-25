import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'pdf_saver.dart';

class ReceiptPrinter {
  static Future<void> print80mm({
    required Map<String, dynamic> invoice,
  }) async {
    final bytes = await _build80mmPdfBytes(invoice: invoice);

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
    );
  }

  static Future<void> share80mm({
    required Map<String, dynamic> invoice,
  }) async {
    final bytes = await _build80mmPdfBytes(invoice: invoice);
    await sharePdfBytes(bytes, filename: 'hoa-don-${invoice['invoice_number'] ?? ''}-80mm.pdf');
  }

  /// Lưu hoá đơn A4 về máy qua dialog Save As.
  /// Trả về `true` nếu lưu thành công.
  static Future<bool> saveA4ToFile({
    required Map<String, dynamic> invoice,
  }) async {
    final bytes = await _buildA4PdfBytes(invoice: invoice);
    return _saveBytesToFile(
      bytes: bytes,
      suggestedName: 'hoa-don-${invoice['invoice_number'] ?? ''}.pdf',
    );
  }

  /// Lưu hoá đơn 80mm về máy qua dialog Save As.
  static Future<bool> save80mmToFile({
    required Map<String, dynamic> invoice,
  }) async {
    final bytes = await _build80mmPdfBytes(invoice: invoice);
    return _saveBytesToFile(
      bytes: bytes,
      suggestedName: 'hoa-don-${invoice['invoice_number'] ?? ''}-80mm.pdf',
    );
  }

  static Future<bool> _saveBytesToFile({
    required Uint8List bytes,
    required String suggestedName,
  }) async {
    if (kIsWeb) {
      await Printing.sharePdf(bytes: bytes, filename: suggestedName);
      return true;
    }
    return savePdfNative(bytes: bytes, suggestedName: suggestedName);
  }

  // ──────────────────── A4 PDF ────────────────────

  static Future<Uint8List> _buildA4PdfBytes({
    required Map<String, dynamic> invoice,
  }) async {
    final font = await PdfGoogleFonts.beVietnamProRegular();
    final fontBold = await PdfGoogleFonts.beVietnamProBold();
    final base = pw.TextStyle(font: font, fontSize: 11);
    final bold = pw.TextStyle(font: fontBold, fontSize: 11, fontWeight: pw.FontWeight.bold);

    final doc = pw.Document();
    final order = Map<String, dynamic>.from(invoice['order'] ?? {});
    final items = List<Map<String, dynamic>>.from(order['items'] ?? []);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Text('HIÊN', style: bold.copyWith(fontSize: 22)),
                    pw.SizedBox(height: 2),
                    pw.Text('Ngọc Thạnh 2, Phước An, Gia Lai', style: base),
                    pw.Text('ĐT: 034-226-3291', style: base),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text('HÓA ĐƠN THANH TOÁN', style: bold.copyWith(fontSize: 14)),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Số HĐ: ${invoice['invoice_number'] ?? ''}', style: bold),
                      pw.Text('Đơn hàng: ${order['order_number'] ?? ''}', style: base),
                      if (order['table'] != null)
                        pw.Text('Bàn: ${order['table']['name']}', style: base),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      if (order['user'] != null)
                        pw.Text('Nhân viên: ${order['user']['name']}', style: base),
                      if (invoice['created_at'] != null)
                        pw.Text('Ngày: ${_formatDate(invoice['created_at'])}', style: base),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),
                  1: const pw.FlexColumnWidth(4),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(2),
                  4: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _cell('STT', bold, center: true),
                      _cell('Tên món', bold),
                      _cell('SL', bold, center: true),
                      _cell('Đơn giá', bold, right: true),
                      _cell('Thành tiền', bold, right: true),
                    ],
                  ),
                  ...items.asMap().entries.map((e) {
                    final i = e.key;
                    final item = e.value;
                    final qty = _toNum(item['quantity']);
                    final subtotal = _toNum(item['subtotal']);
                    final unitPrice = qty > 0 ? subtotal / qty : 0.0;
                    final isPaid = item['is_paid'] == true;
                    final rowStyle = isPaid
                        ? base.copyWith(decoration: pw.TextDecoration.lineThrough, color: PdfColors.grey600)
                        : base;
                    return pw.TableRow(children: [
                      _cell('${i + 1}', rowStyle, center: true),
                      _cell(item['menu_item']?['name']?.toString() ?? '', rowStyle),
                      _cell('${qty.toInt()}', rowStyle, center: true),
                      _cell(_formatCurrency(unitPrice), rowStyle, right: true),
                      _cell(_formatCurrency(subtotal), rowStyle, right: true),
                    ]);
                  }),
                ],
              ),
              pw.SizedBox(height: 12),
              () {
                // Tính lại tổng dựa trên các item chưa is_paid
                final allSubtotal = items.fold<double>(
                  0,
                  (sum, item) => sum + _toNum(item['subtotal']),
                );
                final unpaidItems =
                    items.where((item) => item['is_paid'] != true);
                final unpaidSubtotal = unpaidItems.fold<double>(
                  0,
                  (sum, item) => sum + _toNum(item['subtotal']),
                );
                final rawDiscount = _toNum(invoice['discount_amount']);
                double effectiveDiscount = 0;
                if (allSubtotal > 0 &&
                    rawDiscount > 0 &&
                    unpaidSubtotal > 0) {
                  effectiveDiscount =
                      rawDiscount * (unpaidSubtotal / allSubtotal);
                }
                final displaySubtotal = unpaidSubtotal;
                final displayTotal = displaySubtotal - effectiveDiscount;

                return pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      _summaryRow(
                        'Tạm tính',
                        _formatCurrency(displaySubtotal),
                        base,
                      ),
                      if (effectiveDiscount > 0)
                        _summaryRow(
                          'Giảm giá',
                          '-${_formatCurrency(effectiveDiscount)}',
                          base,
                        ),
                      pw.Divider(),
                      _summaryRow(
                        'Tổng cộng',
                        _formatCurrency(displayTotal),
                        bold.copyWith(fontSize: 14),
                      ),
                    ],
                  ),
                );
              }(),
              pw.SizedBox(height: 30),
              pw.Center(
                child: pw.Text('Cảm ơn quý khách! Hẹn gặp lại!', style: base),
              ),
            ],
          );
        },
      ),
    );

    final data = await doc.save();
    return Uint8List.fromList(data);
  }

  static pw.Widget _cell(String text, pw.TextStyle style, {bool center = false, bool right = false}) {
    final align = right
        ? pw.Alignment.centerRight
        : center
            ? pw.Alignment.center
            : pw.Alignment.centerLeft;
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      alignment: align,
      child: pw.Text(text, style: style),
    );
  }

  static pw.Widget _summaryRow(String label, String value, pw.TextStyle style) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text('$label:  ', style: style),
          pw.Text(value, style: style),
        ],
      ),
    );
  }

  static String _formatDate(dynamic value) {
    if (value == null) return '';
    try {
      final dt = DateTime.parse(value.toString());
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return value.toString();
    }
  }

  static Future<Uint8List> _build80mmPdfBytes({
    required Map<String, dynamic> invoice,
  }) async {
    final font = await PdfGoogleFonts.beVietnamProRegular();
    final fontBold = await PdfGoogleFonts.beVietnamProBold();
    final baseStyle = pw.TextStyle(font: font, fontSize: 10);
    final boldStyle = pw.TextStyle(font: fontBold, fontSize: 10, fontWeight: pw.FontWeight.bold);

    final doc = pw.Document();

    final order = Map<String, dynamic>.from(invoice['order'] ?? {});
    final items = List<Map<String, dynamic>>.from(order['items'] ?? []);

    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(130.0, double.infinity, marginAll: 5),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Text('HIÊN', style: boldStyle.copyWith(fontSize: 13)),
                    pw.SizedBox(height: 2),
                    pw.Text('Ngọc Thạnh 2, Phước An, Gia Lai', style: baseStyle.copyWith(fontSize: 7)),
                    pw.Text('ĐT: 034-226-3291', style: baseStyle.copyWith(fontSize: 7)),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text('HÓA ĐƠN THANH TOÁN', style: baseStyle.copyWith(fontSize: 8)),
              ),
              pw.SizedBox(height: 6),
              pw.Text('ĐH: ${order['order_number'] ?? ''}', style: baseStyle.copyWith(fontSize: 6)),
              if (order['table'] != null)
                pw.Text('Bàn: ${order['table']['name']}', style: baseStyle.copyWith(fontSize: 6)),
              pw.Divider(),
              pw.Table(
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    children: [
                      pw.Text('Món', style: boldStyle.copyWith(fontSize: 5)),
                      pw.Align(
                        alignment: pw.Alignment.center,
                        child: pw.Text('SL', style: boldStyle.copyWith(fontSize: 6)),
                      ),
                      pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text('Tiền', style: boldStyle.copyWith(fontSize: 6)),
                      ),
                    ],
                  ),
                  ...items.map(
                    (item) {
                      final isPaid = item['is_paid'] == true;
                      final lineStyle = isPaid
                          ? baseStyle.copyWith(fontSize: 7, decoration: pw.TextDecoration.lineThrough, color: PdfColors.grey600)
                          : baseStyle.copyWith(fontSize: 7);
                      return pw.TableRow(
                        children: [
                          pw.Text(
                            item['menu_item']?['name']?.toString() ?? '',
                            style: lineStyle,
                          ),
                          pw.Align(
                            alignment: pw.Alignment.center,
                            child: pw.Text('${item['quantity']}', style: lineStyle),
                          ),
                          pw.Align(
                            alignment: pw.Alignment.centerRight,
                            child: pw.Text(
                              _formatCurrency(item['subtotal']),
                              style: lineStyle,
                            ),
                          ),
                          pw.Divider(thickness: 0.5, height: 0.5),
                        ],
                      );
                    },
                  ),
                ],
              ),
              pw.Divider(),
              () {
                // Tính lại tổng dựa trên các item chưa is_paid
                final allSubtotal = items.fold<double>(
                  0,
                  (sum, item) => sum + _toNum(item['subtotal']),
                );
                final unpaidItems =
                    items.where((item) => item['is_paid'] != true);
                final unpaidSubtotal = unpaidItems.fold<double>(
                  0,
                  (sum, item) => sum + _toNum(item['subtotal']),
                );
                final rawDiscount = _toNum(invoice['discount_amount']);
                double effectiveDiscount = 0;
                if (allSubtotal > 0 &&
                    rawDiscount > 0 &&
                    unpaidSubtotal > 0) {
                  effectiveDiscount =
                      rawDiscount * (unpaidSubtotal / allSubtotal);
                }
                final displaySubtotal = unpaidSubtotal;
                final displayTotal = displaySubtotal - effectiveDiscount;

                return pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Tạm tính: ${_formatCurrency(displaySubtotal)}',
                        style: baseStyle.copyWith(fontSize: 8),
                      ),
                      if (effectiveDiscount > 0)
                        pw.Text(
                          'Giảm giá: -${_formatCurrency(effectiveDiscount)}',
                          style: baseStyle.copyWith(fontSize: 8),
                        ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Tổng cộng: ${_formatCurrency(displayTotal)}',
                        style: boldStyle.copyWith(fontSize: 9),
                      ),
                    ],
                  ),
                );
              }(),
              pw.Divider(),
              pw.Center(
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Text(
                      'Trà sữa Hiên',
                      style: boldStyle.copyWith(fontSize: 8),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Cảm ơn quý khách! Hẹn gặp lại!',
                      style: baseStyle.copyWith(fontSize: 7),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    final data = await doc.save();
    return Uint8List.fromList(data);
  }

  static String _formatCurrency(dynamic value) {
    final numVal = _toNum(value);
    return '${numVal.toStringAsFixed(0)}đ';
  }

  static double _toNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static Future<void> sharePdfBytes(Uint8List bytes, {String? filename}) async {
    await Printing.sharePdf(bytes: bytes, filename: filename ?? 'hoa-don.pdf');
  }
}

