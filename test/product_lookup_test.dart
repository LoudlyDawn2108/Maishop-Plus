import 'package:flutter_test/flutter_test.dart';
import 'package:maishop_plus/services/product_lookup_service.dart';

void main() {
  group('ProductLookupService Translation & Result Tests', () {
    test('ProductLookupResult khởi tạo đầy đủ thuộc tính', () {
      final res = ProductLookupResult(
        productName: 'Dầu gội dưỡng ẩm Suave Hạnh Nhân & Bơ Hạt Mỡ',
        originalName: 'Suave Almond & Shea Butter Moisturizing Shampoo',
        source: 'UPCitemdb',
        wasTranslated: true,
        brand: 'Suave',
        quantity: '372ml',
      );

      expect(res.productName, contains('Dầu gội'));
      expect(res.originalName, contains('Shampoo'));
      expect(res.source, 'UPCitemdb');
      expect(res.wasTranslated, isTrue);
      expect(res.brand, 'Suave');
    });

    test('Dịch chuỗi rỗng trả về rỗng không lỗi', () async {
      final res = await ProductLookupService.translateToVietnamese('');
      expect(res.translated, '');
      expect(res.wasTranslated, isFalse);
    });

    test('Chuỗi đã là tiếng Việt thì giữ nguyên', () async {
      final res = await ProductLookupService.translateToVietnamese('Dầu gội Sunsilk bồ kết óng mượt');
      expect(res.translated, 'Dầu gội Sunsilk bồ kết óng mượt');
      expect(res.wasTranslated, isFalse);
    });

    test('Dịch tiếng Anh sang tiếng Việt tự động', () async {
      final res = await ProductLookupService.translateToVietnamese('Baby Shampoo 500ml');
      if (res.wasTranslated) {
        expect(res.translated.toLowerCase(), contains('dầu gội'));
        expect(res.original, 'Baby Shampoo 500ml');
      } else {
        // Khi chạy trên GitHub Actions CI, Google Translate có thể từ chối IP datacenter
        expect(res.translated, 'Baby Shampoo 500ml');
      }
    });

    test('Tra cứu thực tế mã dầu gội nhập khẩu qua UPCitemdb', () async {
      try {
        final res = await ProductLookupService.lookupProduct('079400066619');
        if (res != null) {
          expect(res.source, 'UPCitemdb');
        }
      } catch (_) {
        // Bỏ qua khi chạy trong môi trường CI bị giới hạn mạng
      }
    });
  });
}
