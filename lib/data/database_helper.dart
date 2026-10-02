import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';
import '../utils/currency_utils.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('maishop.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Bảng sản phẩm
    await db.execute('''
      CREATE TABLE products (
        barcode TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        price INTEGER NOT NULL,
        cost_price INTEGER,
        unit TEXT NOT NULL,
        stock INTEGER NOT NULL DEFAULT 0,
        category TEXT NOT NULL DEFAULT 'Chung',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Tạo chỉ mục cho tìm kiếm nhanh
    await db.execute('CREATE INDEX idx_products_name ON products(name)');

    // Bảng đơn hàng
    await db.execute('''
      CREATE TABLE orders (
        id TEXT PRIMARY KEY,
        created_at TEXT NOT NULL,
        items_json TEXT NOT NULL,
        total_amount INTEGER NOT NULL,
        customer_paid INTEGER NOT NULL,
        change_amount INTEGER NOT NULL,
        payment_method TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await db.execute('CREATE INDEX idx_orders_created_at ON orders(created_at)');
  }

  // ==================== SETTINGS OPERATIONS ====================

  Future<String?> getSetting(String key) async {
    final db = await database;
    await db.execute('CREATE TABLE IF NOT EXISTS app_settings (key TEXT PRIMARY KEY, value TEXT)');
    final rows = await db.query('app_settings', where: 'key = ?', whereArgs: [key]);
    if (rows.isNotEmpty) return rows.first['value'] as String?;
    return null;
  }

  Future<void> setSetting(String key, String? value) async {
    final db = await database;
    await db.execute('CREATE TABLE IF NOT EXISTS app_settings (key TEXT PRIMARY KEY, value TEXT)');
    if (value == null) {
      await db.delete('app_settings', where: 'key = ?', whereArgs: [key]);
    } else {
      await db.insert('app_settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<Map<String, String>> getAllSettings() async {
    final db = await database;
    await db.execute('CREATE TABLE IF NOT EXISTS app_settings (key TEXT PRIMARY KEY, value TEXT)');
    final rows = await db.query('app_settings');
    final map = <String, String>{};
    for (final r in rows) {
      if (r['key'] != null && r['value'] != null) {
        map[r['key'] as String] = r['value'] as String;
      }
    }
    return map;
  }

  // ==================== PRODUCT CRUD ====================

  Future<int> insertProduct(Product product) async {
    final db = await database;
    return await db.insert(
      'products',
      product.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateProduct(Product product) async {
    final db = await database;
    return await db.update(
      'products',
      product.toMap(),
      where: 'barcode = ?',
      whereArgs: [product.barcode],
    );
  }

  Future<int> deleteProduct(String barcode) async {
    final db = await database;
    return await db.delete(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
    );
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await database;
    final maps = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode.trim()],
    );

    if (maps.isNotEmpty) {
      return Product.fromMap(maps.first);
    }
    return null;
  }

  /// Lấy danh sách sản phẩm có tìm kiếm và sắp xếp
  Future<List<Product>> getProducts({
    String? query,
    ProductSortOption sortOption = ProductSortOption.newest,
  }) async {
    final db = await database;

    String orderBy;
    switch (sortOption) {
      case ProductSortOption.nameAsc:
        orderBy = 'name COLLATE NOCASE ASC';
        break;
      case ProductSortOption.nameDesc:
        orderBy = 'name COLLATE NOCASE DESC';
        break;
      case ProductSortOption.priceAsc:
        orderBy = 'price ASC';
        break;
      case ProductSortOption.priceDesc:
        orderBy = 'price DESC';
        break;
      case ProductSortOption.newest:
        orderBy = 'created_at DESC';
        break;
      case ProductSortOption.stockLow:
        orderBy = 'stock ASC, name ASC';
        break;
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      orderBy: orderBy,
    );

    var list = maps.map((map) => Product.fromMap(map)).toList();

    // Lọc theo từ khóa tìm kiếm (hỗ trợ tìm cả mã vạch và tên tiếng Việt không dấu)
    if (query != null && query.trim().isNotEmpty) {
      final q = CurrencyUtils.removeDiacritics(query.trim());
      list = list.where((p) {
        final nameNorm = CurrencyUtils.removeDiacritics(p.name);
        return nameNorm.contains(q) || p.barcode.contains(q);
      }).toList();
    }

    return list;
  }

  /// Cập nhật hàng loạt sản phẩm đồng bộ từ Google Sheets
  Future<void> upsertProductsFromSheets(List<Product> products) async {
    final db = await database;
    final batch = db.batch();

    for (final product in products) {
      batch.insert(
        'products',
        product.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  // ==================== ORDER OPERATIONS ====================

  Future<int> insertOrder(Order order) async {
    final db = await database;

    // Giảm tồn kho tương ứng của các mặt hàng
    final batch = db.batch();
    for (final item in order.items) {
      batch.rawUpdate(
        'UPDATE products SET stock = MAX(0, stock - ?) WHERE barcode = ?',
        [item.quantity, item.product.barcode],
      );
    }
    batch.insert('orders', order.toMap());
    await batch.commit(noResult: true);

    return 1;
  }

  Future<List<Order>> getOrders({DateTime? fromDate}) async {
    final db = await database;
    List<Map<String, dynamic>> maps;

    if (fromDate != null) {
      maps = await db.query(
        'orders',
        where: 'created_at >= ?',
        whereArgs: [fromDate.toIso8601String()],
        orderBy: 'created_at DESC',
      );
    } else {
      maps = await db.query(
        'orders',
        orderBy: 'created_at DESC',
      );
    }

    return maps.map((map) => Order.fromMap(map)).toList();
  }

  Future<List<Order>> getUnsyncedOrders() async {
    final db = await database;
    final maps = await db.query(
      'orders',
      where: 'is_synced = 0',
      orderBy: 'created_at ASC',
    );
    return maps.map((map) => Order.fromMap(map)).toList();
  }

  Future<void> markOrdersSynced(List<String> orderIds) async {
    if (orderIds.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final id in orderIds) {
      batch.update(
        'orders',
        {'is_synced': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }
}
