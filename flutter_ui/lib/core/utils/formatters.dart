import 'package:intl/intl.dart';

/// Múi giờ Việt Nam (UTC+7).
const int _vietnamUtcOffsetHours = 7;

class Formatters {
  static final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
  static final _dateFormat = DateFormat('dd/MM/yyyy');
  static final _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
  static final _timeFormat = DateFormat('HH:mm');
  static final _shortDateTimeFormat = DateFormat('dd/MM HH:mm');

  /// Chuyển [DateTime] (UTC hoặc local) sang giờ hiển thị UTC+7 (Việt Nam),
  /// trả về DateTime với cùng year/month/day/hour/minute/second để format không bị lệch thêm.
  static DateTime toVietnamTime(DateTime dt) {
    final utc = dt.toUtc();
    final vn = utc.add(const Duration(hours: _vietnamUtcOffsetHours));
    return DateTime(vn.year, vn.month, vn.day, vn.hour, vn.minute, vn.second);
  }

  /// Chuyển giá từ API (có thể là int, double hoặc String) sang num để tránh lỗi type.
  static num toNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    if (value is String) return num.tryParse(value) ?? 0;
    return 0;
  }

  static String currency(dynamic amount) => _currencyFormat.format(toNum(amount));
  static String date(DateTime dt) => _dateFormat.format(toVietnamTime(dt));
  static String dateTime(DateTime dt) => _dateTimeFormat.format(toVietnamTime(dt));
  static String time(DateTime dt) => _timeFormat.format(toVietnamTime(dt));
  static String shortDateTime(DateTime dt) => _shortDateTimeFormat.format(toVietnamTime(dt));

  static String orderStatus(String status) {
    switch (status) {
      case 'pending':
        return 'Đang chờ';
      case 'paid':
        return 'Đã thanh toán';
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
