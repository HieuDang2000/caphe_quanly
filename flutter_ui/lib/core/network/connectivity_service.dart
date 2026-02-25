import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/api_config.dart';

/// Emits `true` when a usable network connection is available, `false` otherwise.
/// Performs a real reachability check against the API host after connectivity changes.
final connectivityStreamProvider = StreamProvider<bool>((ref) {
  final controller = StreamController<bool>();

  Future<bool> checkReachable() async {
    try {
      final uri = Uri.parse(ApiConfig.baseUrl);
      final result = await InternetAddress.lookup(uri.host)
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void onConnectivityChange(List<ConnectivityResult> results) async {
    if (results.contains(ConnectivityResult.none)) {
      controller.add(false);
      return;
    }
    final reachable = await checkReachable();
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

/// Synchronous-ish snapshot: the latest known connectivity value.
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityStreamProvider).whenData((v) => v).value ?? true;
});
