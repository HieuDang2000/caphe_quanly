import 'dart:async';

import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../repositories/printer_repository.dart';
import 'receipt_printer.dart';

class PrintService {
  /// In hoá đơn 80mm trực tiếp tới máy in hệ thống đã cấu hình.
  ///
  /// - [config]: cấu hình máy in đã lưu (tên/id, khổ giấy, loại, ...).
  /// - [invoice]: dữ liệu hoá đơn (format giống đang dùng cho `ReceiptPrinter.print80mm`).
  static Future<void> printReceipt80mmToSystemPrinter({
    required PrinterConfig config,
    required Map<String, dynamic> invoice,
  }) async {
    try {
      // Tìm lại đối tượng Printer tương ứng trong danh sách máy in hiện có.
      final printers = await Printing.listPrinters();
      Printer? target;

      for (final p in printers) {
        if (p.url == config.id) {
          target = p;
          break;
        }
      }
      target ??= printers.firstWhere(
        (p) => p.name == config.name,
        orElse: () => throw Exception('Không tìm thấy máy in đã cấu hình: ${config.name}'),
      );

      final bytes = await ReceiptPrinter.build80mmPdfBytes(invoice: invoice);

      await Printing.directPrintPdf(
        printer: target,
        onLayout: (PdfPageFormat format) async => bytes,
      );
    } catch (e) {
      // Đẩy lỗi lên cho tầng UI hiển thị SnackBar/Toast phù hợp.
      throw Exception('In hoá đơn thất bại: $e');
    }
  }
}

