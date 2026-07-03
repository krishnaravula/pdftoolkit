package com.pdftoolkit.pdf_tool

import android.app.Activity
import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterActivity() {
    private val channelName = "pdf_toolkit/storage"
    private var pendingResult: MethodChannel.Result? = null

    companion object {
        private const val REQUEST_OPEN_TREE = 8101
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                handleStorageCall(call, result)
            }
    }

    private fun handleStorageCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickExportTreeUri" -> pickExportTreeUri(result)
            "persistTreeUriPermission" -> {
                val treeUriString = call.argument<String>("treeUri")
                if (treeUriString.isNullOrBlank()) {
                    result.error("invalid_argument", "treeUri is required", null)
                    return
                }
                try {
                    persistTreeUriPermission(Uri.parse(treeUriString))
                    result.success(null)
                } catch (e: Exception) {
                    result.error("persist_failed", e.message, null)
                }
            }
            "hasPersistedWritePermission" -> {
                val treeUriString = call.argument<String>("treeUri")
                if (treeUriString.isNullOrBlank()) {
                    result.success(false)
                    return
                }
                result.success(hasPersistedWritePermission(Uri.parse(treeUriString)))
            }
            "exportPdfToTreeUri" -> {
                val treeUriString = call.argument<String>("treeUri")
                val sourcePath = call.argument<String>("sourceFilePath")
                val outputFileName = call.argument<String>("outputFileName")
                if (treeUriString.isNullOrBlank() ||
                    sourcePath.isNullOrBlank() ||
                    outputFileName.isNullOrBlank()
                ) {
                    result.error("invalid_argument", "Missing export parameters", null)
                    return
                }
                try {
                    val exportedUri = exportPdfToTreeUri(
                        Uri.parse(treeUriString),
                        sourcePath,
                        outputFileName,
                    )
                    result.success(exportedUri)
                } catch (e: Exception) {
                    result.error("export_failed", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun pickExportTreeUri(result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("busy", "Another folder picker is already open", null)
            return
        }
        pendingResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
            )
        }
        @Suppress("DEPRECATION")
        startActivityForResult(intent, REQUEST_OPEN_TREE)
    }

    private fun persistTreeUriPermission(treeUri: Uri) {
        contentResolver.takePersistableUriPermission(
            treeUri,
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
        )
    }

    private fun hasPersistedWritePermission(treeUri: Uri): Boolean {
        val perms = contentResolver.persistedUriPermissions
        return perms.any { it.uri == treeUri && it.isWritePermission }
    }

    private fun exportPdfToTreeUri(treeUri: Uri, sourcePath: String, outputName: String): String {
        val sourceFile = File(sourcePath)
        if (!sourceFile.isFile) {
            throw IllegalStateException("Source PDF is unavailable.")
        }
        val folder = DocumentFile.fromTreeUri(this, treeUri)
            ?: throw IllegalStateException("Selected folder is unavailable.")
        val uniqueName = resolveUniquePdfName(folder, outputName)
        val target = folder.createFile("application/pdf", uniqueName)
            ?: throw IllegalStateException("Unable to create destination file.")
        copyFileToUri(sourceFile, target.uri, contentResolver)
        return target.uri.toString()
    }

    private fun resolveUniquePdfName(folder: DocumentFile, fileName: String): String {
        val normalized = if (fileName.lowercase().endsWith(".pdf")) fileName else "$fileName.pdf"
        val dot = normalized.lastIndexOf('.')
        val stem = if (dot > 0) normalized.substring(0, dot) else normalized
        val ext = if (dot > 0) normalized.substring(dot) else ".pdf"
        var index = 0
        while (true) {
            val candidate = if (index == 0) "$stem$ext" else "${stem}_$index$ext"
            val exists = folder.findFile(candidate)
            if (exists == null) return candidate
            index++
        }
    }

    private fun copyFileToUri(sourceFile: File, targetUri: Uri, resolver: ContentResolver) {
        FileInputStream(sourceFile).use { input ->
            resolver.openOutputStream(targetUri, "w").use { output ->
                requireNotNull(output) { "Unable to open target output stream." }
                input.copyTo(output)
                output.flush()
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_OPEN_TREE) return

        val result = pendingResult ?: return
        pendingResult = null

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }

        val treeUri = data.data!!
        try {
            persistTreeUriPermission(treeUri)
            result.success(treeUri.toString())
        } catch (e: Exception) {
            result.error("persist_failed", e.message, null)
        }
    }
}
