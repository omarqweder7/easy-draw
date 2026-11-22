import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing. Every release must be signed with the SAME key, or
// Android refuses to install it over an existing copy (no updates).
// The key comes from android/key.properties (local, git-ignored; created by
// tools/create_release_key.ps1) or from environment variables (CI):
//   EASYDRAW_KEYSTORE      path to the .jks file
//   EASYDRAW_KEY_PASSWORD  its password (store and key share it)
//   EASYDRAW_KEY_ALIAS     optional, default "easydraw"
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val releaseStoreFile: String? = keyProps.getProperty("storeFile") ?: System.getenv("EASYDRAW_KEYSTORE")
val releasePassword: String? = keyProps.getProperty("storePassword") ?: System.getenv("EASYDRAW_KEY_PASSWORD")
val releaseKeyPassword: String? = keyProps.getProperty("keyPassword") ?: releasePassword
val releaseAlias: String = keyProps.getProperty("keyAlias") ?: System.getenv("EASYDRAW_KEY_ALIAS") ?: "easydraw"
val hasReleaseKey = !releaseStoreFile.isNullOrBlank() && !releasePassword.isNullOrBlank()
if (!hasReleaseKey && System.getenv("EASYDRAW_REQUIRE_RELEASE_KEY") == "true") {
    throw GradleException("Release key required but not configured (EASYDRAW_KEYSTORE / EASYDRAW_KEY_PASSWORD).")
}

android {
    namespace = "app.easydraw.easy_draw"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "app.easydraw.easy_draw"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(releaseStoreFile!!)
                storePassword = releasePassword
                keyAlias = releaseAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                // Lets `flutter run --release` work on a machine without the
                // key. Such builds can't update (or be updated by) real releases.
                logger.warn("Easy Draw: no release key configured; signing the release build with the DEBUG key.")
                signingConfigs.getByName("debug")
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
