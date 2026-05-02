plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.io.File
import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

fun loadDotEnv(file: File): Map<String, String> {
    if (!file.exists()) return emptyMap()
    return file.readLines()
        .map { it.trim() }
        .filter { it.isNotEmpty() && !it.startsWith("#") }
        .mapNotNull { line ->
            val idx = line.indexOf('=')
            if (idx <= 0) return@mapNotNull null
            val key = line.substring(0, idx).trim()
            var value = line.substring(idx + 1).trim()
            if ((value.startsWith("\"") && value.endsWith("\"")) ||
                (value.startsWith("'") && value.endsWith("'"))
            ) {
                value = value.substring(1, value.length - 1)
            }
            key to value
        }
        .toMap()
}

// Root `.env` (jedan direktorij iznad `android/`) — vidi `.env.example`.
val dotEnv: Map<String, String> = loadDotEnv(rootProject.file("../.env"))
val googleMapsApiKey: String = dotEnv["GOOGLE_MAPS_API_KEY"] ?: ""

val sharedKeyProperties = Properties()
val sharedKeyPropertiesFile = rootProject.file("../../key.properties")

if (sharedKeyPropertiesFile.exists()) {
    sharedKeyPropertiesFile.inputStream().use { sharedKeyProperties.load(it) }
}

android {
    namespace = "hr.dalekopro.farma"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    defaultConfig {
        applicationId = "hr.dalekopro.farma"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = googleMapsApiKey
    }

    signingConfigs {
        create("release") {
            if (sharedKeyPropertiesFile.exists()) {
                keyAlias = sharedKeyProperties["keyAlias"] as String
                keyPassword = sharedKeyProperties["keyPassword"] as String
                storeFile = file(sharedKeyProperties["storeFile"] as String)
                storePassword = sharedKeyProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (sharedKeyPropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_11)
    }
}

flutter {
    source = "../.."
}
