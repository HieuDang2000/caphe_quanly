import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'check_reachable_io.dart' if (dart.library.html) 'check_reachable_web.dart' as reachability;

/// Emits `true` when a usable network connection is available, `false` otherwise.
/// Khi có connectivity (không phải none): emit true ngay để UI hiển thị online,
/// sau đó chạy kiểm tra reachability và emit kết quả thực.
final connectivityStreamProvider = StreamProvider<bool>((ref) {
  final controller = StreamController<bool>();

  void onConnectivityChange(List<ConnectivityResult> results) async {
    if (results.contains(ConnectivityResult.none)) {
      controller.add(false);
      return;
    }
    // Có kết nối: hiển thị online ngay, tránh hiển thị offline trong lúc chờ check.
    controller.add(true);
    final reachable = await reachability.checkReachable();
    controller.add(reachable);
  }

  final subscription =
      Connectivity().onConnectivityChanged.listen(onConnectivityChange);

  // Initial check
  () async {
    final results = await Connectivity().checkConnectivity();
    onConnectivityChange(results);
  }();

  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Giá trị online/offline hiện tại; mặc định true (online) khi chưa có dữ liệu.
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityStreamProvider).whenData((v) => v).value ?? true;
});
