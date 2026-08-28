package com.musicoasis.music_oasis

import android.content.ContentUris
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : AudioServiceActivity() {

    private var pendingDeleteResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result -> handleMethod(call, result) }
    }

    private fun handleMethod(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "deleteAudioFile" -> {
                val filePath = call.argument<String>("path")
                if (filePath.isNullOrBlank()) {
                    debug("deleteAudioFile: missing path")
                    result.success(mapOf("status" to "ERROR", "message" to "No file path provided."))
                    return
                }
                debug("deleteAudioFile: path=$filePath")
                deleteAudioFile(filePath, result)
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Deletes a physical audio file identified by an absolute filesystem path.
     *
     * Android 11+ (API 30+): resolves the content URI in MediaStore and asks
     * the user via the system `createDeleteRequest` dialog. The physical file
     * is removed by the MediaProvider after approval; the result is reported
     * back through [onActivityResult].
     *
     * Android 10 and below: no system delete request exists, so deletion goes
     * through ContentResolver (or a direct File delete when the file is not
     * indexed by MediaStore yet).
     */
    private fun deleteAudioFile(filePath: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val contentUri = resolveContentUri(filePath)
            debug("deleteAudioFile: resolved uri=$contentUri")
            if (contentUri == null) {
                result.success(mapOf("status" to "NOT_FOUND", "message" to "File not found in MediaStore."))
                return
            }

            try {
                val pendingIntent = MediaStore.createDeleteRequest(
                    contentResolver,
                    arrayListOf(contentUri),
                )
                debug("deleteAudioFile: launching system delete request")
                startIntentSenderForResult(
                    pendingIntent.intentSender,
                    REQUEST_DELETE,
                    null, 0, 0, 0,
                )
                pendingDeleteResult = result
            } catch (e: Exception) {
                debug("deleteAudioFile: start failed: ${e.message}")
                result.success(mapOf("status" to "ERROR", "message" to "Could not start deletion: ${e.message}"))
            }
        } else {
            deleteLegacy(filePath, result)
        }
    }

    /**
     * Tries hard to turn an absolute path into a MediaStore content URI:
     * direct lookup by _data first, then ask the media scanner to index the
     * file and look again. `null` means the file is not known to MediaStore.
     */
    private fun resolveContentUri(filePath: String): Uri? {
        queryMediaStore(filePath)?.let { return it }

        // The file may simply not be indexed yet (freshly copied, never scanned
        // by the OS). Ask the media scanner to index it, then retry.
        val jumped = java.util.concurrent.CountDownLatch(1)
        var indexed = false
        MediaScannerConnection.scanFile(
            this, arrayOf(filePath), arrayOf("audio/*"),
            object : MediaScannerConnection.OnScanCompletedListener {
                override fun onScanCompleted(path: String?, uri: Uri?) {
                    indexed = uri != null
                    jumped.countDown()
                }
            },
        )
        try {
            jumped.await(5, java.util.concurrent.TimeUnit.SECONDS)
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
        }
        debug("deleteAudioFile: scanFile indexed=$indexed")
        if (indexed) {
            queryMediaStore(filePath)?.let { return it }
        }
        return null
    }

    private fun queryMediaStore(filePath: String): Uri? {
        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
        } else {
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        }
        val projection = arrayOf(MediaStore.Audio.Media._ID)
        val selection = "${MediaStore.Audio.Media.DATA} = ?"
        contentResolver.query(collection, projection, selection, arrayOf(filePath), null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val id = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID))
                return ContentUris.withAppendedId(collection, id)
            }
        }
        return null
    }

    /** API ≤ 29: direct deletion via ContentResolver, File delete as a fallback. */
    private fun deleteLegacy(filePath: String, result: MethodChannel.Result) {
        val contentUri = queryMediaStore(filePath)
        debug("deleteLegacy: uri=$contentUri")

        if (contentUri != null) {
            try {
                val deleted = contentResolver.delete(contentUri, null, null)
                if (deleted > 0) {
                    result.success(mapOf("status" to "SUCCESS"))
                    return
                }
            } catch (e: SecurityException) {
                debug("deleteLegacy: security ${e.message}")
                result.success(mapOf("status" to "PERMISSION_DENIED", "message" to e.message))
                return
            } catch (e: Exception) {
                debug("deleteLegacy: error ${e.message}")
                result.success(mapOf("status" to "ERROR", "message" to e.message))
                return
            }
        }

        // Not indexed: the file may still be on disk and deletable with the
        // WRITE_EXTERNAL_STORAGE permission these API levels support.
        val file = File(filePath)
        if (file.exists()) {
            val deleted = file.delete()
            debug("deleteLegacy: file.delete=$deleted")
            result.success(
                mapOf(
                    "status" to if (deleted) "SUCCESS" else "ERROR",
                    "message" to "File deletion ${if (deleted) "succeeded" else "returned false"}.",
                ),
            )
        } else {
            result.success(mapOf("status" to "NOT_FOUND", "message" to "File not found on disk."))
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == REQUEST_DELETE) {
            val pending = pendingDeleteResult
            pendingDeleteResult = null
            if (pending == null) return

            debug("onActivityResult: delete result=$resultCode")
            if (resultCode == RESULT_OK) {
                // The MediaProvider deleted the file. Depending on the OEM the
                // DATA column may be gone by now; the Flutter side trusts this.
                pending.success(mapOf("status" to "SUCCESS"))
            } else {
                pending.success(mapOf("status" to "CANCELLED"))
            }
        }
    }

    private fun debug(message: String) {
        // Logged so the DELETE flow can be traced on a device. Tagged with the
        // channel name; safe to grep from logcat.
        android.util.Log.d(CHANNEL, message)
    }

    companion object {
        private const val CHANNEL = "com.musicoasis.music_oasis/file_deletion"
        private const val REQUEST_DELETE = 1001
    }
}