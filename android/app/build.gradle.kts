plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties

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

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "hr.dalekopro.farma"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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

flutter {
    source = "../.."
}
