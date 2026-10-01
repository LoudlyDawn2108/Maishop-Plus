import 'package:flutter_test/flutter_test.dart';
import 'package:maishop_plus/models/models.dart';
import 'package:maishop_plus/utils/currency_utils.dart';

void main() {
  group('CurrencyUtils Tests', () {
    test('Định dạng tiền tệ VNĐ chuẩn', () {
      expect(CurrencyUtils.formatVND(0), '0 ₫');
      expect(CurrencyUtils.formatVND(10000), contains('10'));
      expect(CurrencyUtils.formatVND(500000), contains('500'));
      expect(CurrencyUtils.formatVND(1250000), contains('1'));
    });

    test('Phân tích chuỗi số tiền VNĐ', () {
      expect(CurrencyUtils.parseVND('15.000'), 15000);
      expect(CurrencyUtils.parseVND('500.000 ₫'), 500000);
      expect(CurrencyUtils.parseVND(' 20,000 đ '), 20000);
      expect(CurrencyUtils.parseVND(''), 0);
    });

    test('Bỏ dấu tiếng Việt tìm kiếm không dấu', () {
      expect(CurrencyUtils.removeDiacritics('Mì Hảo Hảo tôm chua cay'), 'mi hao hao tom chua cay');
      expect(CurrencyUtils.removeDiacritics('Nước Mắm Nam Ngư'), 'nuoc mam nam ngu');
      expect(CurrencyUtils.removeDiacritics('Đường cát'), 'duong cat');
    });

    test('Gợi ý tiền khách đưa thông minh', () {
      final suggestions = CurrencyUtils.getSuggestedPayments(63000);
      expect(suggestions, contains(63000)); // Đúng tiền
      expect(suggestions.every((amt) => amt >= 63000), isTrue);
      expect(suggestions, contains(70000));
      expect(suggestions, contains(100000));
    });

    test('Tính toán phân bổ các tờ tiền thối lại', () {
      final breakdown = CurrencyUtils.calculateChangeBreakdown(37000);
      expect(breakdown[20000], 1);
      expect(breakdown[10000], 1);
      expect(breakdown[5000], 1);
      expect(breakdown[2000], 1);

      final summary = CurrencyUtils.formatChangeBreakdown(37000);
      expect(summary, contains('20k'));
      expect(summary, contains('10k'));
      expect(summary, contains('5k'));
      expect(summary, contains('2k'));
    });

    test('Nhận diện mệnh giá tiền Polymer từ OCR', () {
      expect(CurrencyUtils.extractVndDenominationFromOcr('NGAN HANG NHA NUOC 500.000 VIET NAM'), 500000);
      expect(CurrencyUtils.extractVndDenominationFromOcr('100 000 DONG'), 100000);
      expect(CurrencyUtils.extractVndDenominationFromOcr('To tien 50000'), 50000);
      expect(CurrencyUtils.extractVndDenominationFromOcr('KHONG CO TIEN'), isNull);
    });
  });

  group('Model Serialization Tests', () {
    test('Product toMap & fromMap', () {
      final product = Product(
        barcode: '8934563138164',
        name: 'Mì Hảo Hảo Tôm Chua Cay',
        price: 4500,
        costPrice: 3800,
        unit: 'Gói',
        stock: 50,
      );

      final map = product.toMap();
      final restored = Product.fromMap(map);

      expect(restored.barcode, product.barcode);
      expect(restored.name, product.name);
      expect(restored.price, 4500);
      expect(restored.costPrice, 3800);
      expect(restored.unit, 'Gói');
      expect(restored.stock, 50);
    });

    test('Product toSheetsRow & fromSheetsRow', () {
      final product = Product(
        barcode: '8935049501503',
        name: 'Coca Cola 320ml',
        price: 10000,
        unit: 'Lon',
        stock: 24,
      );

      final row = product.toSheetsRow();
      expect(row[0], '8935049501503');
      expect(row[1], 'Coca Cola 320ml');
      expect(row[2], 10000);

      final fromRow = Product.fromSheetsRow(row);
      expect(fromRow.barcode, '8935049501503');
      expect(fromRow.name, 'Coca Cola 320ml');
      expect(fromRow.price, 10000);
      expect(fromRow.unit, 'Lon');
    });

    test('CartItem & Order calculation', () {
      final p1 = Product(barcode: '111', name: 'Bánh mì', price: 15000, unit: 'Cái');
      final p2 = Product(barcode: '222', name: 'Nước suối', price: 5000, unit: 'Chai');

      final item1 = CartItem(product: p1, quantity: 2); // 30.000
      final item2 = CartItem(product: p2, quantity: 3); // 15.000

      expect(item1.subtotal, 30000);
      expect(item2.subtotal, 15000);

      final order = Order(
        id: 'DH-TEST-001',
        items: [item1, item2],
        totalAmount: item1.subtotal + item2.subtotal,
        customerPaid: 50000,
        changeAmount: 5000,
      );

      expect(order.totalAmount, 45000);
      expect(order.changeAmount, 5000);
      expect(order.itemsSummary, contains('Bánh mì (x2)'));
      expect(order.itemsSummary, contains('Nước suối (x3)'));

      final sheetRow = order.toSheetsRow();
      expect(sheetRow[0], 'DH-TEST-001');
      expect(sheetRow[3], 45000);
      expect(sheetRow[4], 50000);
      expect(sheetRow[5], 5000);
    });
  });
}
