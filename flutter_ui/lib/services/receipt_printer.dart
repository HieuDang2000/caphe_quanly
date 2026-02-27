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
        pageFormat: const PdfPageFormat(135.0, double.infinity, marginAll: 5),
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
                      final lineStyle = baseStyle.copyWith(fontSize: 7);
                      final name = item['menu_item']?['name']?.toString() ?? '';
                      final displayName = isPaid ? 'X $name' : name;
                      final subtotal = _toNum(item['subtotal']);
                      return pw.TableRow(
                        children: [
                          pw.Text(
                            displayName,
                            style: lineStyle,
                          ),
                          pw.Align(
                            alignment: pw.Alignment.center,
                            child: pw.Text('${item['quantity']}', style: lineStyle),
                          ),
                          pw.Align(
                            alignment: pw.Alignment.centerRight,
                            child: pw.Text(
                              _formatCurrency(subtotal),
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
                final hasPaidItems =
                    items.any((item) => item['is_paid'] == true);

                return pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      if (hasPaidItems)
                        pw.Text(
                          'Đã thanh toán: ${_formatCurrency(allSubtotal - unpaidSubtotal)}',
                          style: baseStyle.copyWith(fontSize: 8),
                        ),
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
    final numVal = _toNum(value).round();
    final str = numVal.toString();
    final chars = str.split('').reversed.toList();
    final withCommas = <String>[];
    for (var i = 0; i < chars.length; i++) {
      withCommas.add(chars[i]);
      if ((i + 1) % 3 == 0 && i + 1 != chars.length) {
        withCommas.add(',');
      }
    }
    final formatted = withCommas.reversed.join();
    return '$formatted đ';
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

