package io.notapp.not_app

import android.content.ActivityNotFoundException
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "io.planora/file_opener",
        ).setMethodCallHandler { call, result ->
            if (call.method != "openFile") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val path = call.argument<String>("path")
            if (path.isNullOrBlank()) {
                result.error("INVALID_PATH", "File path is missing.", null)
                return@setMethodCallHandler
            }

            val file = File(path)
            if (!file.exists()) {
                result.error("FILE_NOT_FOUND", "File does not exist.", path)
                return@setMethodCallHandler
            }

            try {
                val uri = FileProvider.getUriForFile(
                    this,
                    "$packageName.fileprovider",
                    file,
                )
                val mimeType = call.argument<String>("mimeType")
                    ?.takeIf { it.isNotBlank() }
                    ?: "*/*"
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, mimeType)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                if (intent.resolveActivity(packageManager) == null) {
                    result.success(false)
                } else {
                    startActivity(intent)
                    result.success(true)
                }
            } catch (_: ActivityNotFoundException) {
                result.success(false)
            } catch (error: Exception) {
                result.error("OPEN_FILE_FAILED", error.message, null)
            }
        }
    }
}
