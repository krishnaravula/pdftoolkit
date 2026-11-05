package com.pdftoolkit.pdf_tool

import android.app.Activity
import android.content.ContentValues
import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.provider.Settings
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.security.MessageDigest
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val storageChannelName = "pdf_toolkit/storage"
    private val androidChannelName = "pdf_toolkit/android"
    private var pendingResult: MethodChannel.Result? = null
    private var androidChannel: MethodChannel? = null
    private var initialPdfIntent: Intent? = null
    private val fileExecutor = Executors.newSingleThreadExecutor()

    companion object {
        private const val REQUEST_OPEN_TREE = 8101
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        initialPdfIntent = intent?.takeIf(::isPdfOpenIntent)
        super.onCreate(savedInstanceState)
        if (initialPdfIntent != null) setIntent(Intent())
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, storageChannelName)
            .setMethodCallHandler { call, result ->
                handleStorageCall(call, result)
            }
        androidChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            androidChannelName,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "consumeInitialPdf" -> consumeInitialPdf(result)
                    "openDefaultPdfSettings" -> openDefaultPdfSettings(result)
                    else -> result.notImplemented()
                }
            }
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
                runFileOperation(result) {
                    exportPdfToTreeUri(Uri.parse(treeUriString), sourcePath, outputFileName)
                }
            }
            "exportPdfToDocuments" -> {
                val sourcePath = call.argument<String>("sourceFilePath")
                val outputFileName = call.argument<String>("outputFileName")
                if (sourcePath.isNullOrBlank() || outputFileName.isNullOrBlank()) {
                    result.error("invalid_argument", "Missing export parameters", null)
                    return
                }
                runFileOperation(result) {
                    exportPdfToDocuments(sourcePath, outputFileName)
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (!isPdfOpenIntent(intent)) {
            setIntent(intent)
            return
        }
        setIntent(Intent())

        importPdfFromIntent(intent) { pdf, error ->
            if (pdf != null) {
                androidChannel?.invokeMethod("openPdf", pdf)
            } else if (error != null) {
                androidChannel?.invokeMethod("openPdfError", error)
            }
        }
    }

    private fun consumeInitialPdf(result: MethodChannel.Result) {
        val sourceIntent = initialPdfIntent
        initialPdfIntent = null
        if (sourceIntent == null) {
            result.success(null)
            return
        }
        importPdfFromIntent(sourceIntent) { pdf, error ->
            if (pdf != null) {
                result.success(pdf)
            } else {
                result.error("open_pdf_failed", error ?: "Unable to open PDF.", null)
            }
        }
    }

    private fun isPdfOpenIntent(candidate: Intent?): Boolean {
        if (candidate == null) return false
        val supportedAction =
            candidate.action == Intent.ACTION_VIEW || candidate.action == Intent.ACTION_SEND
        return supportedAction && incomingPdfUri(candidate) != null
    }

    private fun incomingPdfUri(sourceIntent: Intent): Uri? {
        sourceIntent.data?.let { return it }

        if (sourceIntent.action == Intent.ACTION_SEND) {
            val streamUri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                sourceIntent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                sourceIntent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            }
            streamUri?.let { return it }
        }

        val clipData = sourceIntent.clipData
        return if (clipData != null && clipData.itemCount > 0) {
            clipData.getItemAt(0).uri
        } else {
            null
        }
    }

    private fun importPdfFromIntent(
        sourceIntent: Intent,
        callback: (Map<String, String>?, String?) -> Unit,
    ) {
        val uri = incomingPdfUri(sourceIntent)
        if (uri == null) {
            callback(null, "The PDF location is missing.")
            return
        }
        fileExecutor.execute {
            try {
                val sourceHash = MessageDigest.getInstance("SHA-256")
                    .digest(uri.normalizeScheme().toString().toByteArray(Charsets.UTF_8))
                    .joinToString("") { "%02x".format(it) }
                val path = copyIncomingPdf(uri)
                val pdf = mapOf("path" to path, "readingPositionKey" to "android-uri:$sourceHash")
                runOnUiThread { callback(pdf, null) }
            } catch (e: Exception) {
                runOnUiThread { callback(null, e.message ?: "Unable to read this PDF.") }
            }
        }
    }

    private fun copyIncomingPdf(uri: Uri): String {
        val openedDir = File(cacheDir, "opened_pdfs")
        if (!openedDir.exists() && !openedDir.mkdirs()) {
            throw IllegalStateException("Unable to prepare temporary storage.")
        }

        val displayName = queryDisplayName(uri) ?: "document.pdf"
        val safeName = sanitizePdfName(displayName)
        val destination = resolveUniqueFile(openedDir, safeName)
        try {
            contentResolver.openInputStream(uri).use { input ->
                requireNotNull(input) { "The selected PDF cannot be read." }
                destination.outputStream().use { output -> input.copyTo(output, 64 * 1024) }
            }
            check(hasPdfHeader(destination)) { "The selected file is not a valid PDF." }
            return destination.absolutePath
        } catch (e: Exception) {
            destination.delete()
            throw e
        }
    }

    private fun queryDisplayName(uri: Uri): String? {
        if (uri.scheme == ContentResolver.SCHEME_FILE) return uri.lastPathSegment
        return try {
            contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME),
                null,
                null,
                null,
            )?.use { cursor ->
                if (!cursor.moveToFirst()) return@use null
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0) cursor.getString(index) else null
            }
        } catch (_: Exception) {
            uri.lastPathSegment
        }
    }

    private fun hasPdfHeader(file: File): Boolean {
        if (file.length() < 5) return false
        // ISO 32000 readers allow the PDF header to appear within the first
        // 1024 bytes. Scanner and OEM file-provider output may include a small
        // preamble, so checking byte zero rejects otherwise valid documents.
        val header = ByteArray(minOf(1024L, file.length()).toInt())
        FileInputStream(file).use { input ->
            var offset = 0
            while (offset < header.size) {
                val count = input.read(header, offset, header.size - offset)
                if (count < 0) break
                offset += count
            }
            if (offset < 5) return false
        }
        val marker = byteArrayOf('%'.code.toByte(), 'P'.code.toByte(), 'D'.code.toByte(), 'F'.code.toByte(), '-'.code.toByte())
        for (start in 0..(header.size - marker.size)) {
            if (marker.indices.all { index -> header[start + index] == marker[index] }) {
                return true
            }
        }
        return false
    }

    private fun openDefaultPdfSettings(result: MethodChannel.Result) {
        val packageUri = Uri.parse("package:$packageName")
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                try {
                    startActivity(Intent(Settings.ACTION_APP_OPEN_BY_DEFAULT_SETTINGS, packageUri))
                } catch (_: Exception) {
                    startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, packageUri))
                }
            } else {
                startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, packageUri))
            }
            result.success(null)
        } catch (e: Exception) {
            result.error("settings_unavailable", e.message, null)
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
        return try {
            copyFileToUri(sourceFile, target.uri, contentResolver)
            target.uri.toString()
        } catch (e: Exception) {
            target.delete()
            throw e
        }
    }

    private fun exportPdfToDocuments(sourcePath: String, outputName: String): String {
        val sourceFile = File(sourcePath)
        if (!sourceFile.isFile) {
            throw IllegalStateException("Source PDF is unavailable.")
        }

        val collection = MediaStore.Files.getContentUri("external")
        val relativePath = "${Environment.DIRECTORY_DOCUMENTS}/PDF Tools/"
        val uniqueName = resolveUniqueMediaStoreName(collection, relativePath, outputName)
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, uniqueName)
            put(MediaStore.MediaColumns.MIME_TYPE, "application/pdf")
            put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val targetUri = contentResolver.insert(collection, values)
            ?: throw IllegalStateException("Unable to create the PDF in Documents.")

        try {
            copyFileToUri(sourceFile, targetUri, contentResolver)
            contentResolver.update(
                targetUri,
                ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) },
                null,
                null,
            )
            return targetUri.toString()
        } catch (e: Exception) {
            contentResolver.delete(targetUri, null, null)
            throw e
        }
    }

    private fun resolveUniqueMediaStoreName(
        collection: Uri,
        relativePath: String,
        outputName: String,
    ): String {
        val normalized = sanitizePdfName(outputName)
        val dot = normalized.lastIndexOf('.')
        val stem = if (dot > 0) normalized.substring(0, dot) else normalized
        val extension = if (dot > 0) normalized.substring(dot) else ".pdf"
        var index = 0
        while (true) {
            val candidate = if (index == 0) normalized else "${stem}_$index$extension"
            val exists = contentResolver.query(
                collection,
                arrayOf(MediaStore.MediaColumns._ID),
                "${MediaStore.MediaColumns.RELATIVE_PATH}=? AND " +
                    "${MediaStore.MediaColumns.DISPLAY_NAME}=?",
                arrayOf(relativePath, candidate),
                null,
            )?.use { it.moveToFirst() } ?: false
            if (!exists) return candidate
            index++
        }
    }

    private fun resolveUniquePdfName(folder: DocumentFile, fileName: String): String {
        val normalized = sanitizePdfName(fileName)
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

    private fun sanitizePdfName(fileName: String): String {
        val cleaned = fileName
            .replace(Regex("[\\\\/:*?\"<>|\\u0000-\\u001F]"), "_")
            .trim()
            .take(180)
            .ifBlank { "document" }
        return if (cleaned.lowercase().endsWith(".pdf")) cleaned else "$cleaned.pdf"
    }

    private fun resolveUniqueFile(directory: File, fileName: String): File {
        val dot = fileName.lastIndexOf('.')
        val stem = if (dot > 0) fileName.substring(0, dot) else fileName
        val extension = if (dot > 0) fileName.substring(dot) else ".pdf"
        var index = 0
        while (true) {
            val candidate = File(
                directory,
                if (index == 0) fileName else "${stem}_$index$extension",
            )
            if (!candidate.exists()) return candidate
            index++
        }
    }

    private fun runFileOperation(
        result: MethodChannel.Result,
        operation: () -> String,
    ) {
        fileExecutor.execute {
            try {
                val value = operation()
                runOnUiThread { result.success(value) }
            } catch (e: Exception) {
                runOnUiThread { result.error("export_failed", e.message, null) }
            }
        }
    }

    private fun copyFileToUri(sourceFile: File, targetUri: Uri, resolver: ContentResolver) {
        FileInputStream(sourceFile).use { input ->
            resolver.openOutputStream(targetUri, "w").use { output ->
                requireNotNull(output) { "Unable to open target output stream." }
                input.copyTo(output, 64 * 1024)
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

    override fun onDestroy() {
        androidChannel = null
        fileExecutor.shutdown()
        super.onDestroy()
    }
}
