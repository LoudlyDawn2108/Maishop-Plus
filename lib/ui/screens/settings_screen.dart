import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/sheets_service.dart';
import '../../providers/cart_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _sheetIdController = TextEditingController();
  final TextEditingController _jsonController = TextEditingController();

  bool _isTesting = false;
  String? _testResult;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    final sheets = SheetsService.instance;
    _sheetIdController.text = sheets.spreadsheetId ?? '';
    _jsonController.text = sheets.credentialsJson ?? '';
  }

  @override
  void dispose() {
    _sheetIdController.dispose();
    _jsonController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final sheetId = _sheetIdController.text.trim();
    final json = _jsonController.text.trim();

    if (sheetId.isEmpty || json.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đầy đủ Spreadsheet ID và JSON Service Account.')),
      );
      return;
    }

    await SheetsService.instance.saveConfig(
      spreadsheetId: sheetId,
      credentialsJson: json,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text('Đã lưu cấu hình Google Sheets thành công!'),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      await _saveSettings();
      await SheetsService.instance.testConnection();

      setState(() {
        _isTesting = false;
        _testSuccess = true;
        _testResult = 'Kết nối thành công! Đã tìm thấy và sẵn sàng đồng bộ 2 tab: "Sản phẩm" & "Đơn hàng".';
      });
    } catch (e) {
      setState(() {
        _isTesting = false;
        _testSuccess = false;
        _testResult = 'Kết nối thất bại: ${e.toString()}';
      });
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã sao chép vào bộ nhớ tạm!')),
    );
  }

  void _showSetupGuide() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.menu_book_rounded),
            SizedBox(width: 8),
            Text('Hướng dẫn cài đặt Sheet'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bước 1: Tạo Google Sheet',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Mở Google Drive bằng tài khoản shop, tạo một Google Sheet mới (VD đặt tên là "MaiShop_Data").',
              ),
              SizedBox(height: 12),
              Text(
                'Bước 2: Lấy Spreadsheet ID',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'ID là chuỗi ký tự nằm giữa "/d/" và "/edit" trên thanh địa chỉ trình duyệt:\n'
                'docs.google.com/spreadsheets/d/[ĐÂY_LÀ_ID]/edit',
              ),
              SizedBox(height: 12),
              Text(
                'Bước 3: Tạo Service Account',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Vào Google Cloud Console > Tạo Service Account > Tạo Khóa (Key dạng JSON) và tải về mở ra copy nội dung dán vào ô bên dưới.',
              ),
              SizedBox(height: 12),
              Text(
                'Bước 4: Chia sẻ quyền chỉnh sửa',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Mở Google Sheet vừa tạo, bấm nút "Chia sẻ" (Share), dán email của Service Account vào và cấp quyền "Người chỉnh sửa" (Editor).',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cart = context.watch<CartProvider>();
    final saEmail = SheetsService.instance.serviceAccountEmail;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt hệ thống'),
        actions: [
          IconButton(
            tooltip: 'Hướng dẫn cài đặt',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: _showSetupGuide,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cài đặt âm thanh
            Card(
              child: SwitchListTile(
                secondary: Icon(
                  cart.soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  color: colorScheme.primary,
                ),
                title: const Text('Âm thanh & Rung khi quét'),
                subtitle: const Text('Phát tiếng bíp siêu thị và rung khi quét mã vạch thành công'),
                value: cart.soundEnabled,
                onChanged: (val) {
                  cart.setSoundEnabled(val);
                },
              ),
            ),

            const SizedBox(height: 16),

            // Thẻ cấu hình Google Sheets
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.table_chart_rounded, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        const Text(
                          'Kết nối Google Drive / Sheets',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _showSetupGuide,
                          icon: const Icon(Icons.info_outline_rounded, size: 16),
                          label: const Text('Xem hướng dẫn'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _sheetIdController,
                      decoration: const InputDecoration(
                        labelText: 'Spreadsheet ID (Mã bảng tính) *',
                        hintText: 'VD: 1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms',
                        prefixIcon: Icon(Icons.link_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _jsonController,
                      maxLines: 4,
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                      decoration: const InputDecoration(
                        labelText: 'Service Account Credentials JSON *',
                        hintText: 'Dán toàn bộ nội dung file JSON vào đây...',
                        prefixIcon: Icon(Icons.key_rounded),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (saEmail != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Email Service Account (Chia sẻ Sheet cho email này):',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: SelectableText(
                                    saEmail,
                                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.content_copy_rounded, size: 18),
                                  onPressed: () => _copyToClipboard(saEmail),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isTesting ? null : _testConnection,
                            icon: _isTesting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.network_check_rounded),
                            label: const Text('Kiểm tra kết nối'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _saveSettings,
                            icon: const Icon(Icons.save_rounded),
                            label: const Text('Lưu cài đặt'),
                          ),
                        ),
                      ],
                    ),
                    if (_testResult != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _testSuccess
                              ? Colors.green.withOpacity(0.15)
                              : colorScheme.errorContainer.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _testSuccess ? Colors.green : colorScheme.error,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _testSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                              color: _testSuccess ? Colors.green : colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _testResult!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _testSuccess ? Colors.green.shade900 : colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
