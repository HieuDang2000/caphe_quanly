import 'dart:convert' as convert;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/local_database.dart';

class PrinterConfig {
  final String id;
  final String name;
  final String type;
  final String? paperSize;

  const PrinterConfig({
    required this.id,
    required this.name,
    this.type = 'system',
    this.paperSize,
  });

  bool get isValid => id.isNotEmpty && name.isNotEmpty;

  PrinterConfig copyWith({
    String? id,
    String? name,
    String? type,
    String? paperSize,
  }) {
    return PrinterConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      paperSize: paperSize ?? this.paperSize,
    );
  }

  factory PrinterConfig.fromJson(Map<String, dynamic> json) {
    return PrinterConfig(
      id: (json['id'] ?? json['printerId'] ?? '') as String,
      name: (json['name'] ?? json['printerName'] ?? '') as String,
      type: (json['type'] ?? 'system') as String,
      paperSize: json['paperSize'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      if (paperSize != null) 'paperSize': paperSize,
    };
  }
}

class PrinterRepository {
  PrinterRepository(this._db);

  final LocalDatabase _db;

  static const String _table = 'app_settings';
  static const String _printerKey = 'printer_config';

  Future<PrinterConfig?> loadPrinterConfig() async {
    final rows = await _db.queryWhere(
      _table,
      where: 'key = ?',
      whereArgs: [_printerKey],
    );
    if (rows.isEmpty) return null;

    final raw = rows.first['value'];
    if (raw == null) return null;

    if (raw is Map<String, dynamic>) {
      return PrinterConfig.fromJson(raw);
    }
    if (raw is Map) {
      return PrinterConfig.fromJson(Map<String, dynamic>.from(raw));
    }
    if (raw is String) {
      // Phòng trường hợp giá trị chưa được deserialize ở tầng DB.
      try {
        final decoded = _tryDecodeJson(raw);
        if (decoded is Map<String, dynamic>) {
          return PrinterConfig.fromJson(decoded);
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> savePrinterConfig(PrinterConfig config) async {
    await _db.upsert(_table, {
      'key': _printerKey,
      'value': config.toJson(),
    });
  }

  Future<void> clearPrinterConfig() async {
    // Ghi đè với value null để coi như chưa cấu hình.
    await _db.upsert(_table, {
      'key': _printerKey,
      'value': null,
    });
  }

  dynamic _tryDecodeJson(String value) {
    // Sử dụng jsonDecode gián tiếp thông qua LocalDatabase để tránh nhập lại logic.
    // Ở đây chỉ dùng dart:convert trực tiếp cho đơn giản.
    return convert.jsonDecode(value);
  }
}

final printerRepositoryProvider = Provider<PrinterRepository>((ref) {
  return PrinterRepository(ref.watch(localDatabaseProvider));
});

