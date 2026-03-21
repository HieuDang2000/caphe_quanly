import 'dart:convert' as convert;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/local_database.dart';

class ReceiptTemplate {
  final String shopName;
  final String shopAddress;
  final String shopPhone;
  final String receiptTitle;
  final String footerLine1;
  final String footerLine2;

  const ReceiptTemplate({
    required this.shopName,
    required this.shopAddress,
    required this.shopPhone,
    required this.receiptTitle,
    required this.footerLine1,
    required this.footerLine2,
  });

  factory ReceiptTemplate.defaults() {
    return const ReceiptTemplate(
      shopName: 'HIÊN',
      shopAddress: 'Ngọc Thạnh 2, Phước An, Gia Lai',
      shopPhone: '034-226-3291',
      receiptTitle: 'HÓA ĐƠN THANH TOÁN',
      footerLine1: 'Trà sữa Hiên',
      footerLine2: 'Cảm ơn quý khách! Hẹn gặp lại!',
    );
  }

  ReceiptTemplate copyWith({
    String? shopName,
    String? shopAddress,
    String? shopPhone,
    String? receiptTitle,
    String? footerLine1,
    String? footerLine2,
  }) {
    return ReceiptTemplate(
      shopName: shopName ?? this.shopName,
      shopAddress: shopAddress ?? this.shopAddress,
      shopPhone: shopPhone ?? this.shopPhone,
      receiptTitle: receiptTitle ?? this.receiptTitle,
      footerLine1: footerLine1 ?? this.footerLine1,
      footerLine2: footerLine2 ?? this.footerLine2,
    );
  }

  factory ReceiptTemplate.fromJson(Map<String, dynamic> json) {
    final d = ReceiptTemplate.defaults();
    return ReceiptTemplate(
      shopName: (json['shopName'] as String?)?.trim().isNotEmpty == true ? (json['shopName'] as String).trim() : d.shopName,
      shopAddress: (json['shopAddress'] as String?)?.trim().isNotEmpty == true ? (json['shopAddress'] as String).trim() : d.shopAddress,
      shopPhone: (json['shopPhone'] as String?)?.trim().isNotEmpty == true ? (json['shopPhone'] as String).trim() : d.shopPhone,
      receiptTitle: (json['receiptTitle'] as String?)?.trim().isNotEmpty == true ? (json['receiptTitle'] as String).trim() : d.receiptTitle,
      footerLine1: (json['footerLine1'] as String?)?.trim().isNotEmpty == true ? (json['footerLine1'] as String).trim() : d.footerLine1,
      footerLine2: (json['footerLine2'] as String?)?.trim().isNotEmpty == true ? (json['footerLine2'] as String).trim() : d.footerLine2,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shopName': shopName,
      'shopAddress': shopAddress,
      'shopPhone': shopPhone,
      'receiptTitle': receiptTitle,
      'footerLine1': footerLine1,
      'footerLine2': footerLine2,
    };
  }
}

class ReceiptTemplateRepository {
  ReceiptTemplateRepository(this._db);

  final LocalDatabase _db;

  static const String _table = 'app_settings';
  static const String _key = 'receipt_template';

  Future<ReceiptTemplate?> loadReceiptTemplate() async {
    final rows = await _db.queryWhere(
      _table,
      where: 'key = ?',
      whereArgs: [_key],
    );
    if (rows.isEmpty) return null;

    final raw = rows.first['value'];
    if (raw == null) return null;

    if (raw is Map<String, dynamic>) {
      return ReceiptTemplate.fromJson(raw);
    }
    if (raw is Map) {
      return ReceiptTemplate.fromJson(Map<String, dynamic>.from(raw));
    }
    if (raw is String) {
      // Phòng trường hợp giá trị chưa được deserialize ở tầng DB.
      try {
        final decoded = convert.jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return ReceiptTemplate.fromJson(decoded);
        }
        if (decoded is Map) {
          return ReceiptTemplate.fromJson(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> saveReceiptTemplate(ReceiptTemplate template) async {
    await _db.upsert(_table, {
      'key': _key,
      'value': template.toJson(),
    });
  }

  Future<void> clearReceiptTemplate() async {
    await _db.upsert(_table, {
      'key': _key,
      'value': null,
    });
  }
}

final receiptTemplateRepositoryProvider = Provider<ReceiptTemplateRepository>((ref) {
  return ReceiptTemplateRepository(ref.watch(localDatabaseProvider));
});

