import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Signing config ────────────────────────────────────────────────────────────
// Create android/key.properties before building a signed release.
// For now we fall back to debug signing so the build always works.
val keystorePropertiesFile = rootProject.file("key.properties")
val useReleaseKey = keystorePropertiesFile.exists()
val keystoreProperties = Properties()
if (useReleaseKey) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.wazibot.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.wazibot.mobile"
        // local_auth + flutter_local_notifications require minSdk 21 (Android 5.0)
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
        }
    }

    signingConfigs {
        if (useReleaseKey) {
            create("release") {
                keyAlias     = keystoreProperties["keyAlias"] as String
                keyPassword  = keystoreProperties["keyPassword"] as String
                storeFile    = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Use release key if available, otherwise fall back to debug
            // (debug-signed APKs work fine for testing, just not for Play Store)
            signingConfig = if (useReleaseKey)
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

flutter {
    source = "../.."
}
