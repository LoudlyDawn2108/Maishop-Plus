import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Modal quét mã vạch chuyên dụng thiết kế đồng bộ với camera thu ngân
class BarcodeScannerSheet extends StatefulWidget {
  final String title;
  final String hintText;

  const BarcodeScannerSheet({
    super.key,
    this.title = 'Quét mã vạch đăng ký',
    this.hintText = 'Đặt mã vạch vào giữa ô chữ nhật',
  });

  /// Phương thức tĩnh để mở nhanh BottomSheet quét mã
  static Future<String?> show(
    BuildContext context, {
    String title = 'Quét mã vạch đăng ký',
    String hintText = 'Đặt mã vạch vào giữa ô chữ nhật',
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => BarcodeScannerSheet(
        title: title,
        hintText: hintText,
      ),
    );
  }

  @override
  State<BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<BarcodeScannerSheet>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;

  // Animation cho vòng lấy nét khi chạm vào màn hình
  late final AnimationController _focusAnimController;
  Offset? _focusPoint;
  bool _showFocusReticle = false;

  double _currentZoom = 0.0;
  bool _isTorchOn = false;
  bool _hasDetected = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      formats: [BarcodeFormat.all],
    );

    // Hoạt ảnh ô lấy nét khi chạm màn hình
    _focusAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _focusAnimController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onTapToFocus(TapDownDetails details) {
    HapticFeedback.selectionClick();
    setState(() {
      _focusPoint = details.localPosition;
      _showFocusReticle = true;
    });

    _focusAnimController.forward(from: 0.0).then((_) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          setState(() {
            _showFocusReticle = false;
          });
        }
      });
    });
  }

  void _setZoom(double zoom) {
    HapticFeedback.selectionClick();
    setState(() => _currentZoom = zoom);
    _controller.setZoomScale(zoom);
  }

  void _toggleTorch() {
    HapticFeedback.selectionClick();
    _controller.toggleTorch();
    setState(() => _isTorchOn = !_isTorchOn);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sheetHeight = MediaQuery.of(context).size.height * 0.75;

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 1. Camera scanner preview
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_hasDetected) return;
              final barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final code = barcodes.first.rawValue;
                if (code != null && code.trim().isNotEmpty) {
                  _hasDetected = true;
                  HapticFeedback.mediumImpact();
                  Navigator.of(context).pop(code.trim());
                }
              }
            },
          ),

          // Lớp bắt sự kiện chạm vào màn hình để lấy nét (Tap to focus)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapDown: _onTapToFocus,
            ),
          ),

          // 2. Khung ngắm hình chữ nhật giống hệt màn hình thu ngân
          IgnorePointer(
            child: Center(
              child: Container(
                width: 260,
                height: 130,
                decoration: BoxDecoration(
                  border: Border.all(color: colorScheme.primary, width: 2.5),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),

          // 3. Hiệu ứng ô lấy nét khi chạm màn hình (Focus Reticle)
          if (_showFocusReticle && _focusPoint != null)
            Positioned(
              left: _focusPoint!.dx - 32,
              top: _focusPoint!.dy - 32,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _focusAnimController,
                  builder: (context, child) {
                    final scale = 1.3 - (_focusAnimController.value * 0.3);
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFFFFD600), // Màu vàng lấy nét
                            width: 2.5,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Container(
                            width: 8,
                            height: 8,
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

          // 4. Thanh điều khiển trên cùng (Tiêu đề, đèn pin, lật cam, đóng)
          Positioned(
            top: 14,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Chạm vào màn hình để lấy nét',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // Nút bật/tắt đèn Flash
                IconButton.filledTonal(
                  style: IconButton.styleFrom(
                    backgroundColor: _isTorchOn
                        ? colorScheme.primary
                        : Colors.white.withOpacity(0.2),
                    foregroundColor: _isTorchOn ? colorScheme.onPrimary : Colors.white,
                  ),
                  icon: Icon(
                    _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                    size: 20,
                  ),
                  tooltip: _isTorchOn ? 'Tắt đèn' : 'Bật đèn',
                  onPressed: _toggleTorch,
                ),
                const SizedBox(width: 6),
                // Nút Đổi Camera trước / sau
                IconButton.filledTonal(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.flip_camera_android_rounded, size: 20),
                  tooltip: 'Đổi camera',
                  onPressed: () => _controller.switchCamera(),
                ),
                const SizedBox(width: 6),
                // Nút Đóng
                IconButton.filledTonal(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // 5. Thanh điều khiển dưới cùng: Phóng to (Zoom) khi mã vạch nhỏ & Gợi ý
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Bộ nút Zoom nhanh: 1x, 2x, 3x cho mã nhỏ
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white24, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 6, right: 4),
                        child: Icon(Icons.zoom_in_rounded, size: 16, color: Colors.white70),
                      ),
                      _buildZoomPill('1x', 0.0, colorScheme),
                      const SizedBox(width: 4),
                      _buildZoomPill('2x', 0.25, colorScheme),
                      const SizedBox(width: 4),
                      _buildZoomPill('3x', 0.5, colorScheme),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Card hướng dẫn
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.crop_free_rounded, size: 16, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.hintText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomPill(String label, double zoomValue, ColorScheme colorScheme) {
    final isSelected = (_currentZoom - zoomValue).abs() < 0.05;
    return InkWell(
      onTap: () => _setZoom(zoomValue),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? colorScheme.onPrimary : Colors.white,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
