package com.example.maishop_plus

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.maishop_plus/app_installer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "canRequestPackageInstalls" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        result.success(packageManager.canRequestPackageInstalls())
                    } else {
                        result.success(true)
                    }
                }
                "openInstallPermissionSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.localizedMessage, null)
                    }
                }
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    val closeApp = call.argument<Boolean>("closeApp") ?: false

                    if (filePath.isNullOrEmpty()) {
                        result.error("INVALID_PATH", "Đường dẫn tệp APK không hợp lệ", null)
                        return@setMethodCallHandler
                    }

                    val file = File(filePath)
                    if (!file.exists()) {
                        result.error("FILE_NOT_FOUND", "Không tìm thấy tệp APK tại: $filePath", null)
                        return@setMethodCallHandler
                    }

                    // Kiểm tra quyền cài đặt từ nguồn không xác định trên Android 8.0+
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !packageManager.canRequestPackageInstalls()) {
                        try {
                            val settingsIntent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(settingsIntent)
                            result.success("PERMISSION_REQUIRED")
                            return@setMethodCallHandler
                        } catch (e: Exception) {
                            result.error("PERMISSION_ERROR", "Không thể mở cài đặt cấp quyền: ${e.localizedMessage}", null)
                            return@setMethodCallHandler
                        }
                    }

                    try {
                        val apkUri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                            FileProvider.getUriForFile(
                                applicationContext,
                                "$packageName.fileprovider",
                                file
                            )
                        } else {
                            Uri.fromFile(file)
                        }

                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(apkUri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)

                        if (closeApp) {
                            // Chờ 500ms để hệ thống hiển thị Activity PackageInstaller trước khi đóng app
                            window.decorView.postDelayed({
                                finishAffinity()
                            }, 500)
                        }

                        result.success("SUCCESS")
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", "Lỗi khi kích hoạt trình cài đặt: ${e.localizedMessage}", null)
                    }
                }
                "exitApp" -> {
                    try {
                        finishAffinity()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("EXIT_ERROR", e.localizedMessage, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
