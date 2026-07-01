# =============================================================================
# PDF Toolkit — R8 / ProGuard rules for release (minifyEnabled + shrinkResources)
#
# Scope: Android Java/Kotlin layer only. Dart data classes, Drift entities, and
# domain models in lib/ are compiled AOT and are not processed by R8.
# =============================================================================

# ---------------------------------------------------------------------------
# Diagnostics — preserve line numbers for crash deobfuscation (mapping.txt)
# ---------------------------------------------------------------------------
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# ---------------------------------------------------------------------------
# Annotations, generics, and Kotlin metadata (required by reflection-based
# serializers and Kotlin data classes / enums in plugins)
# ---------------------------------------------------------------------------
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes RuntimeVisibleAnnotations
-keepattributes RuntimeVisibleParameterAnnotations
-keepattributes RuntimeInvisibleAnnotations
-keepattributes RuntimeInvisibleParameterAnnotations

-keepclassmembers class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings { *; }
-keepclassmembers class **$Companion { *; }

# ---------------------------------------------------------------------------
# Flutter embedding and platform channels
# ---------------------------------------------------------------------------
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

-keep class io.flutter.plugin.common.** { *; }
-keep class ** implements io.flutter.plugin.common.MethodCallHandler { *; }
-keep class ** implements io.flutter.plugin.common.PluginRegistry$* { *; }
-keep class ** extends io.flutter.plugin.common.MethodCodec { *; }
-keep class ** extends io.flutter.plugin.common.MessageCodec { *; }
-keep class ** extends io.flutter.plugin.common.StandardMessageCodec { *; }

-keep @androidx.annotation.Keep class * { *; }
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}

# ---------------------------------------------------------------------------
# App entry point and custom platform channel (Storage Access Framework)
# ---------------------------------------------------------------------------
-keep class com.pdftoolkit.pdf_tool.MainActivity { *; }
-keep class com.pdftoolkit.pdf_tool.** { *; }

-keep class androidx.documentfile.** { *; }
-keep class androidx.core.content.FileProvider { *; }

# ---------------------------------------------------------------------------
# Registered Flutter plugins (GeneratedPluginRegistrant)
# ---------------------------------------------------------------------------
-keep class biz.cunning.cunning_document_scanner.** { *; }
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-keep class io.flutter.plugins.flutter_plugin_android_lifecycle.** { *; }
-keep class io.flutter.plugins.googlemobileads.** { *; }
-keep class io.flutter.plugins.inapppurchase.** { *; }
-keep class com.crazecoder.openfile.** { *; }
-keep class com.baseflow.permissionhandler.** { *; }
-keep class dev.fluttercommunity.plus.share.** { *; }
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class io.flutter.plugins.urllauncher.** { *; }
-keep class io.flutter.plugins.webviewflutter.** { *; }

# package:jni / package:jni_flutter (path_provider_android, etc.)
# consumer-rules.pro from those plugins is merged automatically; keep explicitly.
-keep class com.github.dart_lang.jni.** { *; }
-keep class com.github.dart_lang.jni_flutter.** { *; }

# Pigeon-generated codecs and Kotlin data classes used across plugins
-keep class **$PigeonCodec { *; }
-keep class **$PigeonUtils { *; }
-keep class **$MessagesPigeonCodec { *; }
-keep class **$MessagesPigeonUtils { *; }
-keep class dev.flutter.pigeon.** { *; }

# Kotlin enums (Pigeon enums in billing, shared_preferences, etc.)
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ---------------------------------------------------------------------------
# Google Play Billing (in_app_purchase_android → billingclient 8.x)
# ---------------------------------------------------------------------------
-keep class com.android.vending.billing.** { *; }
-keep class com.android.billingclient.** { *; }
-keep interface com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**

# Billing JSON payloads are parsed reflectively by the Play Billing library.
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# ---------------------------------------------------------------------------
# Google Mobile Ads (AdMob) + User Messaging Platform (consent)
# MobileAdsInitProvider runs at process start (before Flutter) — must not be stripped.
# ---------------------------------------------------------------------------
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.android.gms.ads.MobileAdsInitProvider { *; }
-keep class com.google.ads.** { *; }
-keep class com.google.android.ump.** { *; }
-dontwarn com.google.android.gms.**
-dontwarn com.google.ads.**

# ---------------------------------------------------------------------------
# ML Kit (cunning_document_scanner) — MlKitInitProvider also runs at app startup
# ---------------------------------------------------------------------------
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-keep class com.google.android.gms.vision.** { *; }
-keep class com.google.android.gms.common.internal.safeparcel.** { *; }
-keep class com.google.android.gms.common.annotation.** { *; }
-dontwarn com.google.mlkit.**

# Firebase component discovery (pulled in by ML Kit)
-keep class com.google.firebase.** { *; }
-keep class * implements com.google.firebase.components.ComponentRegistrar { *; }
-keepnames class com.google.firebase.components.ComponentRegistrar
-dontwarn com.google.firebase.**

# Play Services / Dynamite (ML Kit + AdMob startup)
-keep class com.google.android.gms.dynamite.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keepclassmembers class * {
    @com.google.android.gms.common.annotation.Keep *;
}

# ---------------------------------------------------------------------------
# WebView (google_mobile_ads dependency)
# ---------------------------------------------------------------------------
-keep class android.webkit.** { *; }
-keepclassmembers class * extends android.webkit.WebViewClient {
    public void *(android.webkit.WebView, java.lang.String, android.graphics.Bitmap);
    public boolean *(android.webkit.WebView, java.lang.String);
}
-keepclassmembers class * extends android.webkit.WebChromeClient {
    public void *(android.webkit.WebView, java.lang.String);
}

# ---------------------------------------------------------------------------
# Gson — not used directly by this app; kept for Play Services / Billing transitives
# ---------------------------------------------------------------------------
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.TypeAdapter { *; }
-keep class * implements com.google.gson.TypeAdapterFactory { *; }
-keep class * implements com.google.gson.JsonSerializer { *; }
-keep class * implements com.google.gson.JsonDeserializer { *; }
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

# ---------------------------------------------------------------------------
# Moshi — defensive rules for transitive Square dependencies
# ---------------------------------------------------------------------------
-dontwarn com.squareup.moshi.**
-keep @com.squareup.moshi.JsonQualifier @interface *
-keepclassmembers class * {
    @com.squareup.moshi.FromJson <methods>;
    @com.squareup.moshi.ToJson <methods>;
}
-keepclasseswithmembers class * {
    @com.squareup.moshi.* <methods>;
}
-keep class * extends com.squareup.moshi.JsonAdapter {
    public <init>(com.squareup.moshi.Moshi);
    public <init>(com.squareup.moshi.Moshi, ...);
}

# ---------------------------------------------------------------------------
# Kotlinx Serialization — defensive rules (plugins / transitives)
# ---------------------------------------------------------------------------
-dontnote kotlinx.serialization.AnnotationsKt
-dontwarn kotlinx.serialization.**

-keepattributes *Annotation*, InnerClasses

-if @kotlinx.serialization.Serializable class **
-keepclassmembers class <1> {
    static <1>$Companion Companion;
}

-if @kotlinx.serialization.Serializable class ** {
    static **$Companion Companion;
}
-keepclassmembers class <2>$Companion {
    kotlinx.serialization.KSerializer serializer(...);
}

-if @kotlinx.serialization.Serializable class ** {
    public static ** Companion;
}
-keepclassmembers class <1> {
    public static ** Companion;
    public static ** serializer();
    public static ** serializer(kotlinx.serialization.KSerializer);
}

-keepclassmembers class kotlinx.serialization.json.** {
    *** Companion;
}
-keepclasseswithmembers class * {
    kotlinx.serialization.KSerializer serializer(...);
}

# ---------------------------------------------------------------------------
# Java Serializable
# ---------------------------------------------------------------------------
-keepnames class * implements java.io.Serializable
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# ---------------------------------------------------------------------------
# Android Parcelable
# ---------------------------------------------------------------------------
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# ---------------------------------------------------------------------------
# Protobuf / DataStore (shared_preferences_android backend)
# ---------------------------------------------------------------------------
-keep class * extends com.google.protobuf.GeneratedMessageLite { *; }
-keepclassmembers class * extends com.google.protobuf.GeneratedMessageLite {
    <fields>;
}
-keep class * extends com.google.protobuf.GeneratedMessageV3 { *; }
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**

-keep class androidx.datastore.** { *; }
-dontwarn androidx.datastore.**

# ---------------------------------------------------------------------------
# Native libraries (PDFium via pdfrx/pdfium_flutter FFI, sqlite3 via Drift FFI, JNI)
# ---------------------------------------------------------------------------
-keepclasseswithmembernames class * {
    native <methods>;
}

# PDFium / Chromium (legacy Java shims; pdfrx loads native code via Dart FFI)
-keep class org.chromium.** { *; }
-dontwarn org.chromium.**

# ---------------------------------------------------------------------------
# Document scanner plugin — Kotlin model classes
# ---------------------------------------------------------------------------
-keep class biz.cunning.cunning_document_scanner.fallback.models.** { *; }

# ---------------------------------------------------------------------------
# AndroidX Lifecycle (used by google_mobile_ads)
# ---------------------------------------------------------------------------
-keep class androidx.lifecycle.** { *; }
-dontwarn androidx.lifecycle.**

# ---------------------------------------------------------------------------
# AndroidX Startup + WorkManager + Room (release crash fix)
# InitializationProvider → WorkManagerInitializer → WorkDatabase (Room)
# Pulled in transitively by Play Services / Ads. R8 must not strip _Impl classes.
# ---------------------------------------------------------------------------
-keep class androidx.startup.** { *; }
-keepclassmembers class * implements androidx.startup.Initializer {
    <init>(...);
}

-keep class androidx.work.** { *; }
-keep class androidx.work.impl.** { *; }
-keep class androidx.work.WorkManagerInitializer { *; }
-keep class androidx.work.impl.WorkDatabase { *; }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.work.impl.WorkDatabaseMigrations { *; }
-keep class * extends androidx.work.Worker { *; }
-keep class * extends androidx.work.InputMerger { *; }
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
-keep class androidx.work.WorkerParameters { *; }

-keep class * extends androidx.room.RoomDatabase { *; }
-keep @androidx.room.Entity class * { *; }
-keep @androidx.room.Dao interface * { *; }
-keepclassmembers class * extends androidx.room.RoomDatabase {
    abstract ** create(...);
}
-keepclassmembers class * {
    @androidx.room.* <methods>;
}
-dontwarn androidx.room.paging.**

# ---------------------------------------------------------------------------
# Flutter deferred components / Play Core (referenced by embedding, not used)
# ---------------------------------------------------------------------------
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task

# ---------------------------------------------------------------------------
# Misc. library warnings commonly triggered after minification
# ---------------------------------------------------------------------------
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
