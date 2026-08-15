group = "dev.fluttercommunity.plus.packageinfo"
version = "1.0-SNAPSHOT"

buildscript {
    val kotlinVersion = "2.2.0"

    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.12.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}

// PATCH (local fork of package_info_plus 10.2.1):
// Upstream gates on the AGP major version alone, skipping `kotlin.android` on
// AGP >= 9 on the assumption that AGP 9 always supplies built-in Kotlin. That
// is only true when `android.builtInKotlin=true`; this project sets it to
// false (the app module applies kotlin-android itself, which AGP 9 rejects if
// built-in Kotlin is on). The result upstream is that this plugin's Kotlin is
// never compiled, and GeneratedPluginRegistrant fails with
// "cannot find symbol PackageInfoPlugin".
//
// Fix: also apply the Kotlin plugin when built-in Kotlin is disabled.
// Remove this fork once package_info_plus ships a release that honours
// `android.builtInKotlin`. See docs/DRIVER_APP_SPRINT_PLAN.md (D9 blocker).
val agpMajor = com.android.Version.ANDROID_GRADLE_PLUGIN_VERSION.substringBefore('.').toInt()
val builtInKotlin = (project.findProperty("android.builtInKotlin") as String?)?.toBoolean() ?: false

if (agpMajor < 9 || !builtInKotlin) {
    apply(plugin = "org.jetbrains.kotlin.android")
}

project.extensions.configure(org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension::class.java) {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

android {
    namespace = "dev.fluttercommunity.plus.packageinfo"
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk = 19
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    lint {
        disable.add("InvalidPackage")
    }
}
