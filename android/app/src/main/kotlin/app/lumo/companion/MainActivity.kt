package app.lumo.companion

import android.app.DownloadManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var downloadManager: DownloadManager
    private var pendingDownloadId = -1L
    private val downloadReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action != DownloadManager.ACTION_DOWNLOAD_COMPLETE || intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1) != pendingDownloadId) return
            val query = DownloadManager.Query().setFilterById(pendingDownloadId)
            downloadManager.query(query).use { cursor ->
                if (!cursor.moveToFirst() || cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS)) != DownloadManager.STATUS_SUCCESSFUL) {
                    Toast.makeText(this@MainActivity, "更新下载失败，请稍后再试。", Toast.LENGTH_SHORT).show()
                    return
                }
            }
            val apk = downloadManager.getUriForDownloadedFile(pendingDownloadId) ?: return
            try {
                startActivity(Intent(Intent.ACTION_VIEW, apk).setDataAndType(apk, "application/vnd.android.package-archive").addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION))
            } catch (error: Exception) {
                Toast.makeText(this@MainActivity, "无法打开安装器。", Toast.LENGTH_SHORT).show()
            } finally {
                pendingDownloadId = -1L
            }
        }
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        downloadManager = getSystemService(DOWNLOAD_SERVICE) as DownloadManager
        val filter = IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) registerReceiver(downloadReceiver, filter, Context.RECEIVER_NOT_EXPORTED) else registerReceiver(downloadReceiver, filter)
    }

    override fun onDestroy() {
        unregisterReceiver(downloadReceiver)
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.lumo.companion/external_url")
            .setMethodCallHandler { call, result ->
                if (call.method != "downloadApk") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val uri = call.argument<String>("url")?.let(Uri::parse)
                if (uri?.scheme != "https" || uri.host != "github.com") {
                    result.error("invalid_url", "Only GitHub APK URLs are allowed", null)
                    return@setMethodCallHandler
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !packageManager.canRequestPackageInstalls()) {
                    startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")))
                    result.success("permission_required")
                    return@setMethodCallHandler
                }
                try {
                    val request = DownloadManager.Request(uri)
                        .setTitle("Lumo 更新")
                        .setDescription("正在下载最新版本")
                        .setMimeType("application/vnd.android.package-archive")
                        .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE)
                        .setDestinationInExternalFilesDir(this, Environment.DIRECTORY_DOWNLOADS, "lumo-update.apk")
                    pendingDownloadId = downloadManager.enqueue(request)
                    result.success("downloading")
                } catch (error: Exception) {
                    result.error("download_failed", error.message, null)
                }
            }
    }
}
