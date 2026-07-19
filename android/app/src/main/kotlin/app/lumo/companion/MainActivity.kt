package app.lumo.companion

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.Locale

class MainActivity : FlutterActivity() {
    companion object {
        private const val SPEECH_PERMISSION_REQUEST = 9031
    }

    private var speechRecognizer: SpeechRecognizer? = null
    private var textToSpeech: TextToSpeech? = null
    private var pendingSpeechResult: MethodChannel.Result? = null
    private var startSpeechAfterPermission = false
    private var stopSpeechAfterPermission = false
    override fun onDestroy() {
        speechRecognizer?.destroy()
        textToSpeech?.stop()
        textToSpeech?.shutdown()
        pendingSpeechResult?.error("cancelled", "语音输入已取消。", null)
        pendingSpeechResult = null
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.lumo.companion/external_url")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canRequestPackageInstalls" -> result.success(Build.VERSION.SDK_INT < Build.VERSION_CODES.O || packageManager.canRequestPackageInstalls())
                    "openInstallSettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")))
                        result.success(null)
                    }
                    "updateDirectory" -> result.success(File(cacheDir, "updates").absolutePath)
                    "installApk" -> {
                        try {
                            val path = call.argument<String>("path")
                            val apk = path?.let(::File)
                            val updateDirectory = File(cacheDir, "updates").canonicalFile
                            if (apk == null || !apk.isFile || apk.canonicalFile.parentFile != updateDirectory) {
                                result.error("install_missing", "安装包不存在或未下载完成。", null)
                                return@setMethodCallHandler
                            }
                            val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", apk)
                            startActivity(Intent(Intent.ACTION_VIEW)
                                .setDataAndType(uri, "application/vnd.android.package-archive")
                                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK))
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("install_failed", "无法打开安装器（${error.javaClass.simpleName}）：${error.message ?: "未知错误"}", null)
                        }
                    }
                    else -> result.notImplemented()
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
                    "speak" -> {
                        val text = call.argument<String>("text")?.trim()
                        if (text.isNullOrEmpty()) {
                            result.error("empty_text", "没有可播放的语音内容。", null)
                        } else if (text.length > TextToSpeech.getMaxSpeechInputLength()) {
                            result.error("text_too_long", "语音回复过长，无法播放。", null)
                        } else {
                            speak(text, result)
                        }
                    }
                    "stopSpeaking" -> {
                        textToSpeech?.stop()
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
                    finishSpeechError("recognition_failed", recognitionErrorMessage(error))
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

    private fun recognitionErrorMessage(error: Int) = when (error) {
        SpeechRecognizer.ERROR_NO_MATCH -> "没有识别到清晰的语音，请重试。"
        SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "未检测到语音，请按住后再说话。"
        SpeechRecognizer.ERROR_CLIENT -> "系统语音识别已取消，请重试。"
        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "麦克风权限不足，请在系统设置中允许。"
        SpeechRecognizer.ERROR_NETWORK, SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "语音识别网络不可用，请检查网络后重试。"
        SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "系统语音识别服务正忙，请稍后重试。"
        else -> "语音识别服务暂时不可用，请检查网络或系统语音服务。"
    }

    private fun speak(text: String, result: MethodChannel.Result) {
        val tts = textToSpeech
        if (tts != null) {
            speakWith(tts, text, result)
            return
        }
        textToSpeech = TextToSpeech(this) { status ->
            val initialized = textToSpeech
            if (status != TextToSpeech.SUCCESS || initialized == null) {
                result.error("tts_unavailable", "这台设备暂不支持系统语音播报。", null)
            } else {
                speakWith(initialized, text, result)
            }
        }
    }

    private fun speakWith(tts: TextToSpeech, text: String, result: MethodChannel.Result) {
        val language = tts.setLanguage(Locale.SIMPLIFIED_CHINESE)
        if (language == TextToSpeech.LANG_MISSING_DATA || language == TextToSpeech.LANG_NOT_SUPPORTED) {
            result.error("tts_language_unavailable", "系统未安装中文语音，请在系统设置中下载后重试。", null)
            return
        }
        if (tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, "lumo-reply") == TextToSpeech.ERROR) {
            result.error("tts_failed", "系统语音播报启动失败。", null)
        } else {
            result.success(null)
        }
    }
}
