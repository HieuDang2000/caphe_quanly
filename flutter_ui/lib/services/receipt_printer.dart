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
                child: pw.Text('COFFEE SHOP', style: bold.copyWith(fontSize: 22)),
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
                    return pw.TableRow(children: [
                      _cell('${i + 1}', base, center: true),
                      _cell(item['menu_item']?['name']?.toString() ?? '', base),
                      _cell('${qty.toInt()}', base, center: true),
                      _cell(_formatCurrency(unitPrice), base, right: true),
                      _cell(_formatCurrency(subtotal), base, right: true),
                    ]);
                  }),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    _summaryRow('Tạm tính', _formatCurrency(invoice['subtotal']), base),
                    if (_toNum(invoice['discount_amount']) > 0)
                      _summaryRow('Giảm giá', '-${_formatCurrency(invoice['discount_amount'])}', base),
                    pw.Divider(),
                    _summaryRow('Tổng cộng', _formatCurrency(invoice['total']), bold.copyWith(fontSize: 14)),
                  ],
                ),
              ),
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
        pageFormat: const PdfPageFormat(226.0, double.infinity, marginAll: 5),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'COFFEE SHOP',
                  style: boldStyle.copyWith(fontSize: 16),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text('HÓA ĐƠN THANH TOÁN', style: baseStyle),
              ),
              pw.SizedBox(height: 6),
              pw.Text('HĐ: ${invoice['invoice_number'] ?? ''}', style: baseStyle),
              pw.Text('ĐH: ${order['order_number'] ?? ''}', style: baseStyle),
              if (order['table'] != null)
                pw.Text('Bàn: ${order['table']['name']}', style: baseStyle),
              if (order['user'] != null)
                pw.Text('NV: ${order['user']['name']}', style: baseStyle),
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
                      pw.Text('Món', style: boldStyle.copyWith(fontSize: 9)),
                      pw.Align(
                        alignment: pw.Alignment.center,
                        child: pw.Text('SL', style: boldStyle.copyWith(fontSize: 9)),
                      ),
                      pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text('Tiền', style: boldStyle.copyWith(fontSize: 9)),
                      ),
                    ],
                  ),
                  ...items.map(
                    (item) => pw.TableRow(
                      children: [
                        pw.Text(
                          item['menu_item']?['name']?.toString() ?? '',
                          style: baseStyle.copyWith(fontSize: 9),
                        ),
                        pw.Align(
                          alignment: pw.Alignment.center,
                          child: pw.Text('${item['quantity']}', style: baseStyle.copyWith(fontSize: 9)),
                        ),
                        pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: pw.Text(
                            _formatCurrency(item['subtotal']),
                            style: baseStyle.copyWith(fontSize: 9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Divider(),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Tạm tính: ${_formatCurrency(invoice['subtotal'])}', style: baseStyle),
                    if ((invoice['discount_amount'] ?? 0) != 0)
                      pw.Text(
                        'Giảm giá: -${_formatCurrency(invoice['discount_amount'])}',
                        style: baseStyle,
                      ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Tổng cộng: ${_formatCurrency(invoice['total'])}',
                      style: boldStyle.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              pw.Divider(),
              pw.Center(
                child: pw.Text(
                  'Cảm ơn quý khách! Hẹn gặp lại!',
                  style: baseStyle.copyWith(fontSize: 9),
                  textAlign: pw.TextAlign.center,
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

