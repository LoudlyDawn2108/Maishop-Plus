import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:gsheets/gsheets.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import '../data/database_helper.dart';

enum SheetsConnectionMode {
  appsScript,
  serviceAccount,
}

class SheetsService {
  static final SheetsService instance = SheetsService._init();
  GSheets? _gsheets;
  Spreadsheet? _spreadsheet;

  String? _webAppUrl =
      'https://script.google.com/macros/s/AKfycbwGvl2BLP9gZBIkCURaqL_gWWU-eSOGeZrNb7PzpmkwPbxwL4tgur-YH6YZhRUo-nHq/exec';
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
    try {
      final settings = await DatabaseHelper.instance.getAllSettings();
      _webAppUrl = settings['web_app_url'] ?? _webAppUrl;
      _spreadsheetId = settings['sheets_id'];
      _credentialsJson = settings['service_account_json'];

      if (activeMode == SheetsConnectionMode.serviceAccount) {
        _initGSheets();
      }
    } catch (e) {
      debugPrint('Lỗi nạp cấu hình Google Sheets: $e');
    }
  }

  /// Lưu cấu hình Google Apps Script Web App
  Future<void> saveAppsScriptConfig(String url) async {
    _webAppUrl = url.trim();
    await DatabaseHelper.instance.setSetting('web_app_url', _webAppUrl);
  }

  /// Lưu cấu hình Service Account JSON
  Future<void> saveServiceAccountConfig({
    required String spreadsheetId,
    required String credentialsJson,
  }) async {
    _spreadsheetId = spreadsheetId.trim();
    _credentialsJson = credentialsJson.trim();

    await DatabaseHelper.instance.setSetting('sheets_id', _spreadsheetId);
    await DatabaseHelper.instance.setSetting('service_account_json', _credentialsJson);

    _initGSheets();
  }

  /// Xóa cấu hình để chuyển phương thức
  Future<void> clearConfig() async {
    _webAppUrl = null;
    _spreadsheetId = null;
    _credentialsJson = null;
    _gsheets = null;
    _spreadsheet = null;

    await DatabaseHelper.instance.setSetting('web_app_url', null);
    await DatabaseHelper.instance.setSetting('sheets_id', null);
    await DatabaseHelper.instance.setSetting('service_account_json', null);
  }

  String? get webAppUrl => _webAppUrl;
  String? get spreadsheetId => _spreadsheetId;
  String? get credentialsJson => _credentialsJson;

  SheetsConnectionMode get activeMode {
    if (_webAppUrl != null && _webAppUrl!.isNotEmpty) {
      return SheetsConnectionMode.appsScript;
    }
    return SheetsConnectionMode.serviceAccount;
  }

  bool get isConfigured {
    if (_webAppUrl != null && _webAppUrl!.isNotEmpty) {
      return true;
    }
    return _spreadsheetId != null &&
        _spreadsheetId!.isNotEmpty &&
        _credentialsJson != null &&
        _credentialsJson!.isNotEmpty;
  }

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
    if (_credentialsJson == null || _credentialsJson!.isEmpty) return;
    try {
      _gsheets = GSheets(_credentialsJson!);
      _spreadsheet = null;
    } catch (e) {
      debugPrint('Lỗi khởi tạo GSheets: $e');
    }
  }

  Future<Spreadsheet> _getSpreadsheet() async {
    if (_spreadsheet != null) return _spreadsheet!;
    if (_spreadsheetId == null || _credentialsJson == null) {
      throw Exception('Chưa cấu hình Google Sheets ID hoặc Service Account JSON.');
    }
    _initGSheets();
    _spreadsheet = await _gsheets!.spreadsheet(_spreadsheetId!);
    return _spreadsheet!;
  }

  // ==================== KIỂM TRA KẾT NỐI ====================

  Future<bool> testConnection() async {
    if (activeMode == SheetsConnectionMode.appsScript) {
      if (_webAppUrl == null || _webAppUrl!.isEmpty) {
        throw Exception('Chưa nhập Google Apps Script Web App URL.');
      }

      final uri = Uri.parse('$_webAppUrl?action=test');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return true;
        } else {
          throw Exception(data['message'] ?? data['error'] ?? 'Lỗi từ script');
        }
      } else {
        throw Exception('Mã phản hồi HTTP: ${response.statusCode}');
      }
    } else {
      // Chế độ Service Account
      final ss = await _getSpreadsheet();
      await _ensureWorksheet(ss, productsSheetTitle, productsHeaders);
      await _ensureWorksheet(ss, ordersSheetTitle, ordersHeaders);
      return true;
    }
  }

  Future<Worksheet> _ensureWorksheet(Spreadsheet ss, String title, List<String> headers) async {
    var ws = ss.worksheetByTitle(title);
    if (ws == null) {
      ws = await ss.addWorksheet(title);
      await ws.values.insertRow(1, headers);
    } else {
      final firstRow = await ws.values.row(1);
      if (firstRow.isEmpty) {
        await ws.values.insertRow(1, headers);
      }
    }
    return ws;
  }

  // ==================== ĐỒNG BỘ SẢN PHẨM ====================

  /// Tải sản phẩm từ Google Sheets về máy
  Future<int> pullProducts() async {
    if (!isConfigured) return 0;

    if (activeMode == SheetsConnectionMode.appsScript) {
      final uri = Uri.parse('$_webAppUrl?action=get_products');
      final response = await http.get(uri).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['products'] is List) {
          final List list = data['products'];
          final List<Product> products = list.map((item) {
            return Product(
              barcode: item['barcode'].toString(),
              name: item['name']?.toString() ?? '',
              price: (item['price'] as num?)?.toInt() ?? 0,
              costPrice: (item['cost_price'] as num?)?.toInt(),
              unit: item['unit']?.toString() ?? 'Cái',
              stock: (item['stock'] as num?)?.toInt() ?? 0,
              category: item['category']?.toString() ?? 'Chung',
            );
          }).toList();

          if (products.isNotEmpty) {
            await DatabaseHelper.instance.upsertProductsFromSheets(products);
          }
          return products.length;
        }
      }
      return 0;
    } else {
      // Service Account
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
  }

  /// Đẩy một sản phẩm mới thêm lên Google Sheets
  Future<void> pushProduct(Product product) async {
    if (!isConfigured) return;

    try {
      if (activeMode == SheetsConnectionMode.appsScript) {
        final uri = Uri.parse(_webAppUrl!);
        await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'action': 'save_product',
            'product': product.toMap(),
          }),
        ).timeout(const Duration(seconds: 15));
      } else {
        final ss = await _getSpreadsheet();
        final ws = await _ensureWorksheet(ss, productsSheetTitle, productsHeaders);

        final columnA = await ws.values.column(1, fromRow: 2);
        final index = columnA.indexWhere((cell) => cell.toString().trim() == product.barcode.trim());

        if (index != -1) {
          await ws.values.insertRow(index + 2, product.toSheetsRow());
        } else {
          await ws.values.appendRow(product.toSheetsRow());
        }
      }
    } catch (e) {
      debugPrint('Lỗi đẩy sản phẩm lên Sheets: $e');
    }
  }

  // ==================== ĐỒNG BỘ ĐƠN HÀNG ====================

  /// Đẩy các đơn hàng chưa đồng bộ lên tab 'Đơn hàng'
  Future<int> pushUnsyncedOrders() async {
    if (!isConfigured) return 0;

    final unsynced = await DatabaseHelper.instance.getUnsyncedOrders();
    if (unsynced.isEmpty) return 0;

    if (activeMode == SheetsConnectionMode.appsScript) {
      final uri = Uri.parse(_webAppUrl!);
      final ordersPayload = unsynced.map((o) {
        final dt = o.createdAt;
        final timeStr =
            '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
        return {
          'id': o.id,
          'time': timeStr,
          'items_summary': o.itemsSummary,
          'total_amount': o.totalAmount,
          'customer_paid': o.customerPaid,
          'change_amount': o.changeAmount,
          'payment_method': o.paymentMethod == 'CHUYEN_KHOAN' ? 'Chuyển khoản' : 'Tiền mặt',
        };
      }).toList();

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'push_orders',
          'orders': ordersPayload,
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200 || response.statusCode == 302) {
        await DatabaseHelper.instance.markOrdersSynced(unsynced.map((o) => o.id).toList());
        return unsynced.length;
      }
      return 0;
    } else {
      final ss = await _getSpreadsheet();
      final ws = await _ensureWorksheet(ss, ordersSheetTitle, ordersHeaders);

      final List<List<dynamic>> rows = unsynced.map((o) => o.toSheetsRow()).toList();
      await ws.values.appendRows(rows);

      await DatabaseHelper.instance.markOrdersSynced(unsynced.map((o) => o.id).toList());
      return unsynced.length;
    }
  }

  /// Đồng bộ hai chiều
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

  /// Mã Google Apps Script mẫu để người dùng copy vào Google Sheet
  static const String googleAppsScriptTemplate = r'''
function doGet(e) {
  return handleRequest(e);
}

function doPost(e) {
  return handleRequest(e);
}

function handleRequest(e) {
  var lock = LockService.getScriptLock();
  lock.tryLock(15000);
  try {
    var action = (e && e.parameter) ? e.parameter.action : null;
    var data = null;
    if (e && e.postData && e.postData.contents) {
      try {
        data = JSON.parse(e.postData.contents);
        if (!action && data && data.action) {
          action = data.action;
        }
      } catch(err) {}
    }

    var ss = SpreadsheetApp.getActiveSpreadsheet();

    // 1. Kiểm tra kết nối
    if (action === 'test' || !action) {
      ensureSheets(ss);
      return responseJSON({ success: true, message: 'Kết nối Google Apps Script thành công!' });
    }

    // 2. Lấy danh sách sản phẩm
    if (action === 'get_products') {
      var sheet = ensureProductsSheet(ss);
      var rows = sheet.getDataRange().getValues();
      var products = [];
      for (var i = 1; i < rows.length; i++) {
        var r = rows[i];
        if (r[0] && r[0].toString().trim() !== '') {
          products.push({
            barcode: r[0].toString(),
            name: r[1] ? r[1].toString() : '',
            price: parseInt(r[2]) || 0,
            cost_price: r[3] ? parseInt(r[3]) : null,
            unit: r[4] ? r[4].toString() : 'Cái',
            stock: parseInt(r[5]) || 0,
            category: r[6] ? r[6].toString() : 'Chung'
          });
        }
      }
      return responseJSON({ success: true, products: products });
    }

    // 3. Thêm hoặc cập nhật sản phẩm
    if (action === 'save_product') {
      var sheet = ensureProductsSheet(ss);
      var p = data.product;
      var rows = sheet.getDataRange().getValues();
      var foundRow = -1;
      for (var i = 1; i < rows.length; i++) {
        if (rows[i][0].toString().trim() === p.barcode.toString().trim()) {
          foundRow = i + 1;
          break;
        }
      }

      var rowData = [
        "'" + p.barcode,
        p.name,
        p.price,
        p.cost_price || '',
        p.unit || 'Cái',
        p.stock !== undefined ? p.stock : 0,
        p.category || 'Chung'
      ];

      if (foundRow > 0) {
        sheet.getRange(foundRow, 1, 1, rowData.length).setValues([rowData]);
      } else {
        sheet.appendRow(rowData);
      }
      return responseJSON({ success: true, message: 'Đã lưu sản phẩm' });
    }

    // 4. Đẩy danh sách đơn hàng
    if (action === 'push_orders') {
      var sheet = ensureOrdersSheet(ss);
      var orders = data.orders || [];
      for (var i = 0; i < orders.length; i++) {
        var o = orders[i];
        sheet.appendRow([
          "'" + o.id,
          o.time,
          o.items_summary,
          o.total_amount,
          o.customer_paid,
          o.change_amount,
          o.payment_method
        ]);
      }
      return responseJSON({ success: true, count: orders.length });
    }

    return responseJSON({ success: false, message: 'Action không hợp lệ: ' + action });
  } catch (err) {
    return responseJSON({ success: false, error: err.toString() });
  } finally {
    lock.releaseLock();
  }
}

function responseJSON(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}

function ensureProductsSheet(ss) {
  var sheet = ss.getSheetByName('Sản phẩm');
  if (!sheet) {
    sheet = ss.insertSheet('Sản phẩm');
    sheet.appendRow(['Mã vạch', 'Tên sản phẩm', 'Giá bán (VNĐ)', 'Giá vốn (VNĐ)', 'Đơn vị', 'Tồn kho', 'Ghi chú']);
    sheet.getRange(1, 1, 1, 7).setFontWeight('bold').setBackground('#E0F2F1');
  }
  return sheet;
}

function ensureOrdersSheet(ss) {
  var sheet = ss.getSheetByName('Đơn hàng');
  if (!sheet) {
    sheet = ss.insertSheet('Đơn hàng');
    sheet.appendRow(['Mã đơn', 'Thời gian', 'Chi tiết mặt hàng', 'Tổng tiền (VNĐ)', 'Khách đưa (VNĐ)', 'Tiền thối (VNĐ)', 'Phương thức']);
    sheet.getRange(1, 1, 1, 7).setFontWeight('bold').setBackground('#FFF3E0');
  }
  return sheet;
}

function ensureSheets(ss) {
  ensureProductsSheet(ss);
  ensureOrdersSheet(ss);
}
''';
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
