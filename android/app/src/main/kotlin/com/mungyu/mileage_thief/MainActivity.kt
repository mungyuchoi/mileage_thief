package com.mungyu.mileage_thief

import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val shareChannelName = "milecatch/share_intent"
    private var shareChannel: MethodChannel? = null
    private var pendingSharedContent: Map<String, Any?>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, shareChannelName)
        pendingSharedContent = extractSharedContent(intent)

        shareChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialSharedContent" -> result.success(pendingSharedContent)
                "clearInitialSharedContent" -> {
                    pendingSharedContent = null
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        val sharedContent = extractSharedContent(intent) ?: return
        pendingSharedContent = sharedContent
        shareChannel?.invokeMethod("onSharedContent", sharedContent)
    }

    @Suppress("DEPRECATION")
    private fun extractSharedContent(intent: Intent?): Map<String, Any?>? {
        if (intent == null) return null

        val action = intent.action
        if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) {
            return null
        }

        val sharedText = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)
            ?.toString()
            ?.trim()
            .orEmpty()
        val subjectExtra = intent.getCharSequenceExtra(Intent.EXTRA_SUBJECT)
            ?: intent.getCharSequenceExtra(Intent.EXTRA_TITLE)
        val sharedSubject = subjectExtra?.toString()?.trim().orEmpty()
        val imageUris = mutableListOf<Uri>()

        if (action == Intent.ACTION_SEND_MULTIPLE) {
            intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                ?.let { imageUris.addAll(it) }
        } else {
            intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                ?.let { imageUris.add(it) }
        }

        intent.clipData?.let { clipData ->
            for (index in 0 until clipData.itemCount) {
                clipData.getItemAt(index).uri?.let { uri ->
                    if (!imageUris.contains(uri)) imageUris.add(uri)
                }
            }
        }

        val copiedImagePaths = imageUris
            .filter { isImageUri(it) }
            .mapIndexedNotNull { index, uri -> copySharedImageToCache(uri, index) }

        if (sharedText.isEmpty() && sharedSubject.isEmpty() && copiedImagePaths.isEmpty()) {
            return null
        }

        return mapOf(
            "text" to sharedText,
            "subject" to sharedSubject,
            "imagePaths" to copiedImagePaths,
        )
    }

    private fun isImageUri(uri: Uri): Boolean {
        val mimeType = contentResolver.getType(uri).orEmpty()
        if (mimeType.startsWith("image/")) return true

        val extension = MimeTypeMap.getFileExtensionFromUrl(uri.toString())
            .lowercase(Locale.ROOT)
        return extension in setOf("jpg", "jpeg", "png", "gif", "webp")
    }

    private fun copySharedImageToCache(uri: Uri, index: Int): String? {
        return try {
            val extension = resolveExtension(uri)
            val targetDir = File(cacheDir, "shared_images").apply { mkdirs() }
            val targetFile = File(
                targetDir,
                "shared_${System.currentTimeMillis()}_${index}.$extension"
            )

            contentResolver.openInputStream(uri)?.use { input ->
                targetFile.outputStream().use { output -> input.copyTo(output) }
            } ?: return null

            targetFile.absolutePath
        } catch (e: Exception) {
            null
        }
    }

    private fun resolveExtension(uri: Uri): String {
        val mimeType = contentResolver.getType(uri)
        val extensionFromMime = mimeType
            ?.let { MimeTypeMap.getSingleton().getExtensionFromMimeType(it) }
            ?.lowercase(Locale.ROOT)
        if (!extensionFromMime.isNullOrBlank()) return extensionFromMime

        val displayName = queryDisplayName(uri)
        val extensionFromName = displayName
            ?.substringAfterLast('.', missingDelimiterValue = "")
            ?.lowercase(Locale.ROOT)
        if (!extensionFromName.isNullOrBlank()) return extensionFromName

        return "jpg"
    }

    private fun queryDisplayName(uri: Uri): String? {
        return try {
            contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME),
                null,
                null,
                null
            )
                ?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (index >= 0) cursor.getString(index) else null
                    } else {
                        null
                    }
                }
        } catch (e: Exception) {
            null
        }
    }
}
