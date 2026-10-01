import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:gsheets/gsheets.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';
import '../data/database_helper.dart';

class SheetsService {
  static final SheetsService instance = SheetsService._init();
  GSheets? _gsheets;
  Spreadsheet? _spreadsheet;

  String? _spreadsheetId;
  String? _credentialsJson;

  SheetsService._init();

  static const String productsSheetTitle = 'Sản phẩm';
  static const String ordersSheetTitle = 'Đơn hàng';

  static const List<String> productsHeaders = [
    'Mã vạch',
    'Tên sản phẩm',
    'Giá bán (VNĐ)',
    'Giá vốn (VNĐ)',
    'Đơn vị',
    'Tồn kho',
    'Ghi chú',
  ];

  static const List<String> ordersHeaders = [
    'Mã đơn',
    'Thời gian',
    'Chi tiết mặt hàng',
    'Tổng tiền (VNĐ)',
    'Khách đưa (VNĐ)',
    'Tiền thối (VNĐ)',
    'Phương thức',
  ];

  /// Nạp cấu hình từ DB cục bộ
  Future<void> loadConfig() async {
    final dbPath = await getDatabasesPath();
    final db = await openDatabase(join(dbPath, 'maishop.db'));

    // Tạo bảng cài đặt nếu chưa có
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    final rows = await db.query('app_settings');
    for (final r in rows) {
      if (r['key'] == 'sheets_id') {
        _spreadsheetId = r['value'] as String?;
      } else if (r['key'] == 'service_account_json') {
        _credentialsJson = r['value'] as String?;
      }
    }

    if (isConfigured) {
      _initGSheets();
    }
  }

  /// Lưu cấu hình vào DB cục bộ
  Future<void> saveConfig({
    required String spreadsheetId,
    required String credentialsJson,
  }) async {
    _spreadsheetId = spreadsheetId.trim();
    _credentialsJson = credentialsJson.trim();

    final dbPath = await getDatabasesPath();
    final db = await openDatabase(join(dbPath, 'maishop.db'));

    final batch = db.batch();
    batch.insert(
      'app_settings',
      {'key': 'sheets_id', 'value': _spreadsheetId},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    batch.insert(
      'app_settings',
      {'key': 'service_account_json', 'value': _credentialsJson},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await batch.commit(noResult: true);

    _initGSheets();
  }

  bool get isConfigured =>
      _spreadsheetId != null &&
      _spreadsheetId!.isNotEmpty &&
      _credentialsJson != null &&
      _credentialsJson!.isNotEmpty;

  String? get spreadsheetId => _spreadsheetId;
  String? get credentialsJson => _credentialsJson;

  /// Lấy email của Service Account từ credentials JSON để người dùng copy chia sẻ quyền Sheet
  String? get serviceAccountEmail {
    if (_credentialsJson == null || _credentialsJson!.isEmpty) return null;
    try {
      final map = jsonDecode(_credentialsJson!);
      return map['client_email'] as String?;
    } catch (_) {
      return null;
    }
  }

  void _initGSheets() {
    if (!isConfigured) return;
    try {
      _gsheets = GSheets(_credentialsJson!);
      _spreadsheet = null;
    } catch (e) {
      debugPrint('Lỗi khởi tạo GSheets: $e');
    }
  }

  Future<Spreadsheet> _getSpreadsheet() async {
    if (_spreadsheet != null) return _spreadsheet!;
    if (!isConfigured) {
      throw Exception('Chưa cấu hình Google Sheets ID hoặc Service Account JSON.');
    }
    _initGSheets();
    _spreadsheet = await _gsheets!.spreadsheet(_spreadsheetId!);
    return _spreadsheet!;
  }

  /// Kiểm tra kết nối tới Google Sheets
  Future<bool> testConnection() async {
    try {
      final ss = await _getSpreadsheet();
      // Đảm bảo các tab tồn tại
      await _ensureWorksheets(ss);
      return true;
    } catch (e) {
      debugPrint('Kiểm tra kết nối Google Sheets thất bại: $e');
      rethrow;
    }
  }

  Future<Worksheet> _ensureWorksheet(Spreadsheet ss, String title, List<String> headers) async {
    var ws = ss.worksheetByTitle(title);
    if (ws == null) {
      ws = await ss.addWorksheet(title);
      await ws.values.insertRow(1, headers);
    } else {
      // Kiểm tra xem dòng tiêu đề đã có chưa
      final firstRow = await ws.values.row(1);
      if (firstRow.isEmpty) {
        await ws.values.insertRow(1, headers);
      }
    }
    return ws;
  }

  Future<void> _ensureWorksheets(Spreadsheet ss) async {
    await _ensureWorksheet(ss, productsSheetTitle, productsHeaders);
    await _ensureWorksheet(ss, ordersSheetTitle, ordersHeaders);
  }

  /// Tải toàn bộ danh sách sản phẩm từ tab 'Sản phẩm' trên Google Sheets về cập nhật vào SQLite
  Future<int> pullProducts() async {
    final ss = await _getSpreadsheet();
    final ws = await _ensureWorksheet(ss, productsSheetTitle, productsHeaders);

    final allRows = await ws.values.allRows(fromRow: 2);
    if (allRows.isEmpty) return 0;

    final List<Product> products = [];
    for (final row in allRows) {
      if (row.isNotEmpty && row[0].toString().trim().isNotEmpty) {
        try {
          products.add(Product.fromSheetsRow(row));
        } catch (e) {
          debugPrint('Lỗi nạp hàng sản phẩm từ Sheets: $e');
        }
      }
    }

    if (products.isNotEmpty) {
      await DatabaseHelper.instance.upsertProductsFromSheets(products);
    }

    return products.length;
  }

  /// Đẩy một sản phẩm mới thêm vào tab 'Sản phẩm'
  Future<void> pushProduct(Product product) async {
    if (!isConfigured) return;
    try {
      final ss = await _getSpreadsheet();
      final ws = await _ensureWorksheet(ss, productsSheetTitle, productsHeaders);

      // Kiểm tra xem mã vạch đã tồn tại trên Sheet chưa
      final columnA = await ws.values.column(1, fromRow: 2);
      final index = columnA.indexWhere((cell) => cell.toString().trim() == product.barcode.trim());

      if (index != -1) {
        // Cập nhật hàng đã có (hàng = index + 2 do bắt đầu từ hàng 2)
        await ws.values.insertRow(index + 2, product.toSheetsRow());
      } else {
        // Thêm hàng mới ở cuối
        await ws.values.appendRow(product.toSheetsRow());
      }
    } catch (e) {
      debugPrint('Lỗi đẩy sản phẩm lên Sheets: $e');
    }
  }

  /// Đẩy các đơn hàng chưa đồng bộ lên tab 'Đơn hàng'
  Future<int> pushUnsyncedOrders() async {
    if (!isConfigured) return 0;

    final unsynced = await DatabaseHelper.instance.getUnsyncedOrders();
    if (unsynced.isEmpty) return 0;

    final ss = await _getSpreadsheet();
    final ws = await _ensureWorksheet(ss, ordersSheetTitle, ordersHeaders);

    final List<List<dynamic>> rows = unsynced.map((o) => o.toSheetsRow()).toList();
    await ws.values.appendRows(rows);

    await DatabaseHelper.instance.markOrdersSynced(unsynced.map((o) => o.id).toList());
    return unsynced.length;
  }

  /// Đồng bộ hai chiều toàn diện
  Future<SyncResult> syncAll() async {
    if (!isConfigured) {
      return SyncResult(success: false, message: 'Chưa cấu hình Google Sheets trong Cài đặt.');
    }

    try {
      final pulledCount = await pullProducts();
      final pushedOrdersCount = await pushUnsyncedOrders();

      return SyncResult(
        success: true,
        message: 'Đồng bộ thành công ($pulledCount sản phẩm, $pushedOrdersCount đơn hàng)',
        pulledProducts: pulledCount,
        pushedOrders: pushedOrdersCount,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        message: 'Lỗi đồng bộ: ${e.toString()}',
      );
    }
  }
}

class SyncResult {
  final bool success;
  final String message;
  final int pulledProducts;
  final int pushedOrders;

  SyncResult({
    required this.success,
    required this.message,
    this.pulledProducts = 0,
    this.pushedOrders = 0,
  });
}
