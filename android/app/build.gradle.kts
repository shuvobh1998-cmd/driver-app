import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is driven by android/key.properties (gitignored). When it is
// absent — CI, fresh clones, day-to-day dev — release builds fall back to the
// debug keys so `flutter run --release` still works. To produce a store build,
// copy key.properties.example to key.properties and point it at your keystore.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// Firebase (phone auth) is configured per-flavor, out of band: google-services.json
// is gitignored and only the `dev` flavor's package is registered. Apply the
// Google Services plugin ONLY for dev builds (and only when the file is present),
// so:
//   - `dev` builds wire Firebase,
//   - `staging`/`prod` builds (package names not in the json) still succeed and
//     fall back to the gated phone verifier at runtime,
//   - CI without the file still builds.
val isDevFlavorBuild = gradle.startParameter.taskNames.any {
    it.contains("Dev", ignoreCase = true)
}
if (isDevFlavorBuild && file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

android {
    namespace = "com.driverapp.driver_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Core library desugaring is required by flutter_local_notifications.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.driverapp.driver_app"
        // minSdk 23: required by firebase_messaging / secure storage.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Per-flavor app_name is injected via resValue.
    buildFeatures {
        resValues = true
    }

    // Build flavors: dev / staging / prod. Each gets its own applicationId
    // suffix and app label so all three can be installed side by side.
    // Pick one with `flutter run --flavor dev -t lib/main_dev.dart`.
    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "Driver Dev")
        }
        create("staging") {
            dimension = "env"
            applicationIdSuffix = ".staging"
            versionNameSuffix = "-staging"
            resValue("string", "app_name", "Driver Staging")
        }
        create("prod") {
            dimension = "env"
            resValue("string", "app_name", "Driver")
        }
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Use the real upload key when key.properties is present; otherwise
            // fall back to debug signing so non-release machines still build.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
