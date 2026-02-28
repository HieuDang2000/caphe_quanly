import 'dart:convert' as convert;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'database_factory_io.dart' if (dart.library.html) 'database_factory_web.dart' as db_factory;

const _dbVersion = 5;

String _jsonEncode(dynamic value) => convert.jsonEncode(value);
dynamic _jsonDecode(String value) => convert.jsonDecode(value);

class LocalDatabase {
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final databaseFactory = db_factory.getDatabaseFactory();
    final dbPath = await db_factory.getDatabasePath();
    return databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: _dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        sort_order INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    batch.execute('''
      CREATE TABLE menu_items (
        id INTEGER PRIMARY KEY,
        category_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        price REAL DEFAULT 0,
        description TEXT,
        image TEXT,
        is_available INTEGER DEFAULT 1,
        sort_order INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE menu_item_options (
        id INTEGER PRIMARY KEY,
        menu_item_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        extra_price REAL DEFAULT 0,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (menu_item_id) REFERENCES menu_items (id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE floors (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        floor_number INTEGER DEFAULT 1,
        is_active INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    batch.execute('''
      CREATE TABLE layout_objects (
        id INTEGER PRIMARY KEY,
        floor_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        name TEXT NOT NULL,
        position_x REAL DEFAULT 0,
        position_y REAL DEFAULT 0,
        width REAL DEFAULT 80,
        height REAL DEFAULT 80,
        rotation REAL DEFAULT 0,
        properties TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (floor_id) REFERENCES floors (id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY,
        user_id INTEGER,
        customer_id INTEGER,
        table_id INTEGER,
        order_number TEXT UNIQUE,
        status TEXT DEFAULT 'pending',
        subtotal REAL DEFAULT 0,
        tax REAL DEFAULT 0,
        discount REAL DEFAULT 0,
        total REAL DEFAULT 0,
        total_all REAL DEFAULT 0,
        highest_total REAL,
        notes TEXT,
        order_history TEXT,
        is_deleted_item INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    batch.execute('''
      CREATE TABLE order_items (
        id INTEGER PRIMARY KEY,
        order_id INTEGER NOT NULL,
        menu_item_id INTEGER NOT NULL,
        quantity INTEGER DEFAULT 1,
        unit_price REAL DEFAULT 0,
        subtotal REAL DEFAULT 0,
        notes TEXT,
        options TEXT,
        is_paid INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE invoices (
        id INTEGER PRIMARY KEY,
        order_id INTEGER NOT NULL,
        invoice_number TEXT UNIQUE,
        subtotal REAL DEFAULT 0,
        tax_rate REAL DEFAULT 0,
        tax_amount REAL DEFAULT 0,
        discount_amount REAL DEFAULT 0,
        total REAL DEFAULT 0,
        payment_status TEXT DEFAULT 'unpaid',
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY,
        invoice_id INTEGER NOT NULL,
        amount REAL DEFAULT 0,
        payment_method TEXT DEFAULT 'cash',
        reference_number TEXT,
        paid_at TEXT,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE _sync_meta (
        table_name TEXT PRIMARY KEY,
        last_synced_at TEXT
      )
    ''');

    batch.execute('CREATE INDEX idx_menu_items_category ON menu_items (category_id)');
    batch.execute('CREATE INDEX idx_menu_item_options_item ON menu_item_options (menu_item_id)');
    batch.execute('CREATE INDEX idx_layout_objects_floor ON layout_objects (floor_id)');
    batch.execute('CREATE INDEX idx_orders_status ON orders (status)');
    batch.execute('CREATE INDEX idx_orders_table ON orders (table_id)');
    batch.execute('CREATE INDEX idx_order_items_order ON order_items (order_id)');
    batch.execute('CREATE INDEX idx_invoices_order ON invoices (order_id)');
    batch.execute('CREATE INDEX idx_payments_invoice ON payments (invoice_id)');

    await batch.commit(noResult: true);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v2: ensure _sync_meta exists for older installs created before this table
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS _sync_meta (
          table_name TEXT PRIMARY KEY,
          last_synced_at TEXT
        )
      ''');
    }
    // v3: orders.total_all, orders.highest_total
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE orders ADD COLUMN total_all REAL DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE orders ADD COLUMN highest_total REAL');
      } catch (_) {}
    }
    // v4: orders.order_history
    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE orders ADD COLUMN order_history TEXT');
      } catch (_) {}
    }
    // v5: orders.is_deleted_item
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE orders ADD COLUMN is_deleted_item INTEGER DEFAULT 0');
      } catch (_) {}
    }
  }

  // ---------------------------------------------------------------------------
  // Generic CRUD
  // ---------------------------------------------------------------------------

  Future<void> upsertBatch(String table, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final row in rows) {
      batch.insert(table, _sanitize(table, row),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> upsert(String table, Map<String, dynamic> row) async {
    final db = await database;
    await db.insert(table, _sanitize(table, row),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> queryAll(String table,
      {String? orderBy}) async {
    final db = await database;
    final rows = await db.query(table, orderBy: orderBy);
    return rows.map(_deserialize).toList();
  }

  Future<Map<String, dynamic>?> queryById(String table, int id) async {
    final db = await database;
    final rows = await db.query(table, where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _deserialize(rows.first);
  }

  Future<List<Map<String, dynamic>>> queryWhere(
    String table, {
    required String where,
    required List<Object?> whereArgs,
    String? orderBy,
  }) async {
    final db = await database;
    final rows = await db.query(table,
        where: where, whereArgs: whereArgs, orderBy: orderBy);
    return rows.map(_deserialize).toList();
  }

  Future<void> deleteByIds(String table, List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.delete(table, where: 'id IN ($placeholders)', whereArgs: ids);
  }

  Future<void> clearTable(String table) async {
    final db = await database;
    await db.delete(table);
  }

  // ---------------------------------------------------------------------------
  // Sync metadata
  // ---------------------------------------------------------------------------

  Future<DateTime?> getSyncTime(String table) async {
    final db = await database;
    final rows = await db.query('_sync_meta',
        where: 'table_name = ?', whereArgs: [table]);
    if (rows.isEmpty) return null;
    final ts = rows.first['last_synced_at'] as String?;
    return ts == null ? null : DateTime.tryParse(ts);
  }

  Future<void> setSyncTime(String table, DateTime time) async {
    final db = await database;
    await db.insert(
      '_sync_meta',
      {'table_name': table, 'last_synced_at': time.toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---------------------------------------------------------------------------
  // Sanitize / Deserialize
  // ---------------------------------------------------------------------------

  static const _tableColumns = <String, Set<String>>{
    'categories': {'id', 'name', 'description', 'sort_order', 'is_active', 'created_at', 'updated_at'},
    'menu_items': {'id', 'category_id', 'name', 'price', 'description', 'image', 'is_available', 'sort_order', 'created_at', 'updated_at'},
    'menu_item_options': {'id', 'menu_item_id', 'name', 'extra_price', 'created_at', 'updated_at'},
    'floors': {'id', 'name', 'floor_number', 'is_active', 'created_at', 'updated_at'},
    'layout_objects': {'id', 'floor_id', 'type', 'name', 'position_x', 'position_y', 'width', 'height', 'rotation', 'properties', 'is_active', 'created_at', 'updated_at'},
    'orders': {'id', 'user_id', 'customer_id', 'table_id', 'order_number', 'status', 'subtotal', 'tax', 'discount', 'total', 'total_all', 'highest_total', 'notes', 'order_history', 'is_deleted_item', 'created_at', 'updated_at'},
    'order_items': {'id', 'order_id', 'menu_item_id', 'quantity', 'unit_price', 'subtotal', 'notes', 'options', 'is_paid', 'created_at', 'updated_at'},
    'invoices': {'id', 'order_id', 'invoice_number', 'subtotal', 'tax_rate', 'tax_amount', 'discount_amount', 'total', 'payment_status', 'created_at', 'updated_at'},
    'payments': {'id', 'invoice_id', 'amount', 'payment_method', 'reference_number', 'paid_at', 'created_at', 'updated_at'},
  };

  static const _jsonColumns = {'properties', 'options'};
  static const _boolColumns = {'is_active', 'is_available', 'is_paid', 'is_deleted_item'};

  Map<String, dynamic> _sanitize(String table, Map<String, dynamic> row) {
    final allowed = _tableColumns[table];
    if (allowed == null) return Map<String, dynamic>.from(row);
    final out = <String, dynamic>{};
    for (final key in allowed) {
      if (!row.containsKey(key)) continue;
      var value = row[key];
      if (_jsonColumns.contains(key) && value is! String && value != null) {
        value = _jsonEncode(value);
      }
      if (_boolColumns.contains(key) && value is bool) {
        value = value ? 1 : 0;
      }
      out[key] = value;
    }
    return out;
  }

  Map<String, dynamic> _deserialize(Map<String, dynamic> row) {
    final out = Map<String, dynamic>.from(row);
    for (final key in _boolColumns) {
      if (out.containsKey(key)) {
        final v = out[key];
        if (v is int) out[key] = v == 1;
      }
    }
    for (final key in _jsonColumns) {
      if (out.containsKey(key) && out[key] is String) {
        try {
          out[key] = _jsonDecode(out[key] as String);
        } catch (_) {}
      }
    }
    return out;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  throw UnimplementedError('LocalDatabase must be initialised before runApp');
});
