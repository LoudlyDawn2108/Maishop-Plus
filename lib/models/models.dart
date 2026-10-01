import 'dart:convert';

/// Tuỳ chọn sắp xếp danh sách sản phẩm
enum ProductSortOption {
  nameAsc('Tên A → Z'),
  nameDesc('Tên Z → A'),
  priceAsc('Giá thấp → cao'),
  priceDesc('Giá cao → thấp'),
  newest('Mới nhất'),
  stockLow('Tồn kho ít nhất');

  final String label;
  const ProductSortOption(this.label);
}

/// Mô hình Sản phẩm
class Product {
  final String barcode;
  final String name;
  final int price; // Giá bán (VNĐ)
  final int? costPrice; // Giá vốn (VNĐ - tuỳ chọn)
  final String unit; // Đơn vị tính (Gói, Lon, Chai, Cái, Kg...)
  final int stock; // Tồn kho
  final String category; // Phân loại / Ghi chú
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.barcode,
    required this.name,
    required this.price,
    this.costPrice,
    this.unit = 'Cái',
    this.stock = 0,
    this.category = 'Chung',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Product copyWith({
    String? barcode,
    String? name,
    int? price,
    int? costPrice,
    String? unit,
    int? stock,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      unit: unit ?? this.unit,
      stock: stock ?? this.stock,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'barcode': barcode,
      'name': name,
      'price': price,
      'cost_price': costPrice,
      'unit': unit,
      'stock': stock,
      'category': category,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      barcode: map['barcode'] as String,
      name: map['name'] as String,
      price: (map['price'] as num).toInt(),
      costPrice: map['cost_price'] != null ? (map['cost_price'] as num).toInt() : null,
      unit: (map['unit'] as String?) ?? 'Cái',
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      category: (map['category'] as String?) ?? 'Chung',
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String) : null,
    );
  }

  /// Chuyển đổi thành hàng dữ liệu cho Google Sheets (Tab Sản phẩm)
  List<dynamic> toSheetsRow() {
    return [
      barcode,
      name,
      price,
      costPrice ?? '',
      unit,
      stock,
      category,
    ];
  }

  /// Tạo Product từ hàng dữ liệu Google Sheets
  factory Product.fromSheetsRow(List<dynamic> row) {
    String barcode = row.isNotEmpty ? row[0].toString().trim() : '';
    String name = row.length > 1 ? row[1].toString().trim() : '';
    int price = row.length > 2 ? int.tryParse(row[2].toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0 : 0;
    int? costPrice = row.length > 3 && row[3].toString().isNotEmpty
        ? int.tryParse(row[3].toString().replaceAll(RegExp(r'[^0-9]'), ''))
        : null;
    String unit = row.length > 4 && row[4].toString().isNotEmpty ? row[4].toString().trim() : 'Cái';
    int stock = row.length > 5 ? int.tryParse(row[5].toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0 : 0;
    String category = row.length > 6 ? row[6].toString().trim() : 'Chung';

    return Product(
      barcode: barcode,
      name: name,
      price: price,
      costPrice: costPrice,
      unit: unit,
      stock: stock,
      category: category,
    );
  }
}

/// Mặt hàng trong giỏ hàng POS
class CartItem {
  final Product product;
  int quantity;

  CartItem({
    required this.product,
    this.quantity = 1,
  });

  int get subtotal => product.price * quantity;

  Map<String, dynamic> toMap() {
    return {
      'barcode': product.barcode,
      'name': product.name,
      'price': product.price,
      'unit': product.unit,
      'quantity': quantity,
      'subtotal': subtotal,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      product: Product(
        barcode: map['barcode'] as String,
        name: map['name'] as String,
        price: (map['price'] as num).toInt(),
        unit: (map['unit'] as String?) ?? 'Cái',
      ),
      quantity: (map['quantity'] as num).toInt(),
    );
  }
}

/// Đơn hàng bán ra
class Order {
  final String id;
  final DateTime createdAt;
  final List<CartItem> items;
  final int totalAmount;
  final int customerPaid;
  final int changeAmount;
  final String paymentMethod; // 'TIEN_MAT' hoặc 'CHUYEN_KHOAN'
  final bool isSynced;

  Order({
    required this.id,
    DateTime? createdAt,
    required this.items,
    required this.totalAmount,
    required this.customerPaid,
    required this.changeAmount,
    this.paymentMethod = 'TIEN_MAT',
    this.isSynced = false,
  }) : createdAt = createdAt ?? DateTime.now();

  Order copyWith({
    String? id,
    DateTime? createdAt,
    List<CartItem>? items,
    int? totalAmount,
    int? customerPaid,
    int? changeAmount,
    String? paymentMethod,
    bool? isSynced,
  }) {
    return Order(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      customerPaid: customerPaid ?? this.customerPaid,
      changeAmount: changeAmount ?? this.changeAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  String get itemsSummary {
    return items.map((e) => '${e.product.name} (x${e.quantity})').join(', ');
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'items_json': jsonEncode(items.map((e) => e.toMap()).toList()),
      'total_amount': totalAmount,
      'customer_paid': customerPaid,
      'change_amount': changeAmount,
      'payment_method': paymentMethod,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory Order.fromMap(Map<String, dynamic> map) {
    List<CartItem> parsedItems = [];
    if (map['items_json'] != null) {
      final List decoded = jsonDecode(map['items_json'] as String);
      parsedItems = decoded.map((e) => CartItem.fromMap(e as Map<String, dynamic>)).toList();
    }

    return Order(
      id: map['id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      items: parsedItems,
      totalAmount: (map['total_amount'] as num).toInt(),
      customerPaid: (map['customer_paid'] as num).toInt(),
      changeAmount: (map['change_amount'] as num).toInt(),
      paymentMethod: (map['payment_method'] as String?) ?? 'TIEN_MAT',
      isSynced: (map['is_synced'] as int?) == 1,
    );
  }

  /// Chuyển đổi thành hàng dữ liệu cho Google Sheets (Tab Đơn hàng)
  List<dynamic> toSheetsRow() {
    return [
      id,
      '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}:${createdAt.second.toString().padLeft(2, '0')}',
      itemsSummary,
      totalAmount,
      customerPaid,
      changeAmount,
      paymentMethod == 'CHUYEN_KHOAN' ? 'Chuyển khoản' : 'Tiền mặt',
    ];
  }
}
