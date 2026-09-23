import java.io.FileInputStream
import java.util.Properties

// Release signing, read from `android/key.properties` — a file that is
// gitignored and never leaves the machine that holds the keystore. Android
// refuses an update whose signature differs from the installed app, and the
// in-app updater (ADR-029) makes that a shipping concern rather than a Play
// Store one: every build handed to a user has to come from this one key.
//
// The fallback below keeps `flutter run --release` working on a machine
// that has no keystore, but a build signed that way must not be
// distributed — see the comment on the release buildType.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}
val hasReleaseKeystore = keystorePropertiesFile.exists()

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.yello_social_app"
    // Pinned to 37 (rather than the Flutter SDK's own default of 36) because
    // flutter_secure_storage requires compiling against Android SDK 37 —
    // Gradle refused the build otherwise. SDKs are backward compatible, so
    // this doesn't change the app's actual min/target SDK behavior.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.yello_social_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Without `key.properties` this falls back to the debug key so
            // a local `flutter run --release` still works. That build is
            // NOT distributable: the debug key is per-machine and expires,
            // so a user who installs one can never be updated from another
            // machine's build — Android rejects the signature change and
            // the only way out is uninstalling, which takes their data with
            // it. Create the keystore before handing anyone an APK.
            signingConfig = signingConfigs.getByName(if (hasReleaseKeystore) "release" else "debug")
        }
    }
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:34.19.0"))
    implementation("com.google.firebase:firebase-analytics")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
