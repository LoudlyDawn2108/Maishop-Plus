import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../providers/cart_provider.dart';
import '../../utils/currency_utils.dart';
import 'checkout_dialog.dart';
import 'product_form_screen.dart';

class PosScreen extends StatefulWidget {
  final bool isActive;
  const PosScreen({super.key, this.isActive = true});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isCameraExpanded = false;
  bool _isTorchOn = false;
  DateTime _lastScannedTime = DateTime.now().subtract(const Duration(seconds: 5));
  String? _lastScannedCode;

  final TextEditingController _manualCodeController = TextEditingController();

  // Chạm lấy nét (Tap to focus)
  late final AnimationController _focusAnimController;
  Offset? _focusPoint;
  bool _showFocusReticle = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focusAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void didUpdateWidget(covariant PosScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Tự động tắt camera khi chuyển sang màn hình/tab khác
    if (oldWidget.isActive && !widget.isActive) {
      _turnOffCamera();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Tự động tắt camera khi app bị thu nhỏ hoặc không còn hiển thị
    if (state != AppLifecycleState.resumed) {
      _turnOffCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusAnimController.dispose();
    _scannerController.dispose();
    _manualCodeController.dispose();
    super.dispose();
  }

  void _turnOffCamera() {
    if (_isCameraExpanded) {
      setState(() {
        _isCameraExpanded = false;
        _isTorchOn = false;
      });
      try {
        _scannerController.stop();
      } catch (_) {}
    }
  }

  void _onTapToFocus(TapDownDetails details) {
    HapticFeedback.selectionClick();
    setState(() {
      _focusPoint = details.localPosition;
      _showFocusReticle = true;
    });

    _focusAnimController.forward(from: 0.0);

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _showFocusReticle = false;
        });
      }
    });
  }

  void _handleBarcodeDetect(String code, CartProvider cart) async {
    // Tự động tắt camera ngay lập tức sau khi quét được mã
    _turnOffCamera();
    HapticFeedback.mediumImpact();

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
            tooltip: _isCameraExpanded ? 'Tắt camera' : 'Mở camera quét',
            icon: Icon(
              _isCameraExpanded ? Icons.close_rounded : Icons.photo_camera_outlined,
            ),
            onPressed: () {
              if (_isCameraExpanded) {
                _turnOffCamera();
              } else {
                setState(() {
                  _isCameraExpanded = true;
                });
              }
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
          // 1. Danh sách giỏ hàng (Chiếm toàn bộ không gian phía trên)
          Expanded(
            child: cart.items.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          if (_isCameraExpanded) {
                            _turnOffCamera();
                          } else {
                            setState(() {
                              _isCameraExpanded = true;
                            });
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer.withOpacity(0.35),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _isCameraExpanded
                                      ? Icons.photo_camera_outlined
                                      : Icons.qr_code_scanner_rounded,
                                  size: 44,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _isCameraExpanded
                                    ? 'Đang bật camera quét ở bên dưới'
                                    : 'Chạm để mở camera quét mã',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isCameraExpanded
                                    ? 'Đưa mã vạch vào khung ngắm phía dưới'
                                    : 'Món chưa có trong kho sẽ có thông báo để đăng ký riêng',
                                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, index) {
                      final item = cart.items[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.product.name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${CurrencyUtils.formatVND(item.product.price)} / ${item.product.unit}',
                                    style: TextStyle(
                                      fontSize: 12,
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
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    iconSize: 15,
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                    icon: const Icon(Icons.remove_rounded),
                                    onPressed: () => cart.decrementQuantity(index),
                                  ),
                                  Text(
                                    '${item.quantity}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  IconButton(
                                    iconSize: 15,
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                    icon: const Icon(Icons.add_rounded),
                                    onPressed: () => cart.incrementQuantity(index),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Thành tiền
                            SizedBox(
                              width: 76,
                              child: Text(
                                CurrencyUtils.formatVND(item.subtotal),
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded, size: 18, color: colorScheme.error),
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              onPressed: () => cart.removeItem(index),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // 2. Camera quét mã vạch (chuyển xuống dưới, thu gọn 25% vừa vặn)
          if (_isCameraExpanded)
            Container(
              height: 150,
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

                  // Lớp bắt sự kiện chạm để lấy nét (Tap to focus)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTapDown: _onTapToFocus,
                    ),
                  ),

                  // Khung ngắm hình chữ nhật
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        width: 210,
                        height: 90,
                        decoration: BoxDecoration(
                          border: Border.all(color: colorScheme.primary, width: 2.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  // Hiệu ứng ô lấy nét màu vàng khi chạm màn hình
                  if (_showFocusReticle && _focusPoint != null)
                    Positioned(
                      left: _focusPoint!.dx - 24,
                      top: _focusPoint!.dy - 24,
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _focusAnimController,
                          builder: (context, child) {
                            final scale = 1.3 - (_focusAnimController.value * 0.3);
                            return Transform.scale(
                              scale: scale,
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFFFFD600), // Vàng tiêu cự
                                    width: 2.0,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Container(
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFFD600),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                  // Dòng hướng dẫn chạm lấy nét
                  const Positioned(
                    bottom: 4,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Center(
                        child: Text(
                          'Chạm vào màn hình để lấy nét',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 4),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Điều khiển Camera (Flash & Flip)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Row(
                      children: [
                        IconButton.filledTonal(
                          iconSize: 17,
                          padding: const EdgeInsets.all(5),
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
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
                        const SizedBox(width: 4),
                        IconButton.filledTonal(
                          iconSize: 17,
                          padding: const EdgeInsets.all(5),
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          icon: const Icon(Icons.flip_camera_android_rounded),
                          onPressed: () => _scannerController.switchCamera(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // 3. Nhập mã vạch thủ công & Nút bật/tắt camera (ở ngay phía dưới, tiện thao tác một tay)
          Container(
            color: colorScheme.surface,
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualCodeController,
                    decoration: InputDecoration(
                      hintText: 'Nhập mã vạch sản phẩm...',
                      isDense: true,
                      prefixIcon: const Icon(Icons.keyboard_alt_outlined, size: 18),
                      suffixIcon: IconButton(
                        iconSize: 18,
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        tooltip: 'Thêm vào giỏ',
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
                const SizedBox(width: 6),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: _isCameraExpanded
                        ? colorScheme.errorContainer
                        : colorScheme.primary,
                    foregroundColor: _isCameraExpanded
                        ? colorScheme.onErrorContainer
                        : colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(9),
                  ),
                  tooltip: _isCameraExpanded ? 'Tắt camera' : 'Bật camera quét mã',
                  icon: Icon(
                    _isCameraExpanded
                        ? Icons.close_rounded
                        : Icons.qr_code_scanner_rounded,
                    size: 20,
                  ),
                  onPressed: () {
                    if (_isCameraExpanded) {
                      _turnOffCamera();
                    } else {
                      setState(() {
                        _isCameraExpanded = true;
                      });
                    }
                  },
                ),
              ],
            ),
          ),

          // 4. Thanh tính tổng tiền đáy màn hình & Nút THANH TOÁN
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Tổng ${cart.totalQuantity} món:',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        CurrencyUtils.formatVND(cart.totalAmount),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: cart.items.isEmpty
                        ? null
                        : () {
                            _turnOffCamera();
                            CheckoutDialog.show(context);
                          },
                    icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 17),
                    label: const Text(
                      'THANH TOÁN',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
