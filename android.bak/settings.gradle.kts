import java.util.Properties

pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }

    val props = Properties()
    val localProps = file("local.properties")
    if (localProps.exists()) localProps.inputStream().use { props.load(it) }
    val flutterSdkPath = props.getProperty("flutter.sdk")
        ?: error("flutter.sdk no está en local.properties")

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    // Fijamos versiones aquí (NO en build.gradle.kts)
    plugins {
        id("com.android.application") version "8.6.1"
        id("org.jetbrains.kotlin.android") version "2.1.0"
        id("com.google.gms.google-services") version "4.4.2"
        id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader")
}

include(":app")
