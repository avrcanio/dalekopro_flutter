package com.example.dalekopro_farma_flutter

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "dalekopro/saf"
    private val requestOpenTree = 4101
    private val requestOpenImage = 4102

    private var pendingTreeResult: MethodChannel.Result? = null
    private var pendingImageResult: MethodChannel.Result? = null

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
                        if (pendingImageResult != null) {
                            result.error("BUSY", "Image selection already in progress.", null)
                            return@setMethodCallHandler
                        }

                        val treeUri = call.argument<String>("treeUri")
                        if (treeUri.isNullOrBlank()) {
                            result.error("INVALID_ARGUMENT", "treeUri is required.", null)
                            return@setMethodCallHandler
                        }

                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "image/*"
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                            putExtra(DocumentsContract.EXTRA_INITIAL_URI, Uri.parse(treeUri))
                        }

                        pendingImageResult = result
                        startActivityForResult(intent, requestOpenImage)
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

        if (requestCode == requestOpenImage) {
            val result = pendingImageResult
            pendingImageResult = null
            handleImageSelection(result, resultCode, data)
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

    private fun handleImageSelection(result: MethodChannel.Result?, resultCode: Int, data: Intent?) {
        if (result == null) return
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }

        val imageUri = data.data!!
        val flags = data.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION
        contentResolver.takePersistableUriPermission(imageUri, flags)

        val fileName = resolveFileName(imageUri) ?: "picked_image_${System.currentTimeMillis()}.jpg"
        val targetFile = File(cacheDir, fileName)

        contentResolver.openInputStream(imageUri).use { input ->
            if (input == null) {
                result.error("READ_ERROR", "Could not read selected image.", null)
                return
            }

            FileOutputStream(targetFile).use { output ->
                input.copyTo(output)
            }
        }

        result.success(
            mapOf(
                "imageUri" to imageUri.toString(),
                "filePath" to targetFile.absolutePath,
            )
        )
    }

    private fun resolveFileName(uri: Uri): String? {
        contentResolver.query(uri, null, null, null, null).use { cursor ->
            if (cursor == null || !cursor.moveToFirst()) return null
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index < 0) return null
            return cursor.getString(index)
        }
    }
}
