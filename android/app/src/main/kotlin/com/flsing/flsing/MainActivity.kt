package com.flsing.flsing

import android.app.Activity
import android.content.Intent
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val FILE_PICKER_REQUEST_CODE = 4102
    }

    private var pendingFileResult: MethodChannel.Result? = null

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
