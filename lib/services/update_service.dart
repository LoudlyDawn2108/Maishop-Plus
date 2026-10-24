import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Kết quả kích hoạt trình cài đặt APK trên thiết bị
class ApkInstallResult {
  final bool success;
  final bool permissionRequired;
  final String? errorMessage;

  const ApkInstallResult({
    required this.success,
    this.permissionRequired = false,
    this.errorMessage,
  });
}

/// Thông tin chi tiết bản cập nhật ứng dụng từ GitHub Releases
class AppUpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final bool hasUpdate;
  final String releaseTitle;
  final String releaseNotes;
  final String? apkDownloadUrl;
  final String? apkFileName;
  final int? apkSize;
  final DateTime? publishedAt;

  AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.hasUpdate,
    required this.releaseTitle,
    required this.releaseNotes,
    this.apkDownloadUrl,
    this.apkFileName,
    this.apkSize,
    this.publishedAt,
  });

  String get formattedSize {
    if (apkSize == null || apkSize! <= 0) return 'Không rõ';
    final mb = apkSize! / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  static const String repoOwner = 'LoudlyDawn2108';
  static const String repoName = 'Maishop-Plus';
  static const String releasesApiUrl =
      'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';

  /// So sánh hai chuỗi phiên bản dạng x.y.z hoặc vx.y.z(+build)
  /// Trả về:
  ///   1 nếu targetVersion > currentVersion (Có bản cập nhật mới)
  ///   0 nếu hai phiên bản bằng nhau
  ///  -1 nếu targetVersion < currentVersion
  static int compareVersions(String currentVersion, String targetVersion) {
    List<int> parseVersion(String v) {
      // Loại bỏ tiền tố 'v' hoặc 'V'
      var clean = v.trim();
      if (clean.startsWith('v') || clean.startsWith('V')) {
        clean = clean.substring(1).trim();
      }

      // Tách phần build number nếu có (ví dụ 1.0.1+2)
      final parts = clean.split('+');
      final mainVersion = parts[0];
      final buildNumber = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

      final subParts = mainVersion.split('.').map((p) => int.tryParse(p) ?? 0).toList();
      while (subParts.length < 3) {
        subParts.add(0);
      }
      subParts.add(buildNumber);
      return subParts;
    }

    final cur = parseVersion(currentVersion);
    final tar = parseVersion(targetVersion);

    for (int i = 0; i < 4; i++) {
      if (tar[i] > cur[i]) return 1;
      if (tar[i] < cur[i]) return -1;
    }
    return 0;
  }

  /// Phiên bản ứng dụng hiện tại (đồng bộ với pubspec.yaml)
  static const String currentAppVersion = '1.0.4+4';

  /// Lấy chuỗi phiên bản hiện tại của app (ví dụ: 1.0.0+1)
  Future<String> getCurrentVersionString() async {
    return currentAppVersion;
  }

  /// Kiểm tra có bản phát hành mới nhất trên GitHub Releases hay không
  Future<AppUpdateInfo?> checkForUpdate({String? mockCurrentVersion}) async {
    final currentVer = mockCurrentVersion ?? await getCurrentVersionString();

    try {
      final url = Uri.parse(releasesApiUrl);
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'MaiShopPlus-Android-Updater',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final tagName = (data['tag_name'] as String? ?? '').trim();
        final releaseTitle = (data['name'] as String? ?? tagName).trim();
        final releaseNotes = (data['body'] as String? ?? '').trim();
        final publishedAtStr = data['published_at'] as String?;
        final publishedAt = publishedAtStr != null ? DateTime.tryParse(publishedAtStr) : null;

        // Trích xuất phiên bản dạng chuẩn từ tag_name (ví dụ v1.0.1 -> 1.0.1)
        var latestVer = tagName;
        if (latestVer.startsWith('v') || latestVer.startsWith('V')) {
          latestVer = latestVer.substring(1);
        }

        // Tìm file APK trong danh sách assets
        String? apkUrl;
        String? apkName;
        int? apkSize;

        final assets = data['assets'] as List<dynamic>? ?? [];
        for (var asset in assets) {
          final name = asset['name'] as String? ?? '';
          if (name.endsWith('.apk')) {
            apkUrl = asset['browser_download_url'] as String?;
            apkName = name;
            apkSize = asset['size'] as int?;
            // Ưu tiên file có tên chứa tên app
            if (name.toLowerCase().contains('maishop')) {
              break;
            }
          }
        }

        final hasUpdate = compareVersions(currentVer, latestVer) > 0;

        return AppUpdateInfo(
          currentVersion: currentVer,
          latestVersion: latestVer,
          hasUpdate: hasUpdate,
          releaseTitle: releaseTitle.isNotEmpty ? releaseTitle : 'Bản cập nhật $tagName',
          releaseNotes: releaseNotes.isNotEmpty ? releaseNotes : 'Không có ghi chú phát hành.',
          apkDownloadUrl: apkUrl,
          apkFileName: apkName ?? 'maishop-plus-release.apk',
          apkSize: apkSize,
          publishedAt: publishedAt,
        );
      } else if (response.statusCode == 404) {
        // Chưa có release nào trên GitHub
        return AppUpdateInfo(
          currentVersion: currentVer,
          latestVersion: currentVer,
          hasUpdate: false,
          releaseTitle: 'Chưa có bản phát hành',
          releaseNotes: 'Chưa có bản cập nhật nào được phát hành trên GitHub.',
        );
      } else {
        debugPrint('GitHub API lỗi HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('Lỗi kiểm tra cập nhật từ GitHub: $e');
    }

    return null;
  }

  /// Tải file APK với báo cáo tiến trình (progress: 0.0 -> 1.0)
  Future<File?> downloadApk(
    String apkUrl,
    String fileName, {
    required void Function(double progress, int receivedBytes, int totalBytes) onProgress,
    void Function(String error)? onError,
  }) async {
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(apkUrl));
      request.headers['User-Agent'] = 'MaiShopPlus-Android-Updater';

      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Lỗi kết nối tải file: HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');

      // Nếu file cũ tồn tại, xóa trước khi ghi đè
      if (await file.exists()) {
        await file.delete();
      }

      final sink = file.openWrite();
      int received = 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (contentLength > 0) {
          final progress = received / contentLength;
          onProgress(progress.clamp(0.0, 1.0), received, contentLength);
        } else {
          onProgress(-1.0, received, 0); // Không rõ tổng dung lượng
        }
      }

      await sink.flush();
      await sink.close();
      client.close();

      return file;
    } catch (e) {
      debugPrint('Lỗi tải file APK: $e');
      onError?.call(e.toString());
      return null;
    }
  }

  static const MethodChannel _installerChannel =
      MethodChannel('com.example.maishop_plus/app_installer');

  /// Kiểm tra ứng dụng đã có quyền cài đặt từ nguồn không xác định hay chưa (Android 8.0+)
  Future<bool> canRequestPackageInstalls() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final bool? result =
          await _installerChannel.invokeMethod<bool>('canRequestPackageInstalls');
      return result ?? false;
    } catch (e) {
      debugPrint('Lỗi kiểm tra quyền cài đặt APK: $e');
      return false;
    }
  }

  /// Mở màn hình Cài đặt của Android để người dùng bật quyền cài đặt từ nguồn không xác định
  Future<void> openInstallPermissionSettings() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _installerChannel.invokeMethod('openInstallPermissionSettings');
    } catch (e) {
      debugPrint('Lỗi mở màn hình cài đặt cấp quyền: $e');
    }
  }

  /// Kích hoạt trình cài đặt ứng dụng Android để cập nhật APK.
  /// Nếu [closeApp] = true, app sẽ tự kết thúc sau khi mở trình cài đặt.
  Future<ApkInstallResult> installApk(String filePath, {bool closeApp = true}) async {
    if (kIsWeb || !Platform.isAndroid) {
      return const ApkInstallResult(
        success: false,
        errorMessage: 'Tính năng cài đặt APK chỉ hỗ trợ trên nền tảng Android.',
      );
    }

    try {
      final String? res = await _installerChannel.invokeMethod<String>(
        'installApk',
        {
          'filePath': filePath,
          'closeApp': closeApp,
        },
      );

      if (res == 'SUCCESS') {
        return const ApkInstallResult(success: true);
      } else if (res == 'PERMISSION_REQUIRED') {
        return const ApkInstallResult(
          success: false,
          permissionRequired: true,
          errorMessage: 'Cần cấp quyền cài đặt ứng dụng từ nguồn không xác định.',
        );
      } else {
        return ApkInstallResult(
          success: false,
          errorMessage: 'Trạng thái cài đặt: $res',
        );
      }
    } on PlatformException catch (e) {
      debugPrint('Lỗi PlatformException khi cài APK: ${e.code} - ${e.message}');
      return ApkInstallResult(
        success: false,
        errorMessage: e.message ?? e.code,
      );
    } catch (e) {
      debugPrint('Lỗi ngoại lệ khi cài APK: $e');
      return ApkInstallResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Thoát ứng dụng một cách an toàn
  Future<void> exitApp() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _installerChannel.invokeMethod('exitApp');
    } catch (_) {
      SystemNavigator.pop();
    }
  }
}

