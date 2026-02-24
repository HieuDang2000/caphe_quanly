import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException({required this.message, this.statusCode, this.data});

  factory ApiException.fromDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(message: 'Kết nối timeout, vui lòng thử lại', statusCode: 408);
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final data = e.response?.data;
        String message = 'Có lỗi xảy ra';
        if (data is Map<String, dynamic>) {
          message = data['message'] ?? message;
        }
        return ApiException(message: message, statusCode: statusCode, data: data);
      case DioExceptionType.cancel:
        return ApiException(message: 'Yêu cầu đã bị hủy');
      default:
        return ApiException(message: 'Không thể kết nối server');
    }
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
