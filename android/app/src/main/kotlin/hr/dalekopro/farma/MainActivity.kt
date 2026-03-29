package hr.dalekopro.farma

import android.app.Activity
import android.database.Cursor
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Point
import android.net.Uri
import android.os.Build
import android.util.Size
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.provider.DocumentsContract.Document
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.ByteArrayOutputStream
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "dalekopro/saf"
    private val requestOpenTree = 4101

    private var pendingTreeResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "selectDocumentTree" -> {
                        if (pendingTreeResult != null) {
                            result.error("BUSY", "Tree selection already in progress.", null)
                            return@setMethodCallHandler
                        }

                        val initialTreeUri = call.argument<String>("initialTreeUri")
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                            addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
                            if (!initialTreeUri.isNullOrBlank()) {
                                putExtra(DocumentsContract.EXTRA_INITIAL_URI, Uri.parse(initialTreeUri))
                            }
                        }

                        pendingTreeResult = result
                        startActivityForResult(intent, requestOpenTree)
                    }

                    "pickImageFromTree" -> {
                        val treeUri = call.argument<String>("treeUri")
                        if (treeUri.isNullOrBlank()) {
                            result.error("INVALID_ARGUMENT", "treeUri is required.", null)
                            return@setMethodCallHandler
                        }

                        result.success(mapOf("treeUri" to treeUri))
                    }

                    "listImagesFromTree" -> {
                        val treeUri = call.argument<String>("treeUri")
                        if (treeUri.isNullOrBlank()) {
                            result.error("INVALID_ARGUMENT", "treeUri is required.", null)
                            return@setMethodCallHandler
                        }

                        try {
                            result.success(listImagesFromTree(Uri.parse(treeUri)))
                        } catch (error: Exception) {
                            result.error("LIST_ERROR", error.message, null)
                        }
                    }

                    "copyDocumentToCache" -> {
                        val documentUri = call.argument<String>("documentUri")
                        val suggestedFileName = call.argument<String>("suggestedFileName")
                        if (documentUri.isNullOrBlank()) {
                            result.error("INVALID_ARGUMENT", "documentUri is required.", null)
                            return@setMethodCallHandler
                        }

                        try {
                            val filePath = copyDocumentToCache(Uri.parse(documentUri), suggestedFileName)
                            result.success(mapOf("filePath" to filePath))
                        } catch (error: Exception) {
                            result.error("READ_ERROR", error.message, null)
                        }
                    }

                    "loadDocumentThumbnail" -> {
                        val documentUri = call.argument<String>("documentUri")
                        val width = call.argument<Int>("width") ?: 512
                        val height = call.argument<Int>("height") ?: 512
                        if (documentUri.isNullOrBlank()) {
                            result.error("INVALID_ARGUMENT", "documentUri is required.", null)
                            return@setMethodCallHandler
                        }

                        try {
                            result.success(loadDocumentThumbnail(Uri.parse(documentUri), width, height))
                        } catch (_: Exception) {
                            result.success(null)
                        }
                    }

                    "deleteDocument" -> {
                        val documentUri = call.argument<String>("documentUri")
                        if (documentUri.isNullOrBlank()) {
                            result.error("INVALID_ARGUMENT", "documentUri is required.", null)
                            return@setMethodCallHandler
                        }

                        try {
                            result.success(deleteDocument(Uri.parse(documentUri)))
                        } catch (error: Exception) {
                            result.error("DELETE_ERROR", error.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == requestOpenTree) {
            val result = pendingTreeResult
            pendingTreeResult = null
            handleTreeSelection(result, resultCode, data)
            return
        }

    }

    private fun handleTreeSelection(result: MethodChannel.Result?, resultCode: Int, data: Intent?) {
        if (result == null) return
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }

        val treeUri = data.data!!
        val flags = data.flags and
            (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)

        contentResolver.takePersistableUriPermission(treeUri, flags)
        result.success(mapOf("treeUri" to treeUri.toString()))
    }

    private fun resolveFileName(uri: Uri): String? {
        contentResolver.query(uri, null, null, null, null).use { cursor ->
            if (cursor == null || !cursor.moveToFirst()) return null
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index < 0) return null
            return cursor.getString(index)
        }
    }

    private fun listImagesFromTree(treeUri: Uri): List<Map<String, Any?>> {
        val treeDocumentUri = DocumentsContract.buildDocumentUriUsingTree(
            treeUri,
            DocumentsContract.getTreeDocumentId(treeUri)
        )
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
            treeUri,
            DocumentsContract.getDocumentId(treeDocumentUri)
        )

        val projection = arrayOf(
            Document.COLUMN_DOCUMENT_ID,
            Document.COLUMN_DISPLAY_NAME,
            Document.COLUMN_MIME_TYPE,
            Document.COLUMN_LAST_MODIFIED,
            Document.COLUMN_SIZE,
        )

        val results = mutableListOf<Map<String, Any?>>()
        contentResolver.query(childrenUri, projection, null, null, null).use { cursor ->
            if (cursor == null) return emptyList()
            while (cursor.moveToNext()) {
                val mimeType = cursor.getStringOrNull(Document.COLUMN_MIME_TYPE) ?: continue
                if (!mimeType.startsWith("image/")) {
                    continue
                }

                val documentId = cursor.getStringOrNull(Document.COLUMN_DOCUMENT_ID) ?: continue
                val documentUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, documentId)

                results.add(
                    mapOf(
                        "uri" to documentUri.toString(),
                        "displayName" to (cursor.getStringOrNull(Document.COLUMN_DISPLAY_NAME) ?: ""),
                        "mimeType" to mimeType,
                        "lastModifiedMillis" to cursor.getLongOrNull(Document.COLUMN_LAST_MODIFIED),
                        "sizeBytes" to cursor.getLongOrNull(Document.COLUMN_SIZE),
                    )
                )
            }
        }
        return results
    }

    private fun copyDocumentToCache(documentUri: Uri, suggestedFileName: String?): String {
        val safeFileName = sanitizeFileName(
            suggestedFileName?.takeIf { it.isNotBlank() } ?: resolveFileName(documentUri)
        ) ?: "picked_image_${System.currentTimeMillis()}.jpg"
        val targetFile = File(cacheDir, safeFileName)

        contentResolver.openInputStream(documentUri).use { input ->
            requireNotNull(input) { "Could not read selected image." }
            FileOutputStream(targetFile).use { output ->
                input.copyTo(output)
            }
        }

        return targetFile.absolutePath
    }

    private fun loadDocumentThumbnail(documentUri: Uri, width: Int, height: Int): ByteArray? {
        val bitmap = try {
            DocumentsContract.getDocumentThumbnail(
                contentResolver,
                documentUri,
                Point(width, height),
                null
            )
        } catch (_: Exception) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                try {
                    contentResolver.loadThumbnail(documentUri, Size(width, height), null)
                } catch (_: Exception) {
                    null
                }
            } else {
                null
            }
        } ?: return null

        return bitmapToPng(bitmap)
    }

    private fun bitmapToPng(bitmap: Bitmap): ByteArray {
        val output = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)
        return output.toByteArray()
    }

    private fun deleteDocument(documentUri: Uri): Boolean {
        return try {
            DocumentsContract.deleteDocument(contentResolver, documentUri)
        } catch (_: Exception) {
            contentResolver.delete(documentUri, null, null) > 0
        }
    }

    private fun Cursor.getStringOrNull(columnName: String): String? {
        val index = getColumnIndex(columnName)
        if (index < 0 || isNull(index)) return null
        return getString(index)
    }

    private fun Cursor.getLongOrNull(columnName: String): Long? {
        val index = getColumnIndex(columnName)
        if (index < 0 || isNull(index)) return null
        return getLong(index)
    }

    private fun sanitizeFileName(fileName: String?): String? {
        if (fileName.isNullOrBlank()) return null
        return fileName.replace(Regex("""[\\/:*?"<>|]"""), "_")
    }
}
