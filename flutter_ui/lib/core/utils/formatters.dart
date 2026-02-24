import 'package:intl/intl.dart';

class Formatters {
  static final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
  static final _dateFormat = DateFormat('dd/MM/yyyy');
  static final _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
  static final _timeFormat = DateFormat('HH:mm');
  static final _shortDateTimeFormat = DateFormat('dd/MM HH:mm');

  /// Chuyển giá từ API (có thể là int, double hoặc String) sang num để tránh lỗi type.
  static num toNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    if (value is String) return num.tryParse(value) ?? 0;
    return 0;
  }

  static String currency(dynamic amount) => _currencyFormat.format(toNum(amount));
  static String date(DateTime dt) => _dateFormat.format(dt);
  static String dateTime(DateTime dt) => _dateTimeFormat.format(dt);
  static String time(DateTime dt) => _timeFormat.format(dt);
  static String shortDateTime(DateTime dt) => _shortDateTimeFormat.format(dt);

  static String orderStatus(String status) {
    switch (status) {
      case 'pending':
        return 'Chờ xử lý';
      case 'in_progress':
        return 'Đang pha chế';
      case 'completed':
        return 'Hoàn thành';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return status;
    }
  }

  static String paymentMethod(String method) {
    switch (method) {
      case 'cash':
        return 'Tiền mặt';
      case 'card':
        return 'Thẻ';
      case 'transfer':
        return 'Chuyển khoản';
      default:
        return method;
    }
  }
}
