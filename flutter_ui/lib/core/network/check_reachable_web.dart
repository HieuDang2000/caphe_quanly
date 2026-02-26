/// Trên web không dùng dart:io; coi là reachable nếu connectivity không phải none.
Future<bool> checkReachable() async => true;
