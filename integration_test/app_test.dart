import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maishop_plus/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Xác minh toàn bộ các tính năng không dùng camera trên thiết bị thật', (tester) async {
    // 1. Khởi chạy ứng dụng
    await tester.pumpWidget(const MaiShopApp());
    await tester.pumpAndSettle();

    // Xác nhận đã vào màn hình chính với thanh điều hướng
    expect(find.text('Thu ngân'), findsOneWidget);
    expect(find.text('Kho hàng'), findsOneWidget);
    expect(find.text('Lịch sử'), findsOneWidget);
    expect(find.text('Cài đặt'), findsOneWidget);

    // ==========================================
    // 2. PHÂN HỆ KHO HÀNG & ĐĂNG KÝ SẢN PHẨM MỚI
    // ==========================================
    // Chuyển sang Tab Kho hàng
    await tester.tap(find.text('Kho hàng'));
    await tester.pumpAndSettle();
    expect(find.text('Kho hàng & Danh mục'), findsOneWidget);

    // Bấm nút nổi "Đăng ký sản phẩm"
    final addProductBtn = find.text('Đăng ký sản phẩm');
    expect(addProductBtn, findsOneWidget);
    await tester.tap(addProductBtn);
    await tester.pumpAndSettle();

    // Màn hình Đăng ký sản phẩm mới
    expect(find.text('Đăng ký sản phẩm mới'), findsOneWidget);

    // Nhập mã vạch sản phẩm 1: Coca Cola
    final barcodeField = find.widgetWithText(TextFormField, 'Mã vạch (Barcode) *');
    await tester.enterText(barcodeField, '8935049501503');
    await tester.pumpAndSettle();

    // Nhập tên sản phẩm
    final nameField = find.widgetWithText(TextFormField, 'Tên sản phẩm *');
    await tester.enterText(nameField, 'Coca Cola 320ml');
    await tester.pumpAndSettle();

    // Nhập giá bán
    final priceField = find.widgetWithText(TextFormField, 'Giá bán (VNĐ) *');
    await tester.enterText(priceField, '10000');
    await tester.pumpAndSettle();

    // Nhập tồn kho
    final stockField = find.widgetWithText(TextFormField, 'Số lượng tồn kho');
    await tester.enterText(stockField, '24');
    await tester.pumpAndSettle();

    // Chọn đơn vị Lon
    await tester.tap(find.text('Lon'));
    await tester.pumpAndSettle();

    // Bấm Lưu vào kho
    final saveBtn1 = find.text('LƯU VÀO KHO HÀNG');
    await tester.tap(saveBtn1);
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Xác nhận đã quay lại danh sách kho và có Coca Cola 320ml
    expect(find.text('Coca Cola 320ml'), findsOneWidget);
    expect(find.text('8935049501503'), findsOneWidget);

    // Thêm sản phẩm 2: Nước khoáng Aquafina
    await tester.tap(find.text('Đăng ký sản phẩm'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Mã vạch (Barcode) *'), '8934588063053');
    await tester.enterText(find.widgetWithText(TextFormField, 'Tên sản phẩm *'), 'Nước Aquafina 500ml');
    await tester.enterText(find.widgetWithText(TextFormField, 'Giá bán (VNĐ) *'), '5000');
    await tester.enterText(find.widgetWithText(TextFormField, 'Số lượng tồn kho'), '50');
    await tester.tap(find.text('Chai'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('LƯU VÀO KHO HÀNG'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('Nước Aquafina 500ml'), findsOneWidget);

    // ==========================================
    // 3. TÌM KIẾM & SẮP XẾP SẢN PHẨM TRONG KHO
    // ==========================================
    final searchInput = find.widgetWithText(TextField, 'Tìm theo tên hoặc mã vạch...');
    // Tìm kiếm không dấu "coca"
    await tester.enterText(searchInput, 'coca');
    await tester.pumpAndSettle();
    expect(find.text('Coca Cola 320ml'), findsOneWidget);
    expect(find.text('Nước Aquafina 500ml'), findsNothing);

    // Xóa tìm kiếm
    await tester.enterText(searchInput, '');
    await tester.pumpAndSettle();
    expect(find.text('Coca Cola 320ml'), findsOneWidget);
    expect(find.text('Nước Aquafina 500ml'), findsOneWidget);

    // Sắp xếp theo giá cao -> thấp
    await tester.tap(find.byTooltip('Sắp xếp danh sách'));
    await tester.pumpAndSettle();
    expect(find.text('Sắp xếp danh sách theo'), findsOneWidget);
    await tester.tap(find.text('Giá cao → thấp'));
    await tester.pumpAndSettle();

    // ==========================================
    // 4. THU NGÂN (POS) & TÍNH TIỀN GIỎ HÀNG
    // ==========================================
    await tester.tap(find.text('Thu ngân'));
    await tester.pumpAndSettle();

    // Nhập mã vạch Coca Cola thủ công
    final manualCodeInput = find.widgetWithText(TextField, 'Nhập mã vạch thủ công...');
    await tester.enterText(manualCodeInput, '8935049501503');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // Xác nhận Coca Cola đã vào giỏ hàng
    expect(find.text('Coca Cola 320ml'), findsOneWidget);

    // Tăng số lượng lên 2
    final addQtyBtn = find.byIcon(Icons.add_rounded).first;
    await tester.tap(addQtyBtn);
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget); // SL = 2

    // Thêm món không có mã vạch (Hàng lẻ)
    await tester.tap(find.text('Hàng lẻ'));
    await tester.pumpAndSettle();
    expect(find.text('Thêm hàng không mã'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Tên mặt hàng *'), 'Rau muống');
    await tester.enterText(find.widgetWithText(TextField, 'Đơn giá (VNĐ) *'), '10000');
    await tester.tap(find.text('Thêm vào giỏ'));
    await tester.pumpAndSettle();

    // Tổng tiền hiện tại: Coca (2 x 10k) + Rau (1 x 10k) = 30.000 ₫
    expect(find.text('Rau muống'), findsOneWidget);

    // Bấm nút THANH TOÁN
    final checkoutBtn = find.text('THANH TOÁN');
    await tester.tap(checkoutBtn);
    await tester.pumpAndSettle();

    // ==========================================
    // 5. MODAL THANH TOÁN, TÍNH TIỀN THỪA & HOÀN TẤT
    // ==========================================
    expect(find.text('Thanh toán hóa đơn'), findsOneWidget);
    expect(find.text('TỔNG TIỀN:'), findsOneWidget);

    // Bấm chip "+50k" (khách đưa tờ 50.000 ₫)
    await tester.tap(find.text('+50k'));
    await tester.pumpAndSettle();

    // Tiền thối lại phải là 20.000 ₫
    expect(find.text('TIỀN THỐI LẠI:'), findsOneWidget);
    expect(find.textContaining('1 tờ 20k'), findsOneWidget);

    // Bấm HOÀN TẤT & LƯU ĐƠN
    await tester.tap(find.text('HOÀN TẤT & LƯU ĐƠN'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Xác nhận giỏ hàng đã reset trống
    expect(find.text('Quét mã vạch sản phẩm để tính tiền'), findsOneWidget);

    // ==========================================
    // 6. LỊCH SỬ ĐƠN HÀNG VÀ DOANH THU
    // ==========================================
    await tester.tap(find.text('Lịch sử'));
    await tester.pumpAndSettle();

    expect(find.text('Lịch sử bán hàng'), findsOneWidget);
    expect(find.text('Doanh thu hôm nay'), findsOneWidget);
    expect(find.text('1 đơn'), findsOneWidget);

    // Bấm vào đơn hàng để xem chi tiết
    await tester.tap(find.textContaining('Coca Cola 320ml').first);
    await tester.pumpAndSettle();
    expect(find.text('Danh sách mặt hàng:'), findsOneWidget);
    await tester.tap(find.text('Đóng'));
    await tester.pumpAndSettle();

    // ==========================================
    // 7. MÀN HÌNH CÀI ĐẶT
    // ==========================================
    await tester.tap(find.text('Cài đặt'));
    await tester.pumpAndSettle();
    expect(find.text('Cài đặt hệ thống'), findsOneWidget);
    expect(find.text('Apps Script (Khuyên dùng)'), findsOneWidget);
    expect(find.text('Google Apps Script Web App URL *'), findsOneWidget);

    // Mở xem hướng dẫn và mã script
    await tester.tap(find.text('Lấy mã script & Xem hướng dẫn triển khai'));
    await tester.pumpAndSettle();
    expect(find.text('Mã Script & Hướng dẫn'), findsOneWidget);
    await tester.tap(find.text('Đóng'));
    await tester.pumpAndSettle();

    debugPrint('=== TẤT CẢ CÁC TÍNH NĂNG ĐÃ ĐƯỢC XÁC MINH THÀNH CÔNG TRÊN THIẾT BỊ THẬT ===');
  });
}
