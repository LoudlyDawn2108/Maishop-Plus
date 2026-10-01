import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../data/database_helper.dart';
import '../services/sheets_service.dart';

class InventoryProvider extends ChangeNotifier {
  List<Product> _products = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  String _searchQuery = '';
  ProductSortOption _sortOption = ProductSortOption.nameAsc;
  DateTime? _lastSyncTime;
  String? _syncMessage;

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String get searchQuery => _searchQuery;
  ProductSortOption get sortOption => _sortOption;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get syncMessage => _syncMessage;

  InventoryProvider() {
    loadProducts();
  }

  /// Nạp danh sách sản phẩm từ DB cục bộ theo tìm kiếm và sắp xếp
  Future<void> loadProducts() async {
    _isLoading = true;
    notifyListeners();

    try {
      _products = await DatabaseHelper.instance.getProducts(
        query: _searchQuery,
        sortOption: _sortOption,
      );
    } catch (e) {
      debugPrint('Lỗi tải sản phẩm: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cập nhật từ khóa tìm kiếm
  void setSearchQuery(String query) {
    _searchQuery = query;
    loadProducts();
  }

  /// Cập nhật tiêu chí sắp xếp
  void setSortOption(ProductSortOption option) {
    _sortOption = option;
    loadProducts();
  }

  /// Đăng ký sản phẩm mới độc lập vào kho
  Future<bool> addProduct(Product product) async {
    try {
      await DatabaseHelper.instance.insertProduct(product);
      await loadProducts();

      // Đồng bộ ngầm lên Google Sheets nếu đã kết nối
      if (SheetsService.instance.isConfigured) {
        SheetsService.instance.pushProduct(product).catchError((err) {
          debugPrint('Đồng bộ sản phẩm lên Sheets lỗi: $err');
        });
      }

      return true;
    } catch (e) {
      debugPrint('Lỗi thêm sản phẩm: $e');
      return false;
    }
  }

  /// Cập nhật thông tin sản phẩm (giá, tồn kho, tên...)
  Future<bool> updateProduct(Product product) async {
    try {
      await DatabaseHelper.instance.updateProduct(product);
      await loadProducts();

      if (SheetsService.instance.isConfigured) {
        SheetsService.instance.pushProduct(product).catchError((err) {
          debugPrint('Cập nhật sản phẩm lên Sheets lỗi: $err');
        });
      }

      return true;
    } catch (e) {
      debugPrint('Lỗi cập nhật sản phẩm: $e');
      return false;
    }
  }

  /// Xóa sản phẩm khỏi kho
  Future<bool> deleteProduct(String barcode) async {
    try {
      await DatabaseHelper.instance.deleteProduct(barcode);
      await loadProducts();
      return true;
    } catch (e) {
      debugPrint('Lỗi xóa sản phẩm: $e');
      return false;
    }
  }

  /// Tra cứu sản phẩm theo mã vạch từ SQLite
  Future<Product?> findByBarcode(String barcode) async {
    return await DatabaseHelper.instance.getProductByBarcode(barcode);
  }

  /// Đồng bộ với Google Sheets
  Future<SyncResult> syncWithSheets() async {
    _isSyncing = true;
    _syncMessage = null;
    notifyListeners();

    try {
      final result = await SheetsService.instance.syncAll();
      _syncMessage = result.message;
      if (result.success) {
        _lastSyncTime = DateTime.now();
        await loadProducts();
      }
      return result;
    } catch (e) {
      _syncMessage = 'Lỗi đồng bộ: $e';
      return SyncResult(success: false, message: e.toString());
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}
