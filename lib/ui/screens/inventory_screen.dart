import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/inventory_provider.dart';
import '../../utils/currency_utils.dart';
import '../widgets/barcode_scanner_sheet.dart';
import 'product_form_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openBarcodeFilter() async {
    final code = await BarcodeScannerSheet.show(
      context,
      title: 'Quét tìm sản phẩm',
      hintText: 'Căn mã vạch vào khung chữ nhật • Chạm lấy nét • Chọn 2x nếu mã bé',
    );

    if (code != null && code.isNotEmpty) {
      _searchController.text = code;
      if (mounted) {
        context.read<InventoryProvider>().setSearchQuery(code);
      }
    }
  }

  void _showSortOptions(BuildContext context, InventoryProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.sort_rounded),
                      SizedBox(width: 8),
                      Text(
                        'Sắp xếp danh sách theo',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                ...ProductSortOption.values.map((option) {
                  final isSelected = provider.sortOption == option;
                  return ListTile(
                    leading: Icon(
                      isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                      color: isSelected ? Theme.of(context).colorScheme.primary : null,
                    ),
                    title: Text(
                      option.label,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    onTap: () {
                      provider.setSortOption(option);
                      Navigator.of(ctx).pop();
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Xác nhận xóa'),
          ],
        ),
        content: Text('Bạn có chắc chắn muốn xóa sản phẩm "${product.name}" khỏi danh mục không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<InventoryProvider>().deleteProduct(product.barcode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = context.watch<InventoryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kho hàng & Danh mục'),
        actions: [
          IconButton(
            tooltip: 'Đồng bộ Google Sheets',
            icon: provider.isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
            onPressed: provider.isSyncing
                ? null
                : () async {
                    final res = await provider.syncWithSheets();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(
                                res.success ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(res.message)),
                            ],
                          ),
                          backgroundColor: res.success ? colorScheme.primary : colorScheme.error,
                        ),
                      );
                    }
                  },
          ),
        ],
      ),
      body: Column(
        children: [
          // Thanh hiển thị trạng thái sắp xếp & số lượng (gọn gàng ở trên)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
            child: Row(
              children: [
                Text(
                  'Tổng: ${provider.products.length} sản phẩm',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => _showSortOptions(context, provider),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      children: [
                        Icon(Icons.tune_rounded, size: 13, color: colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          provider.sortOption.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Danh sách sản phẩm (Chiếm toàn bộ không gian giữa)
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 52, color: colorScheme.outline),
                            const SizedBox(height: 12),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'Không tìm thấy sản phẩm nào'
                                  : 'Chưa có sản phẩm nào trong kho',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'Hãy thử tìm kiếm với từ khóa khác'
                                  : 'Bấm nút "+" ở thanh công cụ bên dưới để thêm món đầu tiên',
                              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          await provider.loadProducts();
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                          itemCount: provider.products.length,
                          itemBuilder: (ctx, index) {
                            final product = provider.products[index];
                            final isLowStock = product.stock <= 5;
                            final isOutOfStock = product.stock <= 0;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (ctx) => ProductFormScreen(productToEdit: product),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(11),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  product.name,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.qr_code_2_rounded,
                                                      size: 16,
                                                      color: colorScheme.onSurfaceVariant,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      product.barcode,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: colorScheme.onSurfaceVariant,
                                                        fontFamily: 'monospace',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          PopupMenuButton<String>(
                                            icon: const Icon(Icons.more_vert_rounded),
                                            onSelected: (val) {
                                              if (val == 'edit') {
                                                Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (ctx) => ProductFormScreen(productToEdit: product),
                                                  ),
                                                );
                                              } else if (val == 'delete') {
                                                _confirmDelete(context, product);
                                              }
                                            },
                                            itemBuilder: (ctx) => [
                                              const PopupMenuItem(
                                                value: 'edit',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.edit_outlined, size: 18),
                                                    SizedBox(width: 8),
                                                    Text('Chỉnh sửa'),
                                                  ],
                                                ),
                                              ),
                                              PopupMenuItem(
                                                value: 'delete',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.delete_outline_rounded, size: 18, color: colorScheme.error),
                                                    const SizedBox(width: 8),
                                                    Text('Xóa', style: TextStyle(color: colorScheme.error)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            CurrencyUtils.formatVND(product.price),
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              color: colorScheme.primary,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              // Nhãn đơn vị tính
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: colorScheme.surfaceContainerHighest,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  product.unit,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: colorScheme.onSurfaceVariant,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              // Nhãn tồn kho
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: isOutOfStock
                                                      ? colorScheme.errorContainer
                                                      : isLowStock
                                                          ? Colors.amber.withOpacity(0.2)
                                                          : colorScheme.primaryContainer.withOpacity(0.5),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      isOutOfStock
                                                          ? Icons.error_outline_rounded
                                                          : Icons.inventory_2_outlined,
                                                      size: 14,
                                                      color: isOutOfStock
                                                          ? colorScheme.error
                                                          : isLowStock
                                                              ? Colors.amber.shade900
                                                              : colorScheme.primary,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      isOutOfStock
                                                          ? 'Hết hàng'
                                                          : 'Kho: ${product.stock}',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                        color: isOutOfStock
                                                            ? colorScheme.error
                                                            : isLowStock
                                                                ? Colors.amber.shade900
                                                                : colorScheme.primary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),

          // Thanh tìm kiếm, lọc & thêm sản phẩm ở dưới cùng màn hình (dễ thao tác một tay)
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              border: Border(
                top: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.4)),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Tìm theo tên hoặc mã vạch...',
                        isDense: true,
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  provider.setSearchQuery('');
                                },
                              )
                            : IconButton(
                                tooltip: 'Quét mã vạch tìm kiếm',
                                icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                                onPressed: _openBarcodeFilter,
                              ),
                      ),
                      onChanged: (val) {
                        provider.setSearchQuery(val);
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filledTonal(
                    tooltip: 'Sắp xếp danh sách',
                    icon: const Icon(Icons.tune_rounded, size: 19),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    onPressed: () => _showSortOptions(context, provider),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    tooltip: 'Đăng ký sản phẩm mới',
                    icon: const Icon(Icons.add_rounded, size: 21),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const ProductFormScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
