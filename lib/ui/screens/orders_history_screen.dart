import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../data/database_helper.dart';
import '../../services/sheets_service.dart';
import '../../utils/currency_utils.dart';
import '../../utils/order_stats_helper.dart';

class OrdersHistoryScreen extends StatefulWidget {
  const OrdersHistoryScreen({super.key});

  @override
  State<OrdersHistoryScreen> createState() => _OrdersHistoryScreenState();
}

class _OrdersHistoryScreenState extends State<OrdersHistoryScreen> {
  List<Order> _orders = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  OrderTimeFilter _selectedFilter = OrderTimeFilter.today;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final list = await DatabaseHelper.instance.getOrders();
      setState(() {
        _orders = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _syncOrders() async {
    if (!SheetsService.instance.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng thiết lập Google Sheets trong phần Cài đặt trước.'),
        ),
      );
      return;
    }

    setState(() => _isSyncing = true);
    try {
      final pushedCount = await SheetsService.instance.pushUnsyncedOrders();
      await _loadOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Đã đồng bộ $pushedCount đơn hàng lên Google Sheets thành công!'),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi đồng bộ đơn: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _showOrderDetails(Order order) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm:ss');
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt_rounded),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                order.id,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateFormat.format(order.createdAt),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: order.isSynced
                          ? Colors.green.withOpacity(0.15)
                          : Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          order.isSynced ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                          size: 13,
                          color: order.isSynced ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          order.isSynced ? 'Đã đồng bộ' : 'Chưa đồng bộ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: order.isSynced ? Colors.green : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    order.paymentMethod == 'CHUYEN_KHOAN'
                        ? Icons.qr_code_rounded
                        : Icons.payments_outlined,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Hình thức: ${order.paymentMethod == "CHUYEN_KHOAN" ? "Chuyển khoản (QR)" : "Tiền mặt"}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const Divider(height: 20),
              const Text(
                'Danh sách mặt hàng:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...order.items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${item.product.name} (x${item.quantity})',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          CurrencyUtils.formatVND(item.subtotal),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ],
                    ),
                  )),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tổng tiền:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    CurrencyUtils.formatVND(order.totalAmount),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Khách đưa:'),
                  Text(CurrencyUtils.formatVND(order.customerPaid)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tiền thối:'),
                  Text(
                    CurrencyUtils.formatVND(order.changeAmount),
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.green),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(ColorScheme colorScheme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: OrderTimeFilter.values.map((filter) {
          final isSelected = _selectedFilter == filter;
          IconData icon;
          switch (filter) {
            case OrderTimeFilter.today:
              icon = Icons.today_rounded;
              break;
            case OrderTimeFilter.thisWeek:
              icon = Icons.date_range_rounded;
              break;
            case OrderTimeFilter.thisMonth:
              icon = Icons.calendar_month_rounded;
              break;
            case OrderTimeFilter.last7Days:
              icon = Icons.history_toggle_off_rounded;
              break;
            case OrderTimeFilter.last30Days:
              icon = Icons.timelapse_rounded;
              break;
            case OrderTimeFilter.all:
              icon = Icons.all_inclusive_rounded;
              break;
          }

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              avatar: Icon(
                icon,
                size: 16,
                color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
              ),
              label: Text(
                filter.label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                ),
              ),
              selected: isSelected,
              selectedColor: colorScheme.primary,
              checkmarkColor: colorScheme.onPrimary,
              showCheckmark: false,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedFilter = filter);
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatsCard(ColorScheme colorScheme, OrderStatistics stats) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_rounded, size: 18, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'Thống kê ${_selectedFilter.label.toLowerCase()}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const Spacer(),
              Text(
                '${stats.totalOrders} đơn',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Hàng 1: Doanh thu & Đơn hàng
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tổng doanh thu',
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        CurrencyUtils.formatVND(stats.totalRevenue),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 38,
                width: 1,
                color: colorScheme.outlineVariant,
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TB / đơn',
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        CurrencyUtils.formatVND(stats.averageOrderValue),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 38,
                width: 1,
                color: colorScheme.outlineVariant,
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Đã bán',
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${stats.totalItemsSold} món',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          // Hàng 2: Chi tiết Tiền mặt & Chuyển khoản
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.payments_outlined, size: 16, color: colorScheme.secondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tiền mặt (${stats.cashOrdersCount})',
                            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                          ),
                          Text(
                            CurrencyUtils.formatVND(stats.cashRevenue),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.qr_code_rounded, size: 16, color: colorScheme.tertiary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chuyển khoản (${stats.transferOrdersCount})',
                            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                          ),
                          Text(
                            CurrencyUtils.formatVND(stats.transferRevenue),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Lọc danh sách theo filter thời gian và search query
    final filteredOrders = OrderStatsHelper.filterOrders(
      _orders,
      _selectedFilter,
      searchQuery: _searchQuery,
    );

    // Tính toán thống kê theo danh sách đơn hàng đã lọc
    final stats = OrderStatsHelper.calculateStats(filteredOrders);

    final unsyncedCount = _orders.where((o) => !o.isSynced).length;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Tìm theo mã đơn, tên hàng...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                style: const TextStyle(fontSize: 16),
                onChanged: (val) {
                  setState(() => _searchQuery = val);
                },
              )
            : const Text('Lịch sử bán hàng'),
        actions: [
          IconButton(
            tooltip: _isSearching ? 'Đóng tìm kiếm' : 'Tìm kiếm đơn',
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                  _searchQuery = '';
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadOrders,
          ),
          IconButton(
            tooltip: 'Đồng bộ đơn lên Sheets',
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Badge(
                    isLabelVisible: unsyncedCount > 0,
                    label: Text('$unsyncedCount'),
                    child: const Icon(Icons.cloud_upload_outlined),
                  ),
            onPressed: _isSyncing ? null : _syncOrders,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadOrders,
        child: Column(
          children: [
            // Thanh chọn mốc thời gian thống kê
            _buildFilterChips(colorScheme),

            // Thẻ thống kê doanh thu đa chiều
            _buildStatsCard(colorScheme, stats),

            // Thông báo đơn chưa đồng bộ
            if (unsyncedCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                child: Row(
                  children: [
                    Icon(Icons.cloud_queue_rounded, size: 16, color: colorScheme.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Có $unsyncedCount đơn chưa đồng bộ lên Google Sheets',
                        style: TextStyle(fontSize: 12, color: colorScheme.error, fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: _syncOrders,
                      child: const Text('Đồng bộ', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),

            // Tiêu đề số lượng đơn hiển thị
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: Row(
                children: [
                  Text(
                    'Danh sách đơn (${filteredOrders.length})',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (_searchQuery.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      '• Lọc: "$_searchQuery"',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Danh sách đơn hàng
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredOrders.isEmpty
                      ? LayoutBuilder(
                          builder: (context, constraints) => SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minHeight: constraints.maxHeight),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.receipt_long_rounded, size: 64, color: colorScheme.outline),
                                    const SizedBox(height: 12),
                                    Text(
                                      _orders.isEmpty
                                          ? 'Chưa có đơn hàng nào'
                                          : 'Không có đơn nào trong mốc "${_selectedFilter.label}"',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _orders.isEmpty
                                          ? 'Các đơn thanh toán sẽ tự động lưu vào đây'
                                          : 'Chọn "Tất cả" hoặc mốc thời gian khác để xem',
                                      style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          itemCount: filteredOrders.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (ctx, index) {
                            final order = filteredOrders[index];
                            final dateFormat = DateFormat('HH:mm - dd/MM/yyyy');

                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                onTap: () => _showOrderDetails(order),
                                leading: CircleAvatar(
                                  backgroundColor: order.paymentMethod == 'CHUYEN_KHOAN'
                                      ? colorScheme.tertiaryContainer
                                      : colorScheme.secondaryContainer,
                                  child: Icon(
                                    order.paymentMethod == 'CHUYEN_KHOAN'
                                        ? Icons.qr_code_rounded
                                        : Icons.payments_outlined,
                                    color: order.paymentMethod == 'CHUYEN_KHOAN'
                                        ? colorScheme.onTertiaryContainer
                                        : colorScheme.onSecondaryContainer,
                                    size: 20,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Text(
                                      CurrencyUtils.formatVND(order.totalAmount),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: (order.paymentMethod == 'CHUYEN_KHOAN'
                                                ? colorScheme.tertiary
                                                : colorScheme.secondary)
                                            .withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        order.paymentMethod == 'CHUYEN_KHOAN' ? 'Chuyển khoản' : 'Tiền mặt',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: order.paymentMethod == 'CHUYEN_KHOAN'
                                              ? colorScheme.tertiary
                                              : colorScheme.secondary,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(
                                      order.isSynced
                                          ? Icons.cloud_done_rounded
                                          : Icons.cloud_off_rounded,
                                      size: 16,
                                      color: order.isSynced ? Colors.green : Colors.grey,
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      order.itemsSummary,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      dateFormat.format(order.createdAt),
                                      style: TextStyle(fontSize: 11, color: colorScheme.outline),
                                    ),
                                  ],
                                ),
                                trailing: const Icon(Icons.chevron_right_rounded),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
