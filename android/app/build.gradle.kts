import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: android/key.properties (never committed). Without it the
// release build falls back to the debug key (fine for testing, not for Play).
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

// --dart-define / --dart-define-from-file values reach Gradle as base64 "KEY=value"
// pairs. Read so config/admob.json can also set the AdMob *app* id in the manifest
// (docs/ads.md).
val dartDefines: Map<String, String> = (project.findProperty("dart-defines") as String?)
    ?.split(",")
    ?.mapNotNull { entry ->
        val pair = String(Base64.getDecoder().decode(entry), Charsets.UTF_8).split("=", limit = 2)
        if (pair.size == 2) pair[0] to pair[1] else null
    }
    ?.toMap()
    ?: emptyMap()

android {
    namespace = "com.iqballab.ludo_mela"
    // The plugins (google_mobile_ads, flutter_local_notifications, audioplayers,
    // mobile_scanner …) compile against API 36; never below it.
    compileSdk = maxOf(36, flutter.compileSdkVersion)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications needs java.time on older Android.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Permanent once published on Google Play.
        applicationId = "com.iqballab.ludo_mela"
        // google_mobile_ads and flutter_local_notifications need API 24 (Android 7.0).
        minSdk = maxOf(24, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // AdMob app id for AndroidManifest.xml; defaults to Google's TEST app id.
        manifestPlaceholders["admobAppId"] =
            dartDefines["ADMOB_APP_ID_ANDROID"]?.takeIf { it.isNotBlank() }
                ?: "ca-app-pub-3940256099942544~3347511713"
    }

    signingConfigs {
        if (keystoreProperties.containsKey("storeFile")) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Falls back to debug keys until android/key.properties exists,
            // so `flutter run --release` still works on a dev machine.
            signingConfig = signingConfigs.findByName("release")
                ?: signingConfigs.getByName("debug")
            // Keep rules for classes created by reflection (AdMob's WorkManager);
            // without them a release build crashes at launch (see proguard-rules.pro).
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Java 8+ time APIs on API 24–25 for flutter_local_notifications.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
