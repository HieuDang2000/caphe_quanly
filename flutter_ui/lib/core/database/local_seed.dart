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

    // Layout objects: sync with server `layout_objects` seed
    final layoutObjects = [
      {
        'id': 1,
        'floor_id': 1,
        'type': 'table',
        'name': 'Bàn 1',
        'position_x': 105.0,
        'position_y': 726.0,
        'width': 80.0,
        'height': 80.0,
        'rotation': 0.0,
        'properties': {'seats': 4, 'shape': 'square'},
        'is_active': true,
      },
      {
        'id': 3,
        'floor_id': 1,
        'type': 'table',
        'name': 'Bàn 3',
        'position_x': 105.0,
        'position_y': 628.0,
        'width': 80.0,
        'height': 80.0,
        'rotation': 0.0,
        'properties': {'seats': 4, 'shape': 'square'},
        'is_active': true,
      },
      {
        'id': 4,
        'floor_id': 1,
        'type': 'table',
        'name': 'Bàn 4',
        'position_x': 318.0,
        'position_y': 633.0,
        'width': 80.0,
        'height': 80.0,
        'rotation': 0.0,
        'properties': {'seats': 4, 'shape': 'square'},
        'is_active': true,
      },
      {
        'id': 5,
        'floor_id': 1,
        'type': 'table',
        'name': 'Bàn 5',
        'position_x': 101.0,
        'position_y': 496.0,
        'width': 80.0,
        'height': 80.0,
        'rotation': 0.0,
        'properties': {'seats': 4, 'shape': 'square'},
        'is_active': true,
      },
      {
        'id': 6,
        'floor_id': 1,
        'type': 'table',
        'name': 'Bàn 6',
        'position_x': 307.0,
        'position_y': 497.0,
        'width': 80.0,
        'height': 80.0,
        'rotation': 0.0,
        'properties': {'seats': 4, 'shape': 'square'},
        'is_active': true,
      },
      {
        'id': 7,
        'floor_id': 1,
        'type': 'table',
        'name': 'Bàn 7',
        'position_x': 98.0,
        'position_y': 404.0,
        'width': 80.0,
        'height': 80.0,
        'rotation': 0.0,
        'properties': {'seats': 4, 'shape': 'square'},
        'is_active': true,
      },
      {
        'id': 8,
        'floor_id': 1,
        'type': 'table',
        'name': 'Bàn 8',
        'position_x': 308.0,
        'position_y': 407.0,
        'width': 80.0,
        'height': 80.0,
        'rotation': 0.0,
        'properties': {'seats': 4, 'shape': 'square'},
        'is_active': true,
      },
      {
        'id': 15,
        'floor_id': 1,
        'type': 'table',
        'name': 'Bàn 2',
        'position_x': 322.0,
        'position_y': 727.0,
        'width': 80.0,
        'height': 80.0,
        'rotation': 0.0,
        'properties': {'seats': 4, 'shape': 'square'},
        'is_active': true,
      },
      {
        'id': 16,
        'floor_id': 1,
        'type': 'table',
        'name': 'Bàn 9',
        'position_x': 97.0,
        'position_y': 312.0,
        'width': 80.0,
        'height': 80.0,
        'rotation': 0.0,
        'properties': {'seats': 4, 'shape': 'square'},
        'is_active': true,
      },
      {
        'id': 17,
        'floor_id': 1,
        'type': 'table',
        'name': 'Bàn 10',
        'position_x': 305.0,
        'position_y': 315.0,
        'width': 80.0,
        'height': 80.0,
        'rotation': 0.0,
        'properties': {'seats': 4, 'shape': 'square'},
        'is_active': true,
      },
      {
        'id': 18,
        'floor_id': 1,
        'type': 'table',
        'name': 'Bàn 11',
        'position_x': 94.0,
        'position_y': 225.0,
        'width': 80.0,
        'height': 80.0,
        'rotation': 0.0,
        'properties': {'seats': 4, 'shape': 'square'},
        'is_active': true,
      },
      {
        'id': 19,
        'floor_id': 1,
        'type': 'table',
        'name': 'Bàn 12',
        'position_x': 305.0,
        'position_y': 225.0,
        'width': 80.0,
        'height': 80.0,
        'rotation': 0.0,
        'properties': {'seats': 4, 'shape': 'square'},
        'is_active': true,
      },
      {
        'id': 20,
        'floor_id': 1,
        'type': 'table',
        'name': 'Bàn 13',
        'position_x': 96.0,
        'position_y': 136.0,
        'width': 80.0,
        'height': 80.0,
        'rotation': 0.0,
        'properties': {'seats': 4, 'shape': 'square'},
        'is_active': true,
      },
      {
        'id': 21,
        'floor_id': 1,
        'type': 'table',
        'name': 'Bàn 14',
        'position_x': 304.0,
        'position_y': 133.0,
        'width': 80.0,
        'height': 80.0,
        'rotation': 0.0,
        'properties': {'seats': 4, 'shape': 'square'},
        'is_active': true,
      },
      {
        'id': 24,
        'floor_id': 1,
        'type': 'table',
        'name': 'Mang về 1',
        'position_x': 487.0,
        'position_y': 618.0,
        'width': 80.0,
        'height': 80.0,
        'rotation': 0.0,
        'properties': {'seats': 4, 'shape': 'square'},
        'is_active': true,
      },
      {
        'id': 25,
        'floor_id': 1,
        'type': 'wall',
        'name': 'Tường 1',
        'position_x': 146.0,
        'position_y': 589.0,
        'width': 200.0,
        'height': 20.0,
        'rotation': 0.0,
        'properties': {'color': '#8B4513'},
        'is_active': true,
      },
      {
        'id': 26,
        'floor_id': 1,
        'type': 'reception',
        'name': 'Quầy 1',
        'position_x': 194.0,
        'position_y': 808.0,
        'width': 120.0,
        'height': 60.0,
        'rotation': 0.0,
        'properties': {'color': '#CD853F'},
        'is_active': true,
      },
      {
        'id': 27,
        'floor_id': 1,
        'type': 'table',
        'name': 'Mang về 2',
        'position_x': 487.0,
        'position_y': 531.0,
        'width': 80.0,
        'height': 80.0,
        'rotation': 0.0,
        'properties': {'seats': 4, 'shape': 'square'},
        'is_active': true,
      },
      {
        'id': 28,
        'floor_id': 1,
        'type': 'table',
        'name': 'Mang về 3',
        'position_x': 487.0,
        'position_y': 442.0,
        'width': 80.0,
        'height': 80.0,
        'rotation': 0.0,
        'properties': {'seats': 4, 'shape': 'square'},
        'is_active': true,
      },
      {
        'id': 29,
        'floor_id': 1,
        'type': 'table',
        'name': 'Mang về 4',
        'position_x': 485.0,
        'position_y': 351.0,
        'width': 80.0,
        'height': 80.0,
        'rotation': 0.0,
        'properties': {'seats': 4, 'shape': 'square'},
        'is_active': true,
      },
      {
        'id': 30,
        'floor_id': 1,
        'type': 'table',
        'name': 'Mang về 5',
        'position_x': 484.0,
        'position_y': 262.0,
        'width': 80.0,
        'height': 80.0,
        'rotation': 0.0,
        'properties': {'seats': 4, 'shape': 'square'},
        'is_active': true,
      },
      {
        'id': 31,
        'floor_id': 1,
        'type': 'table',
        'name': 'Bàn 15',
        'position_x': 94.0,
        'position_y': 49.0,
        'width': 80.0,
        'height': 80.0,
        'rotation': 0.0,
        'properties': {'seats': 4, 'shape': 'square'},
        'is_active': true,
      },
      {
        'id': 32,
        'floor_id': 1,
        'type': 'table',
        'name': 'Bàn 16',
        'position_x': 303.0,
        'position_y': 48.0,
        'width': 80.0,
        'height': 80.0,
        'rotation': 0.0,
        'properties': {'seats': 4, 'shape': 'square'},
        'is_active': true,
      },
    ];

    for (final obj in layoutObjects) {
      await db.upsert('layout_objects', {
        ...obj,
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
    await db.upsert('categories', {'id': 7, 'name': 'Topping', 'sort_order': 7, 'is_active': true, 'created_at': now, 'updated_at': now});

    // -----------------------------------------------------------------------
    // Menu Items – sync với server `menu_items` seed
    // -----------------------------------------------------------------------
    final menuItems = <Map<String, dynamic>>[
      // Cà phê (category_id = 1)
      {'id': 1, 'category_id': 1, 'name': 'Cà phê đen phin', 'price': 13000, 'is_available': true, 'sort_order': 1},
      {'id': 2, 'category_id': 1, 'name': 'Cà phê sữa phin', 'price': 15000, 'is_available': true, 'sort_order': 2},
      {'id': 3, 'category_id': 1, 'name': 'Cà phê đen ép máy', 'price': 16000, 'is_available': true, 'sort_order': 3},
      {'id': 4, 'category_id': 1, 'name': 'Cà phê sữa ép máy', 'price': 18000, 'is_available': true, 'sort_order': 4},
      {'id': 5, 'category_id': 1, 'name': 'Cà phê muối', 'price': 18000, 'is_available': true, 'sort_order': 5},
      {'id': 6, 'category_id': 1, 'name': 'Cà phê kem trứng', 'price': 20000, 'is_available': true, 'sort_order': 6},
      {'id': 7, 'category_id': 1, 'name': 'Cà phê cốt dừa', 'price': 20000, 'is_available': true, 'sort_order': 7},
      {'id': 8, 'category_id': 1, 'name': 'Bạc xỉu', 'price': 22000, 'is_available': true, 'sort_order': 8},
      {'id': 9, 'category_id': 1, 'name': 'Cacao đá', 'price': 25000, 'is_available': true, 'sort_order': 9},

      // Món nóng (category_id = 2)
      {'id': 10, 'category_id': 2, 'name': 'Sữa nóng', 'price': 18000, 'is_available': true, 'sort_order': 1},
      {'id': 11, 'category_id': 2, 'name': 'Bạc xỉu nóng', 'price': 22000, 'is_available': true, 'sort_order': 2},
      {'id': 12, 'category_id': 2, 'name': 'Cacao nóng', 'price': 25000, 'is_available': true, 'sort_order': 3},
      {'id': 13, 'category_id': 2, 'name': 'Trà gừng mật ong', 'price': 18000, 'is_available': true, 'sort_order': 4},

      // Sữa chua & Đá xay (category_id = 3)
      {'id': 14, 'category_id': 3, 'name': 'Sữa chua đá xay ', 'price': 28000, 'is_available': true, 'sort_order': 1},
      {'id': 15, 'category_id': 3, 'name': 'Sữa chua đá xay việt quất', 'price': 28000, 'is_available': true, 'sort_order': 2},
      {'id': 16, 'category_id': 3, 'name': 'Sữa chua đá xay xoài', 'price': 28000, 'is_available': true, 'sort_order': 3},
      {'id': 17, 'category_id': 3, 'name': 'Sữa chua đá xay đào', 'price': 28000, 'is_available': true, 'sort_order': 4},
      {'id': 18, 'category_id': 3, 'name': 'Sữa chua đá xay kiwi', 'price': 28000, 'is_available': true, 'sort_order': 5},
      {'id': 19, 'category_id': 3, 'name': 'Matcha đá xay', 'price': 30000, 'is_available': true, 'sort_order': 6},
      {'id': 20, 'category_id': 3, 'name': 'Chocolate đá xay', 'price': 30000, 'is_available': true, 'sort_order': 7},

      // Trà trái cây (category_id = 5)
      {'id': 21, 'category_id': 5, 'name': 'Trà chanh', 'price': 15000, 'is_available': true, 'sort_order': 1},
      {'id': 22, 'category_id': 5, 'name': 'Trà chanh hạt chia nha đam', 'price': 20000, 'is_available': true, 'sort_order': 2},
      {'id': 23, 'category_id': 5, 'name': 'Trà dâu tằm', 'price': 22000, 'is_available': true, 'sort_order': 3},
      {'id': 24, 'category_id': 5, 'name': 'Trà tắc mật ong nha đam', 'price': 22000, 'is_available': true, 'sort_order': 4},
      {'id': 25, 'category_id': 5, 'name': 'Trà xoài', 'price': 25000, 'is_available': true, 'sort_order': 5},
      {'id': 26, 'category_id': 5, 'name': 'Trà đào cam xả', 'price': 25000, 'is_available': true, 'sort_order': 6},
      {'id': 27, 'category_id': 5, 'name': 'Trà ổi', 'price': 25000, 'is_available': true, 'sort_order': 7},
      {'id': 28, 'category_id': 5, 'name': 'Trà măng cụt tằm đặc', 'price': 27000, 'is_available': true, 'sort_order': 8},
      {'id': 29, 'category_id': 5, 'name': 'Trà vải hạt chia', 'price': 27000, 'is_available': true, 'sort_order': 9},
      {'id': 30, 'category_id': 5, 'name': 'Trà dưa lưới', 'price': 27000, 'is_available': true, 'sort_order': 10},
      {'id': 31, 'category_id': 5, 'name': 'Trà nho kiwi', 'price': 27000, 'is_available': true, 'sort_order': 11},
      {'id': 32, 'category_id': 5, 'name': 'Trà trái cây nhiệt đới', 'price': 30000, 'is_available': true, 'sort_order': 12},

      // Trà sữa (category_id = 4)
      {'id': 33, 'category_id': 4, 'name': 'Trà sữa truyền thống', 'price': 18000, 'is_available': true, 'sort_order': 1},
      {'id': 34, 'category_id': 4, 'name': 'Trà sữa lài', 'price': 18000, 'is_available': true, 'sort_order': 2},
      {'id': 35, 'category_id': 4, 'name': 'Trà sữa trân châu đường đen', 'price': 18000, 'is_available': true, 'sort_order': 3},
      {'id': 36, 'category_id': 4, 'name': 'Trà sữa thái xanh matcha', 'price': 20000, 'is_available': true, 'sort_order': 4},
      {'id': 37, 'category_id': 4, 'name': 'Trà sữa kem machiato', 'price': 20000, 'is_available': true, 'sort_order': 5},
      {'id': 38, 'category_id': 4, 'name': 'Trà sữa kem trứng vụn dừa', 'price': 23000, 'is_available': true, 'sort_order': 6},
      {'id': 39, 'category_id': 4, 'name': 'Trà sữa matcha machiato', 'price': 23000, 'is_available': true, 'sort_order': 7},
      {'id': 40, 'category_id': 4, 'name': 'Trà sữa khoai môn phết', 'price': 23000, 'is_available': true, 'sort_order': 8},
      {'id': 41, 'category_id': 4, 'name': 'Trà sữa Phô mai phết', 'price': 23000, 'is_available': true, 'sort_order': 9},
      {'id': 42, 'category_id': 4, 'name': 'Sữa tươi trân châu đường đen', 'price': 18000, 'is_available': true, 'sort_order': 10},
      {'id': 43, 'category_id': 4, 'name': 'Matcha latte', 'price': 18000, 'is_available': true, 'sort_order': 11},

      // Ăn vặt (category_id = 6)
      {'id': 44, 'category_id': 6, 'name': 'Combo 5', 'price': 28000, 'is_available': true, 'sort_order': 1},
      {'id': 45, 'category_id': 6, 'name': 'Combo 7', 'price': 38000, 'is_available': true, 'sort_order': 2},
      {'id': 46, 'category_id': 6, 'name': 'Combo 10', 'price': 48000, 'is_available': true, 'sort_order': 3},
      {'id': 47, 'category_id': 6, 'name': 'Cá viên', 'price': 10000, 'is_available': true, 'sort_order': 4},
      {'id': 48, 'category_id': 6, 'name': 'Bò viên', 'price': 10000, 'is_available': true, 'sort_order': 5},
      {'id': 49, 'category_id': 6, 'name': 'Tôm viên', 'price': 10000, 'is_available': true, 'sort_order': 6},
      {'id': 50, 'category_id': 6, 'name': 'Ốc viên', 'price': 10000, 'is_available': true, 'sort_order': 7},
      {'id': 51, 'category_id': 6, 'name': 'Phô mai que', 'price': 10000, 'is_available': true, 'sort_order': 8},
      {'id': 52, 'category_id': 6, 'name': 'Xúc xích', 'price': 10000, 'is_available': true, 'sort_order': 9},
      {'id': 53, 'category_id': 6, 'name': 'Xúc xích hồ lô', 'price': 12000, 'is_available': true, 'sort_order': 10},
      {'id': 54, 'category_id': 6, 'name': 'Xúc xích phô mai (Hotdog)', 'price': 15000, 'is_available': true, 'sort_order': 11},
      {'id': 55, 'category_id': 6, 'name': 'Khoai tây chiên', 'price': 15000, 'is_available': true, 'sort_order': 12},
      {'id': 56, 'category_id': 6, 'name': 'Khoai lang kén', 'price': 15000, 'is_available': true, 'sort_order': 13},
      {'id': 57, 'category_id': 6, 'name': 'Cá sốt phô mai', 'price': 15000, 'is_available': true, 'sort_order': 14},
      {'id': 58, 'category_id': 6, 'name': 'Cá tẩm cốm', 'price': 15000, 'is_available': true, 'sort_order': 15},
      {'id': 59, 'category_id': 6, 'name': 'Chả cá rau răm', 'price': 15000, 'is_available': true, 'sort_order': 16},
      {'id': 60, 'category_id': 6, 'name': 'Bánh tráng trộn', 'price': 15000, 'is_available': true, 'sort_order': 17},

      // Sữa chua thêm (category_id = 3, sort_order = 0)
      {'id': 61, 'category_id': 3, 'name': 'Sữa chua hôp', 'price': 10000, 'is_available': true, 'sort_order': 0},
      {'id': 62, 'category_id': 3, 'name': 'Sữa chua đánh đá', 'price': 23000, 'is_available': true, 'sort_order': 0},

      // Topping (category_id = 7, sort_order = 0)
      {'id': 63, 'category_id': 7, 'name': 'Trân châu', 'price': 5000, 'is_available': true, 'sort_order': 0},
      {'id': 64, 'category_id': 7, 'name': 'Thạch', 'price': 5000, 'is_available': true, 'sort_order': 0},
      {'id': 65, 'category_id': 7, 'name': 'Kem trứng', 'price': 5000, 'is_available': true, 'sort_order': 0},
      {'id': 66, 'category_id': 7, 'name': 'Kem muối', 'price': 3000, 'is_available': true, 'sort_order': 0},
      {'id': 67, 'category_id': 7, 'name': 'Kem machiato', 'price': 5000, 'is_available': true, 'sort_order': 0},
      {'id': 68, 'category_id': 7, 'name': 'Thuốc', 'price': 30000, 'is_available': true, 'sort_order': 0},
      {'id': 69, 'category_id': 7, 'name': 'Thuốc lẻ', 'price': 2000, 'is_available': true, 'sort_order': 0},
      {'id': 71, 'category_id': 7, 'name': 'Trái cây', 'price': 5000, 'is_available': true, 'sort_order': 0},
    ];

    for (final item in menuItems) {
      await db.upsert('menu_items', {
        ...item,
        'created_at': now,
        'updated_at': now,
      });
    }

    // Options cho Trà sữa (Size L) – local only
    int optionId = 1;
    const milkTeaItemIds = [33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43];
    for (final menuItemId in milkTeaItemIds) {
      await db.upsert('menu_item_options', {
        'id': optionId++,
        'menu_item_id': menuItemId,
        'name': 'Size L',
        'extra_price': 5000,
        'created_at': now,
        'updated_at': now,
      });
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
