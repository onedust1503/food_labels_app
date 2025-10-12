plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.food_labels_app"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    compileOptions {
        // 🆕 新增：開啟 Core Library Desugaring
        isCoreLibraryDesugaringEnabled = true
        // 🆕 修正：更新為建議的 Java 版本格式
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        // 🆕 修正：更新為建議的 JVM 目標格式
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.example.food_labels_app"
        minSdk = 23
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
        // 🆕 新增：啟用 MultiDex
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// 🆕 新增：加入 Desugaring 依賴
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

