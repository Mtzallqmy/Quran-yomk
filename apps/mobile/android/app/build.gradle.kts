plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "app.tarteel.tarteel"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "app.tarteel.tarteel"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["tarteelAppLabel"] = "ترتيل"
    }

    signingConfigs {
        val keystorePath = System.getenv("TARTEEL_KEYSTORE_PATH")
        if (!keystorePath.isNullOrBlank()) {
            create("tarteelRelease") {
                storeFile = file(keystorePath)
                storePassword = System.getenv("TARTEEL_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("TARTEEL_KEY_ALIAS")
                keyPassword = System.getenv("TARTEEL_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        getByName("debug") {
            if (System.getenv("TARTEEL_ISOLATED_TRIAL") == "1") {
                // Side-by-side trial, never replaces the installed 2092 APK.
                applicationIdSuffix = ".trial"
                versionNameSuffix = "-trial"
                manifestPlaceholders["tarteelAppLabel"] = "ترتيل تجربة"
            }
        }
        release {
            if (System.getenv("TARTEEL_ISOLATED_TRIAL") == "1") {
                applicationIdSuffix = ".trial"
                versionNameSuffix = "-trial"
                manifestPlaceholders["tarteelAppLabel"] = "ترتيل تجربة"
                // Separate debug key for this side-by-side test, never the 2092 signing identity.
                signingConfig = signingConfigs.getByName("debug")
            }
            // Never silently create a new debug identity for an in-place update.
            // CI supplies the existing key and verifies its certificate against 2074.
            if (System.getenv("TARTEEL_ISOLATED_TRIAL") != "1") {
                signingConfig = signingConfigs.findByName("tarteelRelease")
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.media3:media3-exoplayer:1.8.0")
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
