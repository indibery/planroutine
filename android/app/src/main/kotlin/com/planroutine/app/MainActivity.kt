package com.planroutine.app

import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * 다른 앱이 CSV를 "공직플랜으로 열기"(ACTION_VIEW)나 공유(ACTION_SEND)로 넘길 때 받는다.
 * iOS `AppDelegate`와 **같은 채널 계약**을 쓴다 — `planroutine/shared_file`,
 * Dart→native `getPending`, native→Dart `onFileShared`.
 *
 * ⚠️ **iOS와 결정적으로 다른 점: Android는 파일 경로가 아니라 `content://` URI를 준다.**
 * 거기엔 확장자가 없는데(`content://…/document/12`) Dart의 `_handleSharedFile`은
 * `.csv`로 끝나지 않는 경로를 **조용히 버린다**. 그래서 스트림을 캐시로 복사하면서
 * 확장자를 강제한다 — 안 하면 공유 목록에는 뜨는데 탭해도 아무 일이 없는,
 * 알림 M1과 같은 "증상 0의 실패"가 된다.
 *
 * ⚠️ 열기 필터가 와일드카드 mime까지 받으므로 CSV가 아닌 파일로도 앱이 열릴 수 있다.
 * 그때는 Dart가 조용히 버린다(기존 iOS 동작과 같다) — 사용자에게 알려주려면 Dart를 손대야 한다.
 *
 * ⚠️ **이 주석에 와일드카드 mime을 문자 그대로 적지 말 것.** 별표+슬래시가 블록 주석을
 * 그 자리에서 닫아 버려 파일 전체가 syntax error가 된다(실측 2026-08-14: 처음 그렇게 적어
 * `Expecting a top level declaration` 열 줄을 받았다). 매니페스트에서는 그대로 써도 된다.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    /**
     * 엔진 준비 전에 도착한 경로를 담아 두는 자리. iOS `AppDelegate.pendingPath`와 같은
     * 역할이다 — cold-start에서는 Dart가 아직 핸들러를 안 걸어 `onFileShared`가 버려지고,
     * Dart의 `initState`가 `getPending`으로 한 번 꺼내 간다.
     */
    private var pendingPath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPending" -> {
                    result.success(pendingPath)
                    pendingPath = null
                }
                else -> result.notImplemented()
            }
        }

        // cold-start: 액티비티를 띄운 인텐트가 이미 손에 있다.
        handleIntent(intent)
    }

    /**
     * 앱이 이미 떠 있을 때의 두 번째 공유. 이것이 없으면 "한 번은 되고 두 번째는 안 되는"
     * 증상이 된다.
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val uri = uriOf(intent) ?: return
        val path = copyToCache(uri) ?: return
        pendingPath = path
        channel?.invokeMethod("onFileShared", path)
    }

    /** 열기는 `data`, 공유는 `EXTRA_STREAM`으로 온다 — 같은 URI가 다른 자리에 실린다. */
    @Suppress("DEPRECATION")
    private fun uriOf(intent: Intent?): Uri? = when (intent?.action) {
        Intent.ACTION_VIEW -> intent.data
        Intent.ACTION_SEND -> intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri
        else -> null
    }

    /**
     * content:// 스트림을 캐시 파일로 복사하고 **`.csv` 확장자를 강제**한다.
     * 파일 이름은 `DISPLAY_NAME`으로 살린다 — 가져오기 화면에서 무슨 파일인지 보여야 한다.
     */
    private fun copyToCache(uri: Uri): String? {
        return try {
            val raw = displayName(uri) ?: "shared"
            val base = raw.substringBeforeLast('.', raw).ifBlank { "shared" }
            val out = File(cacheDir, "$base.csv")
            val input = contentResolver.openInputStream(uri) ?: return null
            input.use { stream -> out.outputStream().use { stream.copyTo(it) } }
            out.absolutePath
        } catch (e: Exception) {
            // 권한 만료·취소된 URI 등. 조용히 포기한다 — 사용자는 가져오기 화면에서
            // 파일을 직접 고를 수 있다.
            null
        }
    }

    private fun displayName(uri: Uri): String? = contentResolver
        .query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
        ?.use { c -> if (c.moveToFirst()) c.getString(0) else null }

    private companion object {
        /** iOS `AppDelegate`와 같은 이름이어야 한다. 가드가 양방향으로 대조한다. */
        const val CHANNEL = "planroutine/shared_file"
    }
}
