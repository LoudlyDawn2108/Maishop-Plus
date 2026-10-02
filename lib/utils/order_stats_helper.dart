import '../models/models.dart';
import 'currency_utils.dart';

/// Bộ lọc thời gian cho đơn hàng
enum OrderTimeFilter {
  today('Hôm nay'),
  thisWeek('Tuần này'),
  thisMonth('Tháng này'),
  last7Days('7 ngày qua'),
  last30Days('30 ngày qua'),
  all('Tất cả');

  final String label;
  const OrderTimeFilter(this.label);
}

/// Dải thời gian từ đầu ngày đến cuối ngày
class DateRange {
  final DateTime start;
  final DateTime end;

  const DateRange(this.start, this.end);

  bool contains(DateTime date) {
    return (date.isAfter(start) || date.isAtSameMomentAs(start)) &&
        (date.isBefore(end) || date.isAtSameMomentAs(end));
  }
}

/// Kết quả thống kê đơn hàng
class OrderStatistics {
  final int totalRevenue;
  final int totalOrders;
  final int averageOrderValue;
  final int totalItemsSold;
  final int cashRevenue;
  final int transferRevenue;
  final int cashOrdersCount;
  final int transferOrdersCount;

  const OrderStatistics({
    required this.totalRevenue,
    required this.totalOrders,
    required this.averageOrderValue,
    required this.totalItemsSold,
    required this.cashRevenue,
    required this.transferRevenue,
    required this.cashOrdersCount,
    required this.transferOrdersCount,
  });

  factory OrderStatistics.empty() {
    return const OrderStatistics(
      totalRevenue: 0,
      totalOrders: 0,
      averageOrderValue: 0,
      totalItemsSold: 0,
      cashRevenue: 0,
      transferRevenue: 0,
      cashOrdersCount: 0,
      transferOrdersCount: 0,
    );
  }
}

/// Tiện ích hỗ trợ lọc và tính toán thống kê đơn hàng
class OrderStatsHelper {
  /// Lấy dải thời gian tương ứng với bộ lọc
  static DateRange? getDateRange(OrderTimeFilter filter, [DateTime? referenceNow]) {
    final now = referenceNow ?? DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0, 0);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    switch (filter) {
      case OrderTimeFilter.today:
        return DateRange(todayStart, todayEnd);

      case OrderTimeFilter.thisWeek:
        // Thứ Hai đầu tuần (Dart weekday: 1 = Monday, 7 = Sunday)
        final monday = todayStart.subtract(Duration(days: now.weekday - 1));
        final sundayEnd = DateTime(monday.year, monday.month, monday.day + 6, 23, 59, 59, 999);
        return DateRange(monday, sundayEnd);

      case OrderTimeFilter.thisMonth:
        final monthStart = DateTime(now.year, now.month, 1, 0, 0, 0, 0);
        // Ngày cuối cùng của tháng hiện tại
        final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
        return DateRange(monthStart, monthEnd);

      case OrderTimeFilter.last7Days:
        // 7 ngày gần nhất gồm cả hôm nay (từ (hôm nay - 6) đến hết hôm nay)
        final start7 = todayStart.subtract(const Duration(days: 6));
        return DateRange(start7, todayEnd);

      case OrderTimeFilter.last30Days:
        // 30 ngày gần nhất gồm cả hôm nay (từ (hôm nay - 29) đến hết hôm nay)
        final start30 = todayStart.subtract(const Duration(days: 29));
        return DateRange(start30, todayEnd);

      case OrderTimeFilter.all:
        return null;
    }
  }

  /// Lọc danh sách đơn hàng theo mốc thời gian và từ khóa tìm kiếm
  static List<Order> filterOrders(
    List<Order> orders,
    OrderTimeFilter filter, {
    String? searchQuery,
    DateTime? referenceNow,
  }) {
    final range = getDateRange(filter, referenceNow);

    var filtered = orders;

    // Lọc theo mốc thời gian
    if (range != null) {
      filtered = filtered.where((o) => range.contains(o.createdAt)).toList();
    }

    // Lọc theo từ khóa tìm kiếm (mã đơn hoặc tên sản phẩm)
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = CurrencyUtils.removeDiacritics(searchQuery.trim().toLowerCase());
      filtered = filtered.where((o) {
        // Tìm theo mã đơn
        if (o.id.toLowerCase().contains(q)) return true;
        // Tìm theo tên sản phẩm trong đơn
        for (final item in o.items) {
          final pName = CurrencyUtils.removeDiacritics(item.product.name.toLowerCase());
          if (pName.contains(q) || item.product.barcode.contains(q)) {
            return true;
          }
        }
        return false;
      }).toList();
    }

    return filtered;
  }

  /// Tính toán các chỉ số thống kê từ danh sách đơn hàng đã lọc
  static OrderStatistics calculateStats(List<Order> orders) {
    if (orders.isEmpty) {
      return OrderStatistics.empty();
    }

    int totalRevenue = 0;
    int totalItemsSold = 0;
    int cashRevenue = 0;
    int transferRevenue = 0;
    int cashOrdersCount = 0;
    int transferOrdersCount = 0;

    for (final order in orders) {
      totalRevenue += order.totalAmount;

      for (final item in order.items) {
        totalItemsSold += item.quantity;
      }

      if (order.paymentMethod == 'CHUYEN_KHOAN') {
        transferRevenue += order.totalAmount;
        transferOrdersCount++;
      } else {
        cashRevenue += order.totalAmount;
        cashOrdersCount++;
      }
    }

    final totalOrders = orders.length;
    final averageOrderValue = totalOrders > 0 ? (totalRevenue / totalOrders).round() : 0;

    return OrderStatistics(
      totalRevenue: totalRevenue,
      totalOrders: totalOrders,
      averageOrderValue: averageOrderValue,
      totalItemsSold: totalItemsSold,
      cashRevenue: cashRevenue,
      transferRevenue: transferRevenue,
      cashOrdersCount: cashOrdersCount,
      transferOrdersCount: transferOrdersCount,
    );
  }
}
