import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Kết quả tra cứu mã vạch từ các cơ sở dữ liệu mở
class ProductLookupResult {
  final String productName; // Tên đã dịch sang tiếng Việt (hoặc tiếng Việt sẵn có)
  final String? originalName; // Tên gốc tiếng nước ngoài (nếu có bản dịch)
  final String source; // Tên nguồn: 'Open Beauty Facts', 'Open Products Facts', 'UPCitemdb', 'Open Food Facts'
  final bool wasTranslated;
  final String? brand;
  final String? quantity;

  ProductLookupResult({
    required this.productName,
    this.originalName,
    required this.source,
    this.wasTranslated = false,
    this.brand,
    this.quantity,
  });
}

class ProductLookupService {
  static const String _userAgent =
      'MaiShopPlus - Android - Grocery & Cosmetics POS/1.0 (contact: support@maishop.vn)';

  /// Tự động dịch một chuỗi văn bản (tên hàng hóa) sang tiếng Việt
  /// Giữ nguyên nếu đã là tiếng Việt hoặc dịch không thành công
  static Future<({String translated, bool wasTranslated, String? original})> translateToVietnamese(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) {
      return (translated: cleanText, wasTranslated: false, original: null);
    }

    try {
      final url = Uri.parse(
        'https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=vi&dt=t&q=${Uri.encodeComponent(cleanText)}',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36',
      }).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data is List && data.isNotEmpty && data[0] is List) {
          final buffer = StringBuffer();
          for (var part in data[0]) {
            if (part is List && part.isNotEmpty && part[0] != null) {
              buffer.write(part[0]);
            }
          }
          final translated = buffer.toString().trim();
          final detectedLang = data.length > 2 && data[2] is String ? data[2] as String : null;

          if (detectedLang == 'vi' || translated.toLowerCase() == cleanText.toLowerCase()) {
            return (translated: cleanText, wasTranslated: false, original: null);
          }

          if (translated.isNotEmpty) {
            return (translated: translated, wasTranslated: true, original: cleanText);
          }
        }
      }
    } catch (e) {
      debugPrint('Lỗi dịch sang tiếng Việt: $e');
    }

    return (translated: cleanText, wasTranslated: false, original: null);
  }

  /// Tra cứu chi tiết sản phẩm qua pipeline đa tầng chạy song song:
  /// 1. Open Beauty Facts (Dầu gội, sữa tắm, xà phòng, mỹ phẩm)
  /// 2. Open Products Facts (Bột giặt, nước giặt, chất tẩy rửa)
  /// 3. UPCitemdb (Hàng nhập khẩu toàn cầu)
  /// 4. Open Food Facts (Bánh kẹo, thực phẩm, gia vị)
  /// Tự động phiên dịch sang tiếng Việt nếu sản phẩm là hàng nhập khẩu
  static Future<ProductLookupResult?> lookupProduct(String barcode) async {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) return null;

    try {
      // Chạy song song các nguồn để tối ưu tốc độ tra cứu tối đa
      final results = await Future.wait([
        _lookupOpenFacts(
          'https://world.openbeautyfacts.org/api/v2/product/$cleanBarcode.json?fields=product_name,product_name_vi,product_name_en,brands,quantity',
          'Open Beauty Facts',
        ),
        _lookupOpenFacts(
          'https://world.openproductsfacts.org/api/v2/product/$cleanBarcode.json?fields=product_name,product_name_vi,product_name_en,brands,quantity',
          'Open Products Facts',
        ),
        _lookupUpcItemDb(cleanBarcode),
        _lookupOpenFacts(
          'https://world.openfoodfacts.org/api/v2/product/$cleanBarcode.json?fields=product_name,product_name_vi,product_name_en,brands,quantity',
          'Open Food Facts',
        ),
      ]);

      // Lấy kết quả hợp lệ đầu tiên theo thứ tự ưu tiên
      for (final res in results) {
        if (res != null && res.productName.trim().isNotEmpty) {
          return res;
        }
      }
    } catch (e) {
      debugPrint('Lỗi tra cứu đa tầng: $e');
    }

    return null;
  }

  /// Tương thích ngược với hàm cũ
  static Future<String?> lookupProductName(String barcode) async {
    final result = await lookupProduct(barcode);
    return result?.productName;
  }

  /// Helper tra cứu họ Open Facts (Food / Beauty / Products)
  static Future<ProductLookupResult?> _lookupOpenFacts(String requestUrl, String sourceName) async {
    try {
      final url = Uri.parse(requestUrl);
      final response = await http
          .get(url, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['status'] == 1 && data['product'] != null) {
          final product = data['product'] as Map<String, dynamic>;

          String? nameVi = product['product_name_vi'] as String?;
          String? nameOther = (product['product_name'] ?? product['product_name_en']) as String?;
          final brand = product['brands'] as String?;
          final quantity = product['quantity'] as String?;

          String rawName = (nameVi != null && nameVi.trim().isNotEmpty) ? nameVi.trim() : (nameOther?.trim() ?? '');
          if (rawName.isEmpty) return null;

          if (brand != null && brand.trim().isNotEmpty && !rawName.toLowerCase().contains(brand.toLowerCase())) {
            rawName = '${brand.trim()} $rawName';
          }
          if (quantity != null && quantity.trim().isNotEmpty && !rawName.contains(quantity.trim())) {
            rawName = '$rawName $quantity';
          }

          // Nếu đã có sẵn tên tiếng Việt từ cộng đồng
          if (nameVi != null && nameVi.trim().isNotEmpty) {
            return ProductLookupResult(
              productName: rawName,
              source: sourceName,
              wasTranslated: false,
              brand: brand,
              quantity: quantity,
            );
          }

          // Tự động dịch sang tiếng Việt nếu là tiếng nước ngoài
          final trans = await translateToVietnamese(rawName);
          return ProductLookupResult(
            productName: trans.translated,
            originalName: trans.wasTranslated ? trans.original : null,
            source: sourceName,
            wasTranslated: trans.wasTranslated,
            brand: brand,
            quantity: quantity,
          );
        }
      }
    } catch (e) {
      debugPrint('Lỗi tra cứu từ $sourceName: $e');
    }
    return null;
  }

  /// Helper tra cứu từ UPCitemdb Trial API
  static Future<ProductLookupResult?> _lookupUpcItemDb(String barcode) async {
    try {
      final url = Uri.parse('https://api.upcitemdb.com/prod/trial/lookup?upc=$barcode');
      final response = await http
          .get(url, headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
            'Accept': 'application/json',
          })
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['code'] == 'OK' && data['items'] is List && (data['items'] as List).isNotEmpty) {
          final item = (data['items'] as List).first as Map<String, dynamic>;
          final title = item['title'] as String?;
          final brand = item['brand'] as String?;

          if (title != null && title.trim().isNotEmpty) {
            String rawName = title.trim();
            final trans = await translateToVietnamese(rawName);

            return ProductLookupResult(
              productName: trans.translated,
              originalName: trans.wasTranslated ? trans.original : null,
              source: 'UPCitemdb',
              wasTranslated: trans.wasTranslated,
              brand: brand,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Lỗi tra cứu từ UPCitemdb: $e');
    }
    return null;
  }
}

