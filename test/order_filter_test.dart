import 'package:flutter_test/flutter_test.dart';
import 'package:maishop_plus/models/models.dart';
import 'package:maishop_plus/utils/order_stats_helper.dart';

void main() {
  group('OrderStatsHelper Date Range & Filter Tests', () {
    // Reference date: Wednesday 15/10/2026 14:30:00
    final now = DateTime(2026, 10, 15, 14, 30, 0);

    final orderToday = Order(
      id: 'ORD_TODAY',
      createdAt: DateTime(2026, 10, 15, 10, 0, 0),
      items: [
        CartItem(
          product: Product(barcode: '111', name: 'Coca Cola 320ml', price: 10000),
          quantity: 2,
        ),
      ],
      totalAmount: 20000,
      customerPaid: 20000,
      changeAmount: 0,
      paymentMethod: 'TIEN_MAT',
    );

    final orderThisWeek = Order(
      id: 'ORD_THIS_WEEK', // Monday 12/10/2026
      createdAt: DateTime(2026, 10, 12, 9, 0, 0),
      items: [
        CartItem(
          product: Product(barcode: '222', name: 'Bánh mì sandwich', price: 15000),
          quantity: 1,
        ),
      ],
      totalAmount: 15000,
      customerPaid: 20000,
      changeAmount: 5000,
      paymentMethod: 'CHUYEN_KHOAN',
    );

    final order5DaysAgo = Order(
      id: 'ORD_5_DAYS_AGO', // 10/10/2026 (Saturday of previous week, but within 7 days & this month)
      createdAt: DateTime(2026, 10, 10, 16, 0, 0),
      items: [
        CartItem(
          product: Product(barcode: '333', name: 'Sữa tươi Vinamilk', price: 30000),
          quantity: 2,
        ),
      ],
      totalAmount: 60000,
      customerPaid: 100000,
      changeAmount: 40000,
      paymentMethod: 'TIEN_MAT',
    );

    final order20DaysAgo = Order(
      id: 'ORD_20_DAYS_AGO', // 25/09/2026 (20 days ago, last month, but within 30 days)
      createdAt: DateTime(2026, 9, 25, 11, 0, 0),
      items: [
        CartItem(
          product: Product(barcode: '444', name: 'Mì Hảo Hảo tôm chua cay', price: 5000),
          quantity: 4,
        ),
      ],
      totalAmount: 20000,
      customerPaid: 20000,
      changeAmount: 0,
      paymentMethod: 'TIEN_MAT',
    );

    final order45DaysAgo = Order(
      id: 'ORD_45_DAYS_AGO', // 31/08/2026 (over 30 days ago)
      createdAt: DateTime(2026, 8, 31, 8, 0, 0),
      items: [
        CartItem(
          product: Product(barcode: '555', name: 'Nước mắm Nam Ngư 500ml', price: 40000),
          quantity: 1,
        ),
      ],
      totalAmount: 40000,
      customerPaid: 50000,
      changeAmount: 10000,
      paymentMethod: 'CHUYEN_KHOAN',
    );

    final allOrders = [
      orderToday,
      orderThisWeek,
      order5DaysAgo,
      order20DaysAgo,
      order45DaysAgo,
    ];

    test('Lọc theo Hôm nay', () {
      final filtered = OrderStatsHelper.filterOrders(
        allOrders,
        OrderTimeFilter.today,
        referenceNow: now,
      );
      expect(filtered.length, 1);
      expect(filtered.first.id, 'ORD_TODAY');
    });

    test('Lọc theo Tuần này (Thứ Hai 12/10 đến Chủ Nhật 18/10)', () {
      final filtered = OrderStatsHelper.filterOrders(
        allOrders,
        OrderTimeFilter.thisWeek,
        referenceNow: now,
      );
      // orderToday (15/10) và orderThisWeek (12/10)
      expect(filtered.length, 2);
      expect(filtered.map((e) => e.id), containsAll(['ORD_TODAY', 'ORD_THIS_WEEK']));
    });

    test('Lọc theo Tháng này (01/10 đến 31/10)', () {
      final filtered = OrderStatsHelper.filterOrders(
        allOrders,
        OrderTimeFilter.thisMonth,
        referenceNow: now,
      );
      // orderToday, orderThisWeek, order5DaysAgo đều trong tháng 10
      expect(filtered.length, 3);
      expect(filtered.map((e) => e.id), containsAll(['ORD_TODAY', 'ORD_THIS_WEEK', 'ORD_5_DAYS_AGO']));
    });

    test('Lọc theo 7 ngày qua (09/10 đến 15/10)', () {
      final filtered = OrderStatsHelper.filterOrders(
        allOrders,
        OrderTimeFilter.last7Days,
        referenceNow: now,
      );
      expect(filtered.length, 3);
      expect(filtered.map((e) => e.id), containsAll(['ORD_TODAY', 'ORD_THIS_WEEK', 'ORD_5_DAYS_AGO']));
    });

    test('Lọc theo 30 ngày qua (16/09 đến 15/10)', () {
      final filtered = OrderStatsHelper.filterOrders(
        allOrders,
        OrderTimeFilter.last30Days,
        referenceNow: now,
      );
      // orderToday, orderThisWeek, order5DaysAgo, order20DaysAgo
      expect(filtered.length, 4);
      expect(filtered.map((e) => e.id), containsAll([
        'ORD_TODAY',
        'ORD_THIS_WEEK',
        'ORD_5_DAYS_AGO',
        'ORD_20_DAYS_AGO',
      ]));
    });

    test('Lọc Tất cả', () {
      final filtered = OrderStatsHelper.filterOrders(
        allOrders,
        OrderTimeFilter.all,
        referenceNow: now,
      );
      expect(filtered.length, 5);
    });

    test('Lọc theo từ khóa tìm kiếm (tên sản phẩm không dấu)', () {
      final filtered = OrderStatsHelper.filterOrders(
        allOrders,
        OrderTimeFilter.all,
        searchQuery: 'hao hao',
        referenceNow: now,
      );
      expect(filtered.length, 1);
      expect(filtered.first.id, 'ORD_20_DAYS_AGO');
    });

    test('Tính toán chỉ số thống kê (Doanh thu, Đơn, AOV, Món, Tiền mặt/Chuyển khoản)', () {
      final stats = OrderStatsHelper.calculateStats(allOrders);

      // Total revenue: 20k + 15k + 60k + 20k + 40k = 155k
      expect(stats.totalRevenue, 155000);
      expect(stats.totalOrders, 5);
      // Average: 155000 / 5 = 31000
      expect(stats.averageOrderValue, 31000);
      // Total items: 2 + 1 + 2 + 4 + 1 = 10
      expect(stats.totalItemsSold, 10);
      // Cash revenue: 20k + 60k + 20k = 100k (3 đơn)
      expect(stats.cashRevenue, 100000);
      expect(stats.cashOrdersCount, 3);
      // Transfer revenue: 15k + 40k = 55k (2 đơn)
      expect(stats.transferRevenue, 55000);
      expect(stats.transferOrdersCount, 2);
    });
  });
}
