import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // Required so the app's own Kotlin sources (e.g. MainActivity.kt) are
    // compiled. Removing this while android.builtInKotlin=false dropped
    // MainActivity from the APK -> ClassNotFoundException crash on launch.
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localProperties.load(FileInputStream(localPropertiesFile))
}

val flutterVersionCode = localProperties.getProperty("flutter.versionCode")?.toIntOrNull() ?: 2
val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"

android {
    namespace = "fun.trydream.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Enable core library desugaring for flutter_local_notifications
        isCoreLibraryDesugaringEnabled = true
    }

    // Force all Kotlin compile tasks to match the Java target (11).
    // Plugins like image_picker_android / privy_flutter apply KGP themselves and
    // Kotlin 2.x defaults to JVM 21, causing a "Inconsistent JVM-target" build failure.
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
        }
    }

    signingConfigs {
        val releaseStorePath = localProperties.getProperty("MYAPP_UPLOAD_STORE_FILE") ?: "upload-keystore.jks"
        val releaseKeystoreFile = file(releaseStorePath)
        if (releaseKeystoreFile.exists()) {
            create("release") {
                keyAlias = localProperties.getProperty("MYAPP_UPLOAD_KEY_ALIAS") ?: "upload"
                keyPassword = localProperties.getProperty("MYAPP_UPLOAD_KEY_PASSWORD") ?: ""
                storeFile = releaseKeystoreFile
                storePassword = localProperties.getProperty("MYAPP_UPLOAD_STORE_PASSWORD") ?: ""
            }
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "fun.trydream.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 28  // Required by privy_flutter plugin
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Uses release signing if keystore is configured in local.properties,
            // otherwise falls back to debug signing for local builds.
            val hasReleaseSigning = signingConfigs.findByName("release") != null
            signingConfig = if (hasReleaseSigning) signingConfigs.getByName("release")
                            else signingConfigs.getByName("debug")
        }
    }

    packaging {
        resources {
            pickFirsts += "META-INF/versions/9/OSGI-INF/MANIFEST.MF"
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Core library desugaring for flutter_local_notifications
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
