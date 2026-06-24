package com.titiksenyapstudio.balance

import android.content.ContentValues
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "gallery_saver"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Android 15+ (SDK 35): edge-to-edge; hindari pola cutout/fullscreen deprecated.
        // Inset ditangani di Flutter (SafeArea, AppBar, MediaQuery.padding).
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scanFile" -> {
                        val path = call.argument<String>("path")
                        if (path != null) {
                            MediaScannerConnection.scanFile(
                                applicationContext,
                                arrayOf(path),
                                null
                            ) { _, _ -> }
                            result.success(true)
                        } else {
                            result.error("INVALID_PATH", "Path is null", null)
                        }
                    }
                    "saveImage" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val fileName = call.argument<String>("fileName")
                        if (bytes == null || fileName.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "bytes or fileName is null", null)
                            return@setMethodCallHandler
                        }

                        val saved = saveImageToGallery(bytes, fileName)
                        if (saved) {
                            result.success(true)
                        } else {
                            result.error("SAVE_FAILED", "Could not save image", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun saveImageToGallery(bytes: ByteArray, fileName: String): Boolean {
        val resolver = applicationContext.contentResolver
        val displayName = if (fileName.endsWith(".png")) fileName else "$fileName.png"

        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
            put(MediaStore.MediaColumns.MIME_TYPE, "image/png")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(
                    MediaStore.MediaColumns.RELATIVE_PATH,
                    "${Environment.DIRECTORY_PICTURES}/Starvy"
                )
            }
        }

        val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            ?: return false

        return try {
            resolver.openOutputStream(uri)?.use { output ->
                output.write(bytes)
            } ?: return false
            true
        } catch (_: Exception) {
            resolver.delete(uri, null, null)
            false
        }
    }
}
