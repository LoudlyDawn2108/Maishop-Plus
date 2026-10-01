import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/models.dart';
import '../data/database_helper.dart';
import '../services/sheets_service.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  int _customerPaid = 0;
  String _paymentMethod = 'TIEN_MAT';
  bool _soundEnabled = true;

  final AudioPlayer _audioPlayer = AudioPlayer();

  List<CartItem> get items => List.unmodifiable(_items);
  int get customerPaid => _customerPaid;
  String get paymentMethod => _paymentMethod;
  bool get soundEnabled => _soundEnabled;

  int get totalAmount => _items.fold(0, (sum, item) => sum + item.subtotal);
  int get totalQuantity => _items.fold(0, (sum, item) => sum + item.quantity);

  int get changeAmount {
    if (_customerPaid <= 0) return 0;
    return _customerPaid - totalAmount;
  }

  bool get isCustomerPaidEnough => _customerPaid >= totalAmount;

  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
    notifyListeners();
  }

  /// Phát âm thanh bíp và rung phản hồi khi quét mã vạch thành công
  void playBeep() {
    try {
      HapticFeedback.mediumImpact();
      if (_soundEnabled) {
        SystemSound.play(SystemSoundType.click);
      }
    } catch (_) {}
  }

  /// Quét mã vạch và thêm vào giỏ hàng
  /// Trả về Product nếu tìm thấy, hoặc null nếu chưa có trong kho
  Future<Product?> addProductByBarcode(String barcode) async {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) return null;

    final product = await DatabaseHelper.instance.getProductByBarcode(cleanBarcode);
    if (product == null) {
      // Báo rung lỗi nhẹ
      HapticFeedback.vibrate();
      return null;
    }

    // Sản phẩm đã có trong kho -> Thêm vào giỏ
    final existingIndex = _items.indexWhere((i) => i.product.barcode == product.barcode);
    if (existingIndex != -1) {
      _items[existingIndex].quantity++;
    } else {
      _items.add(CartItem(product: product, quantity: 1));
    }

    playBeep();
    notifyListeners();
    return product;
  }

  /// Thêm mặt hàng thủ công không có mã vạch (rau, củ, đá lạnh, trứng...)
  void addManualItem(String name, int price, {int quantity = 1, String unit = 'Cái'}) {
    final customProduct = Product(
      barcode: 'MANUAL_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim().isEmpty ? 'Hàng không mã' : name.trim(),
      price: price,
      unit: unit,
    );

    _items.add(CartItem(product: customProduct, quantity: quantity));
    playBeep();
    notifyListeners();
  }

  /// Cập nhật số lượng mặt hàng
  void updateQuantity(int index, int quantity) {
    if (index < 0 || index >= _items.length) return;
    if (quantity <= 0) {
      _items.removeAt(index);
    } else {
      _items[index].quantity = quantity;
    }
    notifyListeners();
  }

  /// Tăng 1 số lượng
  void incrementQuantity(int index) {
    if (index >= 0 && index < _items.length) {
      _items[index].quantity++;
      notifyListeners();
    }
  }

  /// Giảm 1 số lượng
  void decrementQuantity(int index) {
    if (index >= 0 && index < _items.length) {
      if (_items[index].quantity > 1) {
        _items[index].quantity--;
      } else {
        _items.removeAt(index);
      }
      notifyListeners();
    }
  }

  /// Xoá mặt hàng khỏi giỏ
  void removeItem(int index) {
    if (index >= 0 && index < _items.length) {
      _items.removeAt(index);
      notifyListeners();
    }
  }

  /// Xoá sạch giỏ hàng
  void clearCart() {
    _items.clear();
    _customerPaid = 0;
    _paymentMethod = 'TIEN_MAT';
    notifyListeners();
  }

  /// Đặt số tiền khách đưa
  void setCustomerPaid(int amount) {
    _customerPaid = amount < 0 ? 0 : amount;
    notifyListeners();
  }

  /// Cộng thêm tiền khách đưa (khi bấm các phím chip +10k, +50k...)
  void addCustomerPaid(int delta) {
    _customerPaid = (_customerPaid + delta).clamp(0, 1000000000);
    notifyListeners();
  }

  /// Chọn phương thức thanh toán
  void setPaymentMethod(String method) {
    _paymentMethod = method;
    notifyListeners();
  }

  /// Hoàn tất đơn hàng và lưu vào SQLite + đồng bộ Google Sheets
  Future<Order> completeOrder() async {
    if (_items.isEmpty) {
      throw Exception('Giỏ hàng đang trống.');
    }

    final now = DateTime.now();
    final orderId = 'DH${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

    final order = Order(
      id: orderId,
      createdAt: now,
      items: List.from(_items),
      totalAmount: totalAmount,
      customerPaid: _customerPaid > 0 ? _customerPaid : totalAmount,
      changeAmount: changeAmount,
      paymentMethod: _paymentMethod,
    );

    // Lưu vào SQLite
    await DatabaseHelper.instance.insertOrder(order);

    // Đẩy ngầm lên Google Sheets nếu đã thiết lập
    if (SheetsService.instance.isConfigured) {
      SheetsService.instance.pushUnsyncedOrders().catchError((err) {
        debugPrint('Lỗi đẩy đơn hàng lên Google Sheets: $err');
        return 0;
      });
    }

    // Reset giỏ hàng
    clearCart();

    return order;
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
