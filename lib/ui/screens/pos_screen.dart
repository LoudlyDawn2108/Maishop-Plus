import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../providers/cart_provider.dart';
import '../../utils/currency_utils.dart';
import 'checkout_dialog.dart';
import 'product_form_screen.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isCameraExpanded = true;
  bool _isTorchOn = false;
  DateTime _lastScannedTime = DateTime.now().subtract(const Duration(seconds: 5));
  String? _lastScannedCode;

  final TextEditingController _manualCodeController = TextEditingController();

  @override
  void dispose() {
    _scannerController.dispose();
    _manualCodeController.dispose();
    super.dispose();
  }

  void _handleBarcodeDetect(String code, CartProvider cart) async {
    // Tránh quét lặp lại liên tiếp trong vòng 1.5 giây đối với cùng 1 mã
    final now = DateTime.now();
    if (_lastScannedCode == code && now.difference(_lastScannedTime).inMilliseconds < 1500) {
      return;
    }
    _lastScannedTime = now;
    _lastScannedCode = code;

    final product = await cart.addProductByBarcode(code);

    if (product == null && mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          content: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Mã vạch "$code" chưa có trong kho'),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'ĐĂNG KÝ NGAY',
            textColor: Colors.amberAccent,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => ProductFormScreen(initialBarcode: code),
                ),
              );
            },
          ),
        ),
      );
    }
  }

  void _showAddManualItemDialog(BuildContext context, CartProvider cart) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    String unit = 'Cái';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.playlist_add_rounded),
              SizedBox(width: 8),
              Text('Thêm hàng không mã'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Tên mặt hàng *',
                  hintText: 'VD: Rau muống, Túi đá, Trứng gà...',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Đơn giá (VNĐ) *',
                        suffixText: '₫',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'SL',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: ['Cái', 'Gói', 'Túi', 'Kg', 'Quả', 'Bó'].map((u) {
                  return ChoiceChip(
                    label: Text(u),
                    selected: unit == u,
                    onSelected: (selected) {
                      if (selected) setDlgState(() => unit = u);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final price = CurrencyUtils.parseVND(priceCtrl.text);
                final qty = int.tryParse(qtyCtrl.text.trim()) ?? 1;

                if (name.isEmpty || price <= 0) return;

                cart.addManualItem(name, price, quantity: qty, unit: unit);
                Navigator.of(ctx).pop();
              },
              child: const Text('Thêm vào giỏ'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thu ngân / Bán hàng'),
        actions: [
          IconButton(
            tooltip: _isCameraExpanded ? 'Thu gọn camera' : 'Mở camera quét',
            icon: Icon(
              _isCameraExpanded ? Icons.visibility_off_outlined : Icons.photo_camera_outlined,
            ),
            onPressed: () {
              setState(() {
                _isCameraExpanded = !_isCameraExpanded;
              });
            },
          ),
          if (cart.items.isNotEmpty)
            IconButton(
              tooltip: 'Xóa giỏ hàng',
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: () {
                cart.clearCart();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Khung quét mã vạch
          if (_isCameraExpanded)
            Container(
              height: 190,
              color: Colors.black,
              child: Stack(
                children: [
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: (capture) {
                      final barcodes = capture.barcodes;
                      if (barcodes.isNotEmpty) {
                        final raw = barcodes.first.rawValue;
                        if (raw != null && raw.isNotEmpty) {
                          _handleBarcodeDetect(raw, cart);
                        }
                      }
                    },
                  ),
                  // Khung ngắm
                  Center(
                    child: Container(
                      width: 220,
                      height: 100,
                      decoration: BoxDecoration(
                        border: Border.all(color: colorScheme.primary, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  // Điều khiển Camera (Flash & Flip)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      children: [
                        IconButton.filledTonal(
                          iconSize: 20,
                          icon: Icon(
                            _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                          ),
                          onPressed: () async {
                            await _scannerController.toggleTorch();
                            setState(() {
                              _isTorchOn = !_isTorchOn;
                            });
                          },
                        ),
                        const SizedBox(width: 6),
                        IconButton.filledTonal(
                          iconSize: 20,
                          icon: const Icon(Icons.flip_camera_android_rounded),
                          onPressed: () => _scannerController.switchCamera(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Nhập mã thủ công hoặc thêm hàng nhanh
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualCodeController,
                    decoration: InputDecoration(
                      hintText: 'Nhập mã vạch thủ công...',
                      isDense: true,
                      prefixIcon: const Icon(Icons.keyboard_alt_outlined, size: 20),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        onPressed: () {
                          final code = _manualCodeController.text.trim();
                          if (code.isNotEmpty) {
                            _handleBarcodeDetect(code, cart);
                            _manualCodeController.clear();
                          }
                        },
                      ),
                    ),
                    onSubmitted: (val) {
                      final code = val.trim();
                      if (code.isNotEmpty) {
                        _handleBarcodeDetect(code, cart);
                        _manualCodeController.clear();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onPressed: () => _showAddManualItemDialog(context, cart),
                  icon: const Icon(Icons.add_box_outlined, size: 18),
                  label: const Text('Hàng lẻ'),
                ),
              ],
            ),
          ),

          const Divider(height: 12),

          // Danh sách giỏ hàng
          Expanded(
            child: cart.items.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code_scanner_rounded,
                            size: 48,
                            color: colorScheme.outline,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Quét mã vạch sản phẩm để tính tiền',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Món chưa có trong kho sẽ có thông báo để đăng ký riêng',
                            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, index) {
                      final item = cart.items[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.product.name,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${CurrencyUtils.formatVND(item.product.price)} / ${item.product.unit}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Bộ nút tăng giảm số lượng
                            Container(
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    iconSize: 18,
                                    icon: const Icon(Icons.remove_rounded),
                                    onPressed: () => cart.decrementQuantity(index),
                                  ),
                                  Text(
                                    '${item.quantity}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  IconButton(
                                    iconSize: 18,
                                    icon: const Icon(Icons.add_rounded),
                                    onPressed: () => cart.incrementQuantity(index),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Thành tiền
                            SizedBox(
                              width: 80,
                              child: Text(
                                CurrencyUtils.formatVND(item.subtotal),
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded, size: 20, color: colorScheme.error),
                              onPressed: () => cart.removeItem(index),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Thanh tính tổng tiền đáy màn hình
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Tổng ${cart.totalQuantity} món:',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        CurrencyUtils.formatVND(cart.totalAmount),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                    onPressed: cart.items.isEmpty ? null : () => CheckoutDialog.show(context),
                    icon: const Icon(Icons.shopping_cart_checkout_rounded),
                    label: const Text(
                      'THANH TOÁN',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
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
