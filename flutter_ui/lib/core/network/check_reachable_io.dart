import 'dart:io';

import '../../config/api_config.dart';

Future<bool> checkReachable() async {
  try {
    final uri = Uri.parse(ApiConfig.baseUrl);
    final result = await InternetAddress.lookup(uri.host)
        .timeout(const Duration(seconds: 5));
    return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
  } catch (_) {
    return false;
  }
}
