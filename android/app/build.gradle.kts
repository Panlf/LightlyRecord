plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // namespace 必须与 Kotlin 源码包一致（flutter create --org com.lightly
    // --project-name lightly_record 生成 com.lightly.lightly_record）；
    // applicationId 才是对外身份，按架构文档 §8.1 取 com.lightly.record，
    // 与导出目录 Android/data/com.lightly.record/files/export/ 对齐（§11 A7）。
    namespace = "com.lightly.lightly_record"
    compileSdk = 35                 // share_plus / package_info_plus 需要 34+
    // 插件（sqflite / path_provider / share_plus 等）要求 NDK 27，取已安装的最高版
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.lightly.record"
        minSdk = 23
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // 中文日期选择器等本地化资源
        resourceConfigurations += listOf("zh", "en")
    }

    buildTypes {
        release {
            // 复用 debug keystore 自签：flutter build apk --release 直出
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

flutter {
    source = "../.."
}
