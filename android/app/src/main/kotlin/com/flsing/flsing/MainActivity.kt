package com.flsing.flsing

import android.app.Activity
import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.provider.OpenableColumns
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val FILE_PICKER_REQUEST_CODE = 4102
        private const val UPDATE_CHANNEL = "flsing/app_update"
        private const val DEVICE_CHANNEL = "flsing/device"
    }

    private var pendingFileResult: MethodChannel.Result? = null
    private var pendingApk: File? = null

    override fun onResume() {
        super.onResume()
        val apk = pendingApk ?: return
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O || packageManager.canRequestPackageInstalls()) {
            pendingApk = null
            launchInstaller(apk)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != FILE_PICKER_REQUEST_CODE) return
        val result = pendingFileResult ?: return
        pendingFileResult = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        runCatching { copyToPrivateStorage(uri.toString()) }
            .onSuccess(result::success)
            .onFailure { result.error("FILE_IMPORT_FAILED", it.message, null) }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "flsing/configuration_file")
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                if (call.method != "pickFile") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (pendingFileResult != null) {
                    result.error("PICKER_BUSY", "已有文件选择请求正在处理", null)
                    return@setMethodCallHandler
                }
                pendingFileResult = result
                startActivityForResult(
                    Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                        putExtra(
                            Intent.EXTRA_MIME_TYPES,
                            arrayOf("application/json", "application/yaml", "text/yaml", "text/plain", "application/octet-stream"),
                        )
                    },
                    FILE_PICKER_REQUEST_CODE,
                )
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATE_CHANNEL)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                when (call.method) {
                    "getSupportedAbis" -> result.success(Build.SUPPORTED_ABIS.toList())
                    "installApk" -> installApk(call.arguments, result)
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_CHANNEL)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                when (call.method) {
                    "isIgnoringBatteryOptimizations" -> result.success(isIgnoringBatteryOptimizations())
                    "requestIgnoreBatteryOptimizations" -> requestIgnoreBatteryOptimizations(result)
                    "shareFile" -> shareFile(call.arguments, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        val manager = getSystemService(Context.POWER_SERVICE) as PowerManager
        return manager.isIgnoringBatteryOptimizations(packageName)
    }

    private fun requestIgnoreBatteryOptimizations(result: MethodChannel.Result) {
        if (isIgnoringBatteryOptimizations()) {
            result.success(null)
            return
        }
        runCatching {
            startActivity(
                Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = android.net.Uri.parse("package:$packageName")
                },
            )
        }.onSuccess { result.success(null) }
            .onFailure { result.error("BATTERY_OPTIMIZATION_REQUEST_FAILED", it.message, null) }
    }

    private fun shareFile(arguments: Any?, result: MethodChannel.Result) {
        val values = arguments as? Map<*, *> ?: run {
            result.error("SHARE_FILE_INVALID", "Missing file arguments", null)
            return
        }
        val file = (values["path"] as? String)?.let(::File)
        if (file == null || !file.isFile) {
            result.error("SHARE_FILE_NOT_FOUND", "The file to share was not found", null)
            return
        }
        val mimeType = values["mimeType"] as? String ?: "text/plain"
        val title = values["title"] as? String ?: "Share"
        runCatching {
            val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
            startActivity(
                Intent.createChooser(
                    Intent(Intent.ACTION_SEND).apply {
                        type = mimeType
                        putExtra(Intent.EXTRA_STREAM, uri)
                        clipData = ClipData.newRawUri(file.name, uri)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    },
                    title,
                ),
            )
        }.onSuccess { result.success(null) }
            .onFailure { result.error("SHARE_FILE_FAILED", it.message, null) }
    }

    private fun installApk(arguments: Any?, result: MethodChannel.Result) {
        val path = arguments as? String
        val apk = path?.let(::File)
        if (apk == null || !apk.isFile) {
            result.error("APK_NOT_FOUND", "找不到已下载的安装包", null)
            return
        }
        runCatching { requestInstall(apk) }
            .onSuccess { result.success(null) }
            .onFailure { result.error("INSTALL_FAILED", it.message, null) }
    }

    private fun requestInstall(apk: File) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !packageManager.canRequestPackageInstalls()) {
            pendingApk = apk
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    android.net.Uri.parse("package:$packageName"),
                ),
            )
            return
        }
        launchInstaller(apk)
    }

    private fun launchInstaller(apk: File) {
        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", apk)
        startActivity(
            Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            },
        )
    }

    private fun copyToPrivateStorage(uriString: String): String {
        val uri = android.net.Uri.parse(uriString)
        val filename = contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (cursor.moveToFirst() && index >= 0) cursor.getString(index) else null
        } ?: "subscription.json"
        val importDir = File(filesDir, "imports").apply { mkdirs() }
        val target = File(importDir, "${System.currentTimeMillis()}_${filename.replace(Regex("[^A-Za-z0-9._-]"), "_")}")
        contentResolver.openInputStream(uri).use { input ->
            requireNotNull(input) { "无法读取所选文件" }
            target.outputStream().use(input::copyTo)
        }
        return target.absolutePath
    }
}
