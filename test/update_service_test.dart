import 'package:flutter_test/flutter_test.dart';
import 'package:maishop_plus/services/update_service.dart';

void main() {
  group('UpdateService Version Comparison & Formatting Tests', () {
    test('So sánh phiên bản cơ bản (patch version)', () {
      expect(UpdateService.compareVersions('1.0.0', '1.0.1'), 1);
      expect(UpdateService.compareVersions('1.0.1', '1.0.0'), -1);
      expect(UpdateService.compareVersions('1.0.0', '1.0.0'), 0);
    });

    test('Xử lý tiền tố v / V hoa thường', () {
      expect(UpdateService.compareVersions('v1.0.0', 'v1.0.5'), 1);
      expect(UpdateService.compareVersions('V1.2.0', 'v1.1.9'), -1);
      expect(UpdateService.compareVersions('v1.0.0', '1.0.0'), 0);
    });

    test('So sánh phiên bản lớn (major & minor)', () {
      expect(UpdateService.compareVersions('1.9.9', '2.0.0'), 1);
      expect(UpdateService.compareVersions('1.2.0', '1.10.0'), 1);
      expect(UpdateService.compareVersions('2.1.0', '2.0.9'), -1);
    });

    test('So sánh có kèm build number (+1, +2)', () {
      expect(UpdateService.compareVersions('1.0.0+1', '1.0.0+2'), 1);
      expect(UpdateService.compareVersions('1.0.0+2', '1.0.0+1'), -1);
      expect(UpdateService.compareVersions('1.0.0+1', '1.0.1+1'), 1);
    });

    test('Định dạng dung lượng file APK chuẩn', () {
      final info1 = AppUpdateInfo(
        currentVersion: '1.0.0',
        latestVersion: '1.0.1',
        hasUpdate: true,
        releaseTitle: 'Bản vá lỗi v1.0.1',
        releaseNotes: 'Fixes',
        apkSize: 25 * 1024 * 1024, // 25 MB
      );
      expect(info1.formattedSize, '25.0 MB');

      final info2 = AppUpdateInfo(
        currentVersion: '1.0.0',
        latestVersion: '1.0.0',
        hasUpdate: false,
        releaseTitle: '',
        releaseNotes: '',
        apkSize: null,
      );
      expect(info2.formattedSize, 'Không rõ');
    });

    test('Phiên bản hiện tại đồng bộ 1.0.4+4', () {
      expect(UpdateService.currentAppVersion, '1.0.4+4');
    });

    test('Khởi tạo ApkInstallResult chính xác theo từng trạng thái', () {
      const resSuccess = ApkInstallResult(success: true);
      expect(resSuccess.success, isTrue);
      expect(resSuccess.permissionRequired, isFalse);
      expect(resSuccess.errorMessage, isNull);

      const resPerm = ApkInstallResult(
        success: false,
        permissionRequired: true,
        errorMessage: 'Cần cấp quyền',
      );
      expect(resPerm.success, isFalse);
      expect(resPerm.permissionRequired, isTrue);
      expect(resPerm.errorMessage, 'Cần cấp quyền');

      const resErr = ApkInstallResult(
        success: false,
        errorMessage: 'Lỗi IO',
      );
      expect(resErr.success, isFalse);
      expect(resErr.permissionRequired, isFalse);
      expect(resErr.errorMessage, 'Lỗi IO');
    });
  });
}
