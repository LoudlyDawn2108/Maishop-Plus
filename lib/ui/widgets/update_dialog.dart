import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../../services/update_service.dart';

enum UpdateDownloadState {
  idle,
  downloading,
  completed,
  error,
}

class UpdateDialog extends StatefulWidget {
  final AppUpdateInfo updateInfo;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
  });

  /// Phương thức tĩnh để mở nhanh Hộp thoại Cập nhật
  static Future<void> show(BuildContext context, AppUpdateInfo updateInfo) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => UpdateDialog(updateInfo: updateInfo),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  UpdateDownloadState _state = UpdateDownloadState.idle;
  double _progress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String? _errorMessage;
  File? _downloadedApkFile;

  Future<void> _startDownload() async {
    final apkUrl = widget.updateInfo.apkDownloadUrl;
    if (apkUrl == null || apkUrl.isEmpty) {
      setState(() {
        _state = UpdateDownloadState.error;
        _errorMessage = 'Không tìm thấy link tải APK trong bản phát hành này.';
      });
      return;
    }

    setState(() {
      _state = UpdateDownloadState.downloading;
      _progress = 0.0;
      _errorMessage = null;
    });

    final fileName = widget.updateInfo.apkFileName ?? 'maishop-plus-update.apk';

    final file = await UpdateService.instance.downloadApk(
      apkUrl,
      fileName,
      onProgress: (progress, received, total) {
        if (mounted) {
          setState(() {
            _progress = progress;
            _receivedBytes = received;
            _totalBytes = total;
          });
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() {
            _state = UpdateDownloadState.error;
            _errorMessage = 'Tải file thất bại: $err';
          });
        }
      },
    );

    if (file != null && mounted) {
      setState(() {
        _state = UpdateDownloadState.completed;
        _downloadedApkFile = file;
      });

      // Tự động mở trình cài đặt ngay sau khi tải xong
      _installApk(file.path);
    }
  }

  Future<void> _installApk(String filePath) async {
    final result = await UpdateService.instance.installApk(filePath);
    if (result.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể mở bộ cài: ${result.message}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final info = widget.updateInfo;

    return PopScope(
      canPop: _state != UpdateDownloadState.downloading,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.system_update_rounded,
                color: colorScheme.primary,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cập nhật ứng dụng',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'v${info.latestVersion}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${info.formattedSize})',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280, minWidth: 300),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Text(
                  info.releaseTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
                  ),
                  child: Text(
                    info.releaseNotes,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Trạng thái tải file
                if (_state == UpdateDownloadState.downloading) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Đang tải gói cài đặt...',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.primary,
                        ),
                      ),
                      Text(
                        _progress >= 0
                            ? '${(_progress * 100).toInt()}%'
                            : '${(_receivedBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _progress >= 0 ? _progress : null,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_totalBytes > 0)
                    Text(
                      '${(_receivedBytes / (1024 * 1024)).toStringAsFixed(1)} MB / ${(_totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                      style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                    ),
                ] else if (_state == UpdateDownloadState.completed) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Đã tải xong! Trình cài đặt sẽ tự động mở.',
                            style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_state == UpdateDownloadState.error) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded, color: colorScheme.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage ?? 'Lỗi không xác định khi tải.',
                            style: TextStyle(fontSize: 12, color: colorScheme.onErrorContainer),
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
        actions: [
          if (_state != UpdateDownloadState.downloading)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                _state == UpdateDownloadState.completed ? 'ĐÓNG' : 'ĐỂ SAU',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ),
          if (_state == UpdateDownloadState.idle)
            FilledButton.icon(
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('CẬP NHẬT NGAY', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: _startDownload,
            )
          else if (_state == UpdateDownloadState.downloading)
            const SizedBox.shrink()
          else if (_state == UpdateDownloadState.completed && _downloadedApkFile != null)
            FilledButton.icon(
              icon: const Icon(Icons.install_mobile_rounded, size: 18),
              label: const Text('CÀI ĐẶT LẠI', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _installApk(_downloadedApkFile!.path),
            )
          else if (_state == UpdateDownloadState.error)
            FilledButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('THỬ LẠI'),
              onPressed: _startDownload,
            ),
        ],
      ),
    );
  }
}
