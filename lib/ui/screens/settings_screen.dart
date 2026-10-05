import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/sheets_service.dart';
import '../../services/update_service.dart';
import '../../providers/cart_provider.dart';
import '../widgets/update_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedMethodIndex = 0; // 0: Apps Script (Khuyên dùng), 1: Service Account JSON

  final TextEditingController _appsScriptUrlController = TextEditingController();
  final TextEditingController _sheetIdController = TextEditingController();
  final TextEditingController _jsonController = TextEditingController();

  bool _isTesting = false;
  String? _testResult;
  bool _testSuccess = false;

  String _currentVersion = UpdateService.currentAppVersion;
  bool _isCheckingUpdate = false;
  AppUpdateInfo? _availableUpdate;

  @override
  void initState() {
    super.initState();
    final sheets = SheetsService.instance;
    _appsScriptUrlController.text = sheets.webAppUrl ?? '';
    _sheetIdController.text = sheets.spreadsheetId ?? '';
    _jsonController.text = sheets.credentialsJson ?? '';

    if (sheets.activeMode == SheetsConnectionMode.serviceAccount &&
        (sheets.spreadsheetId?.isNotEmpty ?? false)) {
      _selectedMethodIndex = 1;
    } else {
      _selectedMethodIndex = 0;
    }

    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final v = await UpdateService.instance.getCurrentVersionString();
    if (mounted) {
      setState(() {
        _currentVersion = v;
      });
    }
  }

  Future<void> _checkForUpdate() async {
    setState(() {
      _isCheckingUpdate = true;
    });

    final info = await UpdateService.instance.checkForUpdate();

    if (mounted) {
      setState(() {
        _isCheckingUpdate = false;
        _availableUpdate = info?.hasUpdate == true ? info : null;
      });

      if (info == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể kiểm tra cập nhật. Vui lòng kiểm tra kết nối mạng.'),
          ),
        );
      } else if (!info.hasUpdate) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text('Ứng dụng đang ở phiên bản mới nhất (${info.currentVersion})!'),
              ],
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
      } else {
        UpdateDialog.show(context, info);
      }
    }
  }

  @override
  void dispose() {
    _appsScriptUrlController.dispose();
    _sheetIdController.dispose();
    _jsonController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (_selectedMethodIndex == 0) {
      final url = _appsScriptUrlController.text.trim();
      if (url.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng nhập Google Apps Script Web App URL.')),
        );
        return;
      }
      await SheetsService.instance.saveAppsScriptConfig(url);
    } else {
      final sheetId = _sheetIdController.text.trim();
      final json = _jsonController.text.trim();

      if (sheetId.isEmpty || json.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng nhập đầy đủ Spreadsheet ID và JSON Service Account.')),
        );
        return;
      }
      await SheetsService.instance.saveServiceAccountConfig(
        spreadsheetId: sheetId,
        credentialsJson: json,
      );
    }

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
        _testResult = 'Kết nối thành công! Đã sẵn sàng đồng bộ 2 tab "Sản phẩm" & "Đơn hàng" trên Google Sheet.';
      });
    } catch (e) {
      setState(() {
        _isTesting = false;
        _testSuccess = false;
        _testResult = 'Kết nối thất bại: ${e.toString()}';
      });
    }
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
      ),
    );
  }

  void _showAppsScriptGuide() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.code_rounded),
            SizedBox(width: 8),
            Flexible(child: Text('Mã Script & Hướng dẫn')),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Cách thiết lập Google Apps Script (3 phút):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                const Text('1. Mở Google Sheet của shop trên máy tính/trình duyệt.'),
                const Text('2. Bấm menu: Tiện ích mở rộng (Extensions) > Apps Script.'),
                const Text('3. Xóa hết mã cũ trong file Code.gs, bấm nút sao chép bên dưới và dán vào.'),
                const Text('4. Bấm nút "Triển khai" (Deploy) góc trên bên phải > chọn "Triển khai mới" (New deployment).'),
                const Text('5. Bấm vào biểu tượng bánh răng ⚙ cạnh "Chọn loại" > chọn "Ứng dụng web" (Web app).'),
                const Text('6. Tại mục "Ai có quyền truy cập" (Who has access) > Chọn "Bất kỳ ai" (Anyone).'),
                const Text('7. Bấm "Triển khai" (Deploy) > Cấp quyền truy cập nếu Google hỏi.'),
                const Text('8. Copy đường link "URL ứng dụng web" (kết thúc bằng /exec) và dán vào app.'),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    _copyToClipboard(
                      SheetsService.googleAppsScriptTemplate,
                      'Đã sao chép mã script vào bộ nhớ tạm!',
                    );
                    Navigator.of(ctx).pop();
                  },
                  icon: const Icon(Icons.content_copy_rounded),
                  label: const Text('SAO CHÉP TOÀN BỘ MÃ SCRIPT'),
                ),
              ],
            ),
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
    final cart = context.watch<CartProvider>();
    final saEmail = SheetsService.instance.serviceAccountEmail;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt hệ thống'),
        actions: [
          IconButton(
            tooltip: 'Hướng dẫn cài đặt',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: _showAppsScriptGuide,
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

            // Card cấu hình Google Drive / Sheets
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
                          'Đồng bộ Google Sheets',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Lựa chọn phương thức kết nối
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment<int>(
                          value: 0,
                          label: Text('Apps Script (Khuyên dùng)'),
                          icon: Icon(Icons.flash_on_rounded),
                        ),
                        ButtonSegment<int>(
                          value: 1,
                          label: Text('Service Account'),
                          icon: Icon(Icons.key_rounded),
                        ),
                      ],
                      selected: {_selectedMethodIndex},
                      onSelectionChanged: (set) {
                        setState(() {
                          _selectedMethodIndex = set.first;
                          _testResult = null;
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    if (_selectedMethodIndex == 0) ...[
                      // Giao diện Google Apps Script
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.tips_and_updates_outlined, color: colorScheme.primary, size: 20),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Phương thức này không cần Google Cloud, không sợ bị chặn khóa bảo mật, áp dụng cho mọi tài khoản Google.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _appsScriptUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Google Apps Script Web App URL *',
                          hintText: 'https://script.google.com/macros/s/.../exec',
                          prefixIcon: Icon(Icons.link_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _showAppsScriptGuide,
                        icon: const Icon(Icons.code_rounded),
                        label: const Text('Lấy mã script & Xem hướng dẫn triển khai'),
                      ),
                    ] else ...[
                      // Giao diện Service Account JSON
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
                        maxLines: 3,
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                        decoration: const InputDecoration(
                          labelText: 'Service Account Credentials JSON *',
                          hintText: 'Dán nội dung file JSON vào đây...',
                          prefixIcon: Icon(Icons.key_rounded),
                        ),
                      ),
                      if (saEmail != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Email: $saEmail',
                                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                                ),
                              ),
                              IconButton(
                                iconSize: 18,
                                icon: const Icon(Icons.content_copy_rounded),
                                onPressed: () => _copyToClipboard(saEmail, 'Đã copy email!'),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                                  color: _testSuccess
                                      ? (theme.brightness == Brightness.dark ? Colors.greenAccent : Colors.green.shade900)
                                      : colorScheme.onErrorContainer,
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

            const SizedBox(height: 16),

            // Card 3: Thông tin ứng dụng & Cập nhật
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.system_update_rounded, color: colorScheme.primary),
                        const SizedBox(width: 12),
                        const Text(
                          'Phiên bản & Cập nhật',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Phiên bản hiện tại:',
                          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'v$_currentVersion',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tự động kiểm tra bản phát hành mới nhất từ GitHub Releases.',
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isCheckingUpdate ? null : _checkForUpdate,
                        icon: _isCheckingUpdate
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh_rounded),
                        label: Text(_isCheckingUpdate ? 'Đang kiểm tra...' : 'Kiểm tra bản cập nhật'),
                      ),
                    ),
                    if (_availableUpdate != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorScheme.primary.withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.new_releases_rounded, color: colorScheme.primary, size: 24),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Có bản mới v${_availableUpdate!.latestVersion}!',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    _availableUpdate!.releaseTitle,
                                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                              onPressed: () => UpdateDialog.show(context, _availableUpdate!),
                              child: const Text('Cập nhật', style: TextStyle(fontSize: 12)),
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
