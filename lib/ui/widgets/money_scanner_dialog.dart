import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/currency_utils.dart';

class MoneyScannerDialog extends StatefulWidget {
  final Function(int denomination) onDetected;

  const MoneyScannerDialog({
    super.key,
    required this.onDetected,
  });

  static Future<void> show(BuildContext context, Function(int denomination) onDetected) {
    return showDialog(
      context: context,
      builder: (ctx) => MoneyScannerDialog(onDetected: onDetected),
    );
  }

  @override
  State<MoneyScannerDialog> createState() => _MoneyScannerDialogState();
}

class _MoneyScannerDialogState extends State<MoneyScannerDialog> {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;
  int? _detectedAmount;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Tự động mở camera chụp tiền ngay khi bật modal
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _captureAndScan();
    });
  }

  Future<void> _captureAndScan() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _detectedAmount = null;
    });

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (photo == null) {
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      final inputImage = InputImage.fromFilePath(photo.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      final detected = CurrencyUtils.extractVndDenominationFromOcr(recognizedText.text);

      setState(() {
        _isProcessing = false;
        _detectedAmount = detected;
        if (detected == null) {
          _errorMessage = 'Chưa nhận diện được mệnh giá. Bạn vui lòng chụp rõ số tiền hoặc chọn từ hàng phím tắt bên dưới.';
        }
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Lỗi nhận diện camera: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.document_scanner_rounded, color: colorScheme.primary),
          const SizedBox(width: 8),
          const Text('Quét tiền Polymer VNĐ'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isProcessing) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 16),
              const Center(child: Text('Đang phân tích tờ tiền...')),
              const SizedBox(height: 24),
            ] else if (_detectedAmount != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.primary),
                ),
                child: Column(
                  children: [
                    Icon(Icons.check_circle_rounded, color: colorScheme.primary, size: 40),
                    const SizedBox(height: 8),
                    const Text('Phát hiện tờ tiền:', style: TextStyle(fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyUtils.formatVND(_detectedAmount!),
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  widget.onDetected(_detectedAmount!);
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: Text('Cộng ${CurrencyUtils.formatVND(_detectedAmount!)}'),
              ),
            ] else ...[
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: colorScheme.onErrorContainer, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              const Text(
                'Hoặc chọn nhanh mệnh giá khách đưa:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CurrencyUtils.vietnameseDenominations.take(6).map((denom) {
                  return ActionChip(
                    avatar: Icon(Icons.payments_outlined, size: 16, color: colorScheme.primary),
                    label: Text(CurrencyUtils.formatVND(denom)),
                    onPressed: () {
                      widget.onDetected(denom);
                      Navigator.of(context).pop();
                    },
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _isProcessing ? null : _captureAndScan,
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('Chụp lại'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
      ],
    );
  }
}
