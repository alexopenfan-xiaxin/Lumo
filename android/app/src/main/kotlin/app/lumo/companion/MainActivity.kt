package app.lumo.companion

import android.Manifest
import android.app.DownloadManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    companion object {
        private const val SPEECH_PERMISSION_REQUEST = 9031
    }

    private lateinit var downloadManager: DownloadManager
    private var pendingDownloadId = -1L
    private var speechRecognizer: SpeechRecognizer? = null
    private var pendingSpeechResult: MethodChannel.Result? = null
    private var startSpeechAfterPermission = false
    private var stopSpeechAfterPermission = false
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
        speechRecognizer?.destroy()
        pendingSpeechResult?.error("cancelled", "语音输入已取消。", null)
        pendingSpeechResult = null
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
                    getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
                        ?.listFiles { file -> file.name.startsWith("lumo-update-") && file.extension == "apk" }
                        ?.forEach { file -> file.delete() }
                    val request = DownloadManager.Request(uri)
                        .setTitle("Lumo 更新")
                        .setDescription("正在下载最新版本")
                        .setMimeType("application/vnd.android.package-archive")
                        .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE)
                        .setDestinationInExternalFilesDir(this, Environment.DIRECTORY_DOWNLOADS, "lumo-update-${System.currentTimeMillis()}.apk")
                    pendingDownloadId = downloadManager.enqueue(request)
                    result.success("downloading")
                } catch (error: Exception) {
                    result.error("download_failed", error.message, null)
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.lumo.companion/speech")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        if (pendingSpeechResult != null) {
                            result.error("busy", "正在倾听，请稍候。", null)
                            return@setMethodCallHandler
                        }
                        pendingSpeechResult = result
                        stopSpeechAfterPermission = false
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                            startSpeechAfterPermission = true
                            requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), SPEECH_PERMISSION_REQUEST)
                        } else {
                            startSpeechRecognition()
                        }
                    }
                    "stop" -> {
                        stopSpeechAfterPermission = true
                        speechRecognizer?.stopListening()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.lumo.companion/device")
            .setMethodCallHandler { call, result ->
                if (call.method != "getId") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val androidId = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
                val digest = MessageDigest.getInstance("SHA-256").digest("$packageName:$androidId".toByteArray())
                result.success(digest.take(16).joinToString("") { "%02x".format(it) })
            }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != SPEECH_PERMISSION_REQUEST || !startSpeechAfterPermission) return
        startSpeechAfterPermission = false
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            if (stopSpeechAfterPermission) finishSpeech("") else startSpeechRecognition()
        } else {
            finishSpeechError("permission_denied", "请允许麦克风权限后再使用语音输入。")
        }
    }

    private fun startSpeechRecognition() {
        if (stopSpeechAfterPermission) {
            finishSpeech("")
            return
        }
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            finishSpeechError("unavailable", "这台设备暂不支持语音识别。")
            return
        }
        speechRecognizer?.destroy()
        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this).apply {
            setRecognitionListener(object : RecognitionListener {
                override fun onResults(results: Bundle) {
                    val text = results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull().orEmpty()
                    finishSpeech(text)
                }

                override fun onError(error: Int) {
                    if (error == SpeechRecognizer.ERROR_NO_MATCH || error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT || error == SpeechRecognizer.ERROR_CLIENT) {
                        finishSpeech("")
                    } else {
                        finishSpeechError("recognition_failed", "语音识别服务暂时不可用，请检查网络或系统语音服务。")
                    }
                }
                override fun onReadyForSpeech(params: Bundle) = Unit
                override fun onBeginningOfSpeech() = Unit
                override fun onRmsChanged(rmsdB: Float) = Unit
                override fun onBufferReceived(buffer: ByteArray) = Unit
                override fun onEndOfSpeech() = Unit
                override fun onPartialResults(partialResults: Bundle) = Unit
                override fun onEvent(eventType: Int, params: Bundle) = Unit
            })
            startListening(
                Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                    .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    .putExtra(RecognizerIntent.EXTRA_LANGUAGE, "zh-CN")
                    .putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            )
        }
    }

    private fun finishSpeechError(code: String, message: String) {
        pendingSpeechResult?.error(code, message, null)
        pendingSpeechResult = null
        stopSpeechAfterPermission = false
    }

    private fun finishSpeech(text: String) {
        pendingSpeechResult?.success(text)
        pendingSpeechResult = null
        stopSpeechAfterPermission = false
    }
}
