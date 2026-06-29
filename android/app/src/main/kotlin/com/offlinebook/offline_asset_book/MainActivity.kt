package com.offlinebook.offline_asset_book

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val backupChannelName = "offline_asset_book/backup_file"
    private val createBackupRequestCode = 9401
    private var pendingCreateResult: MethodChannel.Result? = null
    private var pendingCreateFileName: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, backupChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "chooseBackupDestination" -> {
                        if (pendingCreateResult != null) {
                            result.error(
                                "backup_export_in_progress",
                                "已有导出操作正在进行",
                                null
                            )
                            return@setMethodCallHandler
                        }
                        val fileName = call.argument<String>("fileName")
                            ?: "asset_book_backup.assetbook"
                        pendingCreateResult = result
                        pendingCreateFileName = fileName
                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "application/json"
                            putExtra(Intent.EXTRA_TITLE, fileName)
                        }
                        try {
                            startActivityForResult(intent, createBackupRequestCode)
                        } catch (error: Exception) {
                            pendingCreateResult = null
                            pendingCreateFileName = null
                            result.error(
                                "backup_destination_unavailable",
                                error.localizedMessage,
                                null
                            )
                        }
                    }
                    "writeBackupToUri" -> {
                        val uriText = call.argument<String>("uri")
                        val contents = call.argument<String>("contents")
                        if (uriText.isNullOrEmpty() || contents == null) {
                            result.error(
                                "invalid_arguments",
                                "缺少导出文件地址或内容",
                                null
                            )
                            return@setMethodCallHandler
                        }
                        try {
                            contentResolver.openOutputStream(Uri.parse(uriText), "wt")
                                ?.bufferedWriter(Charsets.UTF_8)
                                ?.use { writer -> writer.write(contents) }
                                ?: throw IllegalStateException("无法打开导出文件")
                            result.success(null)
                        } catch (error: Exception) {
                            result.error(
                                "backup_write_failed",
                                error.localizedMessage,
                                null
                            )
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != createBackupRequestCode) return

        val result = pendingCreateResult
        val fallbackFileName = pendingCreateFileName ?: "asset_book_backup.assetbook"
        pendingCreateResult = null
        pendingCreateFileName = null

        if (result == null) return
        if (resultCode != Activity.RESULT_OK) {
            result.success(null)
            return
        }

        val uri = data?.data
        if (uri == null) {
            result.success(null)
            return
        }

        val flags = data.flags and
            (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        try {
            contentResolver.takePersistableUriPermission(uri, flags)
        } catch (_: Exception) {
            // Some providers grant only transient access. Writing immediately still works.
        }

        result.success(
            mapOf(
                "uri" to uri.toString(),
                "fileName" to (displayName(uri) ?: fallbackFileName),
            )
        )
    }

    private fun displayName(uri: Uri): String? {
        return contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index >= 0 && cursor.moveToFirst()) cursor.getString(index) else null
        }
    }
}
