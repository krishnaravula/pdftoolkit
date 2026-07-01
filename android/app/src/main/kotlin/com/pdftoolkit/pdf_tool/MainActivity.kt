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
                val treeUri = Uri.parse(call.argument<String>("treeUri"))
                persistTreeUriPermission(treeUri)
                result.success(null)
            }
            "hasPersistedWritePermission" -> {
                val treeUri = Uri.parse(call.argument<String>("treeUri"))
                result.success(hasPersistedWritePermission(treeUri))
            }
            "exportPdfToTreeUri" -> {
                val treeUri = Uri.parse(requireNotNull(call.argument<String>("treeUri")))
                val sourcePath = requireNotNull(call.argument<String>("sourceFilePath"))
                val outputFileName = requireNotNull(call.argument<String>("outputFileName"))
                result.success(exportPdfToTreeUri(treeUri, sourcePath, outputFileName))
            }
            else -> result.notImplemented()
        }
    }

    private fun pickExportTreeUri(result: MethodChannel.Result) {
        pendingResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }
        startActivityForResult(intent, REQUEST_OPEN_TREE)
    }

    private fun persistTreeUriPermission(treeUri: Uri) {
        contentResolver.takePersistableUriPermission(
            treeUri,
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        )
    }

    private fun hasPersistedWritePermission(treeUri: Uri): Boolean {
        val perms = contentResolver.persistedUriPermissions
        return perms.any { it.uri == treeUri && it.isWritePermission }
    }

    private fun exportPdfToTreeUri(treeUri: Uri, sourcePath: String, outputName: String): String {
        val folder = DocumentFile.fromTreeUri(this, treeUri)
            ?: throw IllegalStateException("Selected folder is unavailable.")
        val uniqueName = resolveUniquePdfName(folder, outputName)
        val target = folder.createFile("application/pdf", uniqueName)
            ?: throw IllegalStateException("Unable to create destination file.")
        copyFileToUri(File(sourcePath), target.uri, contentResolver)
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

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        val result = pendingResult ?: return
        when (requestCode) {
            REQUEST_OPEN_TREE -> {
                if (resultCode != Activity.RESULT_OK || data?.data == null) {
                    result.success(null)
                } else {
                    val treeUri = data.data!!
                    persistTreeUriPermission(treeUri)
                    result.success(treeUri.toString())
                }
                pendingResult = null
            }
        }
    }
}
