import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'local_database.dart';

class LocalSeed {
  static String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  /// Seed initial data if not yet seeded (check by roles table being empty).
  static Future<void> seedIfNeeded(LocalDatabase db) async {
    final roles = await db.queryAll('roles');
    if (roles.isNotEmpty) return;

    final now = DateTime.now().toIso8601String();

    // -----------------------------------------------------------------------
    // Roles
    // -----------------------------------------------------------------------
    await db.upsert('roles', {'id': 1, 'name': 'admin', 'display_name': 'Quản trị viên', 'description': 'Toàn quyền hệ thống', 'created_at': now, 'updated_at': now});
    await db.upsert('roles', {'id': 2, 'name': 'manager', 'display_name': 'Quản lý', 'description': 'Quản lý quán', 'created_at': now, 'updated_at': now});
    await db.upsert('roles', {'id': 3, 'name': 'staff', 'display_name': 'Nhân viên', 'description': 'Nhân viên phục vụ', 'created_at': now, 'updated_at': now});
    await db.upsert('roles', {'id': 4, 'name': 'cashier', 'display_name': 'Thu ngân', 'description': 'Thu ngân', 'created_at': now, 'updated_at': now});

    // -----------------------------------------------------------------------
    // Users (password = same as email/username)
    // -----------------------------------------------------------------------
    await db.upsert('users', {'id': 1, 'name': 'Admin', 'email': 'admin', 'password_hash': _hashPassword('admin'), 'phone': '0901000001', 'is_active': true, 'role_id': 1, 'created_at': now, 'updated_at': now});
    await db.upsert('users', {'id': 2, 'name': 'Quản lý', 'email': 'manager', 'password_hash': _hashPassword('manager'), 'phone': '0901000002', 'is_active': true, 'role_id': 2, 'created_at': now, 'updated_at': now});
    await db.upsert('users', {'id': 3, 'name': 'Nhân viên A', 'email': 'staff', 'password_hash': _hashPassword('staff'), 'phone': '0901000003', 'is_active': true, 'role_id': 3, 'created_at': now, 'updated_at': now});
    await db.upsert('users', {'id': 4, 'name': 'Thu ngân', 'email': 'cashier', 'password_hash': _hashPassword('cashier'), 'phone': '0901000004', 'is_active': true, 'role_id': 4, 'created_at': now, 'updated_at': now});

    // -----------------------------------------------------------------------
    // Floors
    // -----------------------------------------------------------------------
    await db.upsert('floors', {'id': 1, 'name': 'Tầng trệt', 'floor_number': 1, 'is_active': true, 'created_at': now, 'updated_at': now});
    await db.upsert('floors', {'id': 2, 'name': 'Tầng lầu', 'floor_number': 2, 'is_active': true, 'created_at': now, 'updated_at': now});

    // Tables – Floor 1: 8 square tables (4 seats each)
    for (int i = 1; i <= 8; i++) {
      final col = (i - 1) % 4;
      final row = (i - 1) ~/ 4;
      await db.upsert('layout_objects', {
        'id': i,
        'floor_id': 1,
        'type': 'table',
        'name': 'Bàn $i',
        'position_x': col * 150.0 + 50.0,
        'position_y': row * 150.0 + 50.0,
        'width': 80.0,
        'height': 80.0,
        'rotation': 0.0,
        'properties': {'seats': 4, 'shape': 'square'},
        'is_active': true,
        'created_at': now,
        'updated_at': now,
      });
    }

    // Tables – Floor 2: 6 round tables (6 seats each)
    for (int i = 9; i <= 14; i++) {
      final col = (i - 9) % 3;
      final row = (i - 9) ~/ 3;
      await db.upsert('layout_objects', {
        'id': i,
        'floor_id': 2,
        'type': 'table',
        'name': 'Bàn $i',
        'position_x': col * 180.0 + 50.0,
        'position_y': row * 180.0 + 50.0,
        'width': 100.0,
        'height': 100.0,
        'rotation': 0.0,
        'properties': {'seats': 6, 'shape': 'round'},
        'is_active': true,
        'created_at': now,
        'updated_at': now,
      });
    }

    // -----------------------------------------------------------------------
    // Categories
    // -----------------------------------------------------------------------
    await db.upsert('categories', {'id': 1, 'name': 'Cà phê', 'sort_order': 1, 'is_active': true, 'created_at': now, 'updated_at': now});
    await db.upsert('categories', {'id': 2, 'name': 'Món nóng', 'sort_order': 2, 'is_active': true, 'created_at': now, 'updated_at': now});
    await db.upsert('categories', {'id': 3, 'name': 'Sữa chua & Đá xay', 'sort_order': 3, 'is_active': true, 'created_at': now, 'updated_at': now});
    await db.upsert('categories', {'id': 4, 'name': 'Trà sữa', 'sort_order': 4, 'is_active': true, 'created_at': now, 'updated_at': now});
    await db.upsert('categories', {'id': 5, 'name': 'Trà trái cây', 'sort_order': 5, 'is_active': true, 'created_at': now, 'updated_at': now});
    await db.upsert('categories', {'id': 6, 'name': 'Ăn vặt', 'sort_order': 6, 'is_active': true, 'created_at': now, 'updated_at': now});

    // -----------------------------------------------------------------------
    // Menu Items
    // -----------------------------------------------------------------------
    int itemId = 1;

    // Cà phê
    final coffeeItems = [
      {'name': 'Cà phê đen phin', 'price': 13000},
      {'name': 'Cà phê sữa phin', 'price': 15000},
      {'name': 'Cà phê đen ép máy', 'price': 16000},
      {'name': 'Cà phê sữa ép máy', 'price': 18000},
      {'name': 'Cà phê muối', 'price': 18000},
      {'name': 'Cà phê kem trứng', 'price': 20000},
      {'name': 'Cà phê cốt dừa', 'price': 20000},
      {'name': 'Bạc xỉu', 'price': 22000},
      {'name': 'Cacao đá', 'price': 25000},
    ];
    for (int j = 0; j < coffeeItems.length; j++) {
      await db.upsert('menu_items', {'id': itemId++, 'category_id': 1, 'name': coffeeItems[j]['name'], 'price': coffeeItems[j]['price'], 'is_available': true, 'sort_order': j + 1, 'created_at': now, 'updated_at': now});
    }

    // Món nóng
    final hotItems = [
      {'name': 'Sữa nóng', 'price': 18000},
      {'name': 'Bạc xỉu nóng', 'price': 22000},
      {'name': 'Cacao nóng', 'price': 25000},
      {'name': 'Trà gừng mật ong', 'price': 18000},
    ];
    for (int j = 0; j < hotItems.length; j++) {
      await db.upsert('menu_items', {'id': itemId++, 'category_id': 2, 'name': hotItems[j]['name'], 'price': hotItems[j]['price'], 'is_available': true, 'sort_order': j + 1, 'created_at': now, 'updated_at': now});
    }

    // Sữa chua & Đá xay
    final yogurtItems = [
      {'name': 'Sữa chua đá xay', 'price': 28000},
      {'name': 'Sữa chua đá xay việt quất', 'price': 28000},
      {'name': 'Sữa chua đá xay xoài', 'price': 28000},
      {'name': 'Sữa chua đá xay đào', 'price': 28000},
      {'name': 'Sữa chua đá xay kiwi', 'price': 28000},
      {'name': 'Matcha đá xay', 'price': 30000},
      {'name': 'Chocolate đá xay', 'price': 30000},
    ];
    for (int j = 0; j < yogurtItems.length; j++) {
      await db.upsert('menu_items', {'id': itemId++, 'category_id': 3, 'name': yogurtItems[j]['name'], 'price': yogurtItems[j]['price'], 'is_available': true, 'sort_order': j + 1, 'created_at': now, 'updated_at': now});
    }

    // Trà sữa + Size L option
    final milkTeaItems = [
      {'name': 'Trà sữa truyền thống', 'price': 18000},
      {'name': 'Trà sữa lài', 'price': 18000},
      {'name': 'Trà sữa trân châu đường đen', 'price': 18000},
      {'name': 'Trà sữa thái xanh matcha', 'price': 20000},
      {'name': 'Trà sữa kem machiato', 'price': 20000},
      {'name': 'Trà sữa kem trứng vụn dừa', 'price': 23000},
      {'name': 'Trà sữa matcha machiato', 'price': 23000},
      {'name': 'Trà sữa khoai môn phết', 'price': 23000},
      {'name': 'Trà sữa Phô mai phết', 'price': 23000},
      {'name': 'Sữa tươi trân châu đường đen', 'price': 18000},
      {'name': 'Matcha latte', 'price': 18000},
    ];
    int optionId = 1;
    for (int j = 0; j < milkTeaItems.length; j++) {
      final currentItemId = itemId++;
      await db.upsert('menu_items', {'id': currentItemId, 'category_id': 4, 'name': milkTeaItems[j]['name'], 'price': milkTeaItems[j]['price'], 'is_available': true, 'sort_order': j + 1, 'created_at': now, 'updated_at': now});
      await db.upsert('menu_item_options', {'id': optionId++, 'menu_item_id': currentItemId, 'name': 'Size L', 'extra_price': 5000, 'created_at': now, 'updated_at': now});
    }

    // Trà trái cây
    final fruitTeaItems = [
      {'name': 'Trà chanh', 'price': 15000},
      {'name': 'Trà chanh hạt chia nha đam', 'price': 20000},
      {'name': 'Trà dâu tằm', 'price': 22000},
      {'name': 'Trà tắc mật ong nha đam', 'price': 22000},
      {'name': 'Trà xoài', 'price': 25000},
      {'name': 'Trà đào cam xả', 'price': 25000},
      {'name': 'Trà ổi', 'price': 25000},
      {'name': 'Trà măng cụt tằm đặc', 'price': 27000},
      {'name': 'Trà vải hạt chia', 'price': 27000},
      {'name': 'Trà dưa lưới', 'price': 27000},
      {'name': 'Trà nho kiwi', 'price': 27000},
      {'name': 'Trà trái cây nhiệt đới', 'price': 30000},
    ];
    for (int j = 0; j < fruitTeaItems.length; j++) {
      await db.upsert('menu_items', {'id': itemId++, 'category_id': 5, 'name': fruitTeaItems[j]['name'], 'price': fruitTeaItems[j]['price'], 'is_available': true, 'sort_order': j + 1, 'created_at': now, 'updated_at': now});
    }

    // Ăn vặt
    final snackItems = [
      {'name': 'Combo 5 (Cá / Bò / Tôm / Cá cốm / Cá phô mai)', 'price': 28000},
      {'name': 'Combo 7 (Thêm ốc và xúc xích)', 'price': 38000},
      {'name': 'Combo 10 (Đầy đủ các loại viên, xúc xích, phô mai que, khoai lang kén, hồ lô...)', 'price': 48000},
      {'name': 'Cá viên', 'price': 10000},
      {'name': 'Bò viên', 'price': 10000},
      {'name': 'Tôm viên', 'price': 10000},
      {'name': 'Ốc viên', 'price': 10000},
      {'name': 'Phô mai que', 'price': 10000},
      {'name': 'Xúc xích', 'price': 10000},
      {'name': 'Xúc xích hồ lô', 'price': 12000},
      {'name': 'Xúc xích phô mai (Hotdog)', 'price': 15000},
      {'name': 'Khoai tây chiên', 'price': 15000},
      {'name': 'Khoai lang kén', 'price': 15000},
      {'name': 'Cá sốt phô mai', 'price': 15000},
      {'name': 'Cá tẩm cốm', 'price': 15000},
      {'name': 'Chả cá rau răm', 'price': 15000},
      {'name': 'Bánh tráng trộn', 'price': 15000},
    ];
    for (int j = 0; j < snackItems.length; j++) {
      await db.upsert('menu_items', {'id': itemId++, 'category_id': 6, 'name': snackItems[j]['name'], 'price': snackItems[j]['price'], 'is_available': true, 'sort_order': j + 1, 'created_at': now, 'updated_at': now});
    }

    // -----------------------------------------------------------------------
    // Inventory Items
    // -----------------------------------------------------------------------
    final inventoryData = [
      {'id': 1, 'name': 'Cà phê hạt', 'unit': 'kg', 'quantity': 20.0, 'min_quantity': 5.0, 'cost_per_unit': 200000.0},
      {'id': 2, 'name': 'Sữa tươi', 'unit': 'l', 'quantity': 30.0, 'min_quantity': 10.0, 'cost_per_unit': 30000.0},
      {'id': 3, 'name': 'Đường', 'unit': 'kg', 'quantity': 15.0, 'min_quantity': 3.0, 'cost_per_unit': 20000.0},
      {'id': 4, 'name': 'Trà ô long', 'unit': 'kg', 'quantity': 5.0, 'min_quantity': 1.0, 'cost_per_unit': 300000.0},
      {'id': 5, 'name': 'Đào ngâm', 'unit': 'kg', 'quantity': 10.0, 'min_quantity': 2.0, 'cost_per_unit': 60000.0},
      {'id': 6, 'name': 'Matcha bột', 'unit': 'kg', 'quantity': 2.0, 'min_quantity': 0.5, 'cost_per_unit': 500000.0},
    ];
    for (final item in inventoryData) {
      await db.upsert('inventory_items', {...item, 'created_at': now, 'updated_at': now});
    }
  }
}
