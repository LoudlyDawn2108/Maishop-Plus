import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ProductLookupService {
  static const String _userAgent = 'MaiShopPlus - Android - Shop Management';

  /// Tra cứu tên sản phẩm từ mã vạch qua cơ sở dữ liệu mở Open Food Facts
  static Future<String?> lookupProductName(String barcode) async {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) return null;

    final url = Uri.parse(
      'https://world.openfoodfacts.org/api/v2/product/$cleanBarcode.json?fields=product_name,product_name_vi,product_name_en,brands,quantity',
    );

    try {
      final response = await http
          .get(url, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['status'] == 1 && data['product'] != null) {
          final product = data['product'] as Map<String, dynamic>;

          String? name = product['product_name_vi'] as String?;
          name ??= product['product_name'] as String?;
          name ??= product['product_name_en'] as String?;

          final brand = product['brands'] as String?;
          final quantity = product['quantity'] as String?;

          if (name != null && name.trim().isNotEmpty) {
            String fullName = name.trim();
            if (brand != null && brand.trim().isNotEmpty && !fullName.toLowerCase().contains(brand.toLowerCase())) {
              fullName = '${brand.trim()} $fullName';
            }
            if (quantity != null && quantity.trim().isNotEmpty && !fullName.contains(quantity.trim())) {
              fullName = '$fullName $quantity';
            }
            return fullName;
          }
        }
      }
    } catch (e) {
      debugPrint('Lỗi tra cứu mã vạch trực tuyến: $e');
    }

    return null;
  }
}
