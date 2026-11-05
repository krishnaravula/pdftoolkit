import java.io.FileInputStream
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// Flutter passes --dart-define values as base64-encoded "KEY=VALUE" pairs.
fun decodeDartDefines(): Map<String, String> {
    val encoded = project.findProperty("dart-defines") as String? ?: return emptyMap()
    if (encoded.isBlank()) return emptyMap()
    return encoded.split(",").mapNotNull { entry ->
        if (entry.isBlank()) return@mapNotNull null
        val decoded = String(Base64.getDecoder().decode(entry), Charsets.UTF_8)
        val parts = decoded.split("=", limit = 2)
        if (parts.size == 2) parts[0] to parts[1] else null
    }.toMap()
}

val dartDefines = decodeDartDefines()
val disableMinify = dartDefines["DISABLE_MINIFY"] == "true"
val releaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

android {
    namespace = "com.pdftoolkit.pdf_tool"
    // Android 16 (API 36) — latest stable; required for Play submissions from Aug 2026.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.pdftoolkit.pdf_tool"
        minSdk = 29
        targetSdk = 36
        // versionCode / versionName are sourced from pubspec.yaml (e.g. 1.0.0+2).
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    packaging {
        jniLibs {
            // Setting to false ensures native libs are stored uncompressed and 16KB-aligned
            // for compatibility with Android 15/16.
            useLegacyPackaging = false
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = !disableMinify
            // Resource shrinking strips plugin drawables/styles and can crash at
            // icon tap before Flutter starts. Code minification stays enabled.
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            val configuredReleaseSigning = signingConfigs.findByName("release")
            if (configuredReleaseSigning != null) {
                signingConfig = configuredReleaseSigning
            } else if (releaseBuildRequested) {
                error(
                    "Release signing is not configured. Copy android/key.properties.example " +
                        "to android/key.properties and set your upload keystore passwords " +
                        "before building for Play Console.",
                )
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Storage Access Framework helpers (DocumentFile) used by MainActivity for
    // exporting PDFs to a user-picked tree URI. Declared explicitly because it
    // is no longer provided transitively by plugins.
    implementation("androidx.documentfile:documentfile:1.0.1")
}
