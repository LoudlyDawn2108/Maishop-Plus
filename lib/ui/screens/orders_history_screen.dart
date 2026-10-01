import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../data/database_helper.dart';
import '../../services/sheets_service.dart';
import '../../utils/currency_utils.dart';

class OrdersHistoryScreen extends StatefulWidget {
  const OrdersHistoryScreen({super.key});

  @override
  State<OrdersHistoryScreen> createState() => _OrdersHistoryScreenState();
}

class _OrdersHistoryScreenState extends State<OrdersHistoryScreen> {
  List<Order> _orders = [];
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadOrders();
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
                Text('Đã đồng bộ $pushedCount đơn hàng lên Google Sheets thành công!'),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt_rounded),
            const SizedBox(width: 8),
            Text(order.id, style: const TextStyle(fontSize: 16)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Thời gian: ${dateFormat.format(order.createdAt)}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              Text(
                'Hình thức: ${order.paymentMethod == "CHUYEN_KHOAN" ? "Chuyển khoản" : "Tiền mặt"}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
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
                          child: Text('${item.product.name} (x${item.quantity})'),
                        ),
                        Text(
                          CurrencyUtils.formatVND(item.subtotal),
                          style: const TextStyle(fontWeight: FontWeight.w600),
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
                      fontSize: 17,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Khách đưa:'),
                  Text(CurrencyUtils.formatVND(order.customerPaid)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tiền thối:'),
                  Text(CurrencyUtils.formatVND(order.changeAmount)),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Doanh thu hôm nay
    final now = DateTime.now();
    final todayOrders = _orders.where((o) =>
        o.createdAt.year == now.year &&
        o.createdAt.month == now.month &&
        o.createdAt.day == now.day).toList();

    final todayRevenue = todayOrders.fold(0, (sum, o) => sum + o.totalAmount);
    final unsyncedCount = _orders.where((o) => !o.isSynced).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử bán hàng'),
        actions: [
          IconButton(
            tooltip: 'Đồng bộ đơn lên Sheets',
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            onPressed: _isSyncing ? null : _syncOrders,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadOrders,
        child: Column(
          children: [
            // Thẻ tóm tắt doanh thu hôm nay
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Doanh thu hôm nay',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyUtils.formatVND(todayRevenue),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 40,
                    width: 1,
                    color: colorScheme.outlineVariant,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Đơn hôm nay',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${todayOrders.length} đơn',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (unsyncedCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.cloud_queue_rounded, size: 16, color: colorScheme.error),
                    const SizedBox(width: 6),
                    Text(
                      'Có $unsyncedCount đơn chưa đồng bộ lên Google Sheets',
                      style: TextStyle(fontSize: 12, color: colorScheme.error, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _syncOrders,
                      child: const Text('Đồng bộ ngay', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),

            // Danh sách đơn hàng
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _orders.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_rounded, size: 64, color: colorScheme.outline),
                              const SizedBox(height: 12),
                              const Text(
                                'Chưa có đơn hàng nào',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Các đơn thanh toán sẽ tự động lưu vào đây',
                                style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _orders.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (ctx, index) {
                            final order = _orders[index];
                            final dateFormat = DateFormat('HH:mm - dd/MM');

                            return Card(
                              child: ListTile(
                                onTap: () => _showOrderDetails(order),
                                leading: CircleAvatar(
                                  backgroundColor: colorScheme.secondaryContainer,
                                  child: Icon(
                                    order.paymentMethod == 'CHUYEN_KHOAN'
                                        ? Icons.qr_code_rounded
                                        : Icons.payments_outlined,
                                    color: colorScheme.onSecondaryContainer,
                                    size: 20,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Text(
                                      CurrencyUtils.formatVND(order.totalAmount),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
