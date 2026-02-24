class Validators {
  static String? required(String? value, [String field = 'Trường này']) {
    if (value == null || value.trim().isEmpty) return '$field không được để trống';
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email không được để trống';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) return 'Email không hợp lệ';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Mật khẩu không được để trống';
    if (value.length < 4) return 'Mật khẩu phải có ít nhất 4 ký tự';
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final phoneRegex = RegExp(r'^0\d{9}$');
    if (!phoneRegex.hasMatch(value)) return 'Số điện thoại không hợp lệ';
    return null;
  }

  static String? number(String? value, [String field = 'Giá trị']) {
    if (value == null || value.trim().isEmpty) return '$field không được để trống';
    if (double.tryParse(value) == null) return '$field phải là số';
    return null;
  }

  static String? positiveNumber(String? value, [String field = 'Giá trị']) {
    final numError = number(value, field);
    if (numError != null) return numError;
    if (double.parse(value!) <= 0) return '$field phải lớn hơn 0';
    return null;
  }
}
