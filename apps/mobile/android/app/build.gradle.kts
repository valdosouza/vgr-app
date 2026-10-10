import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing (decision 246): the upload key lives OUTSIDE the
// repository. `android/key.properties` (gitignored, like every *.jks and
// *.keystore) names it — storeFile, storePassword, keyAlias, keyPassword;
// Play App Signing holds the final app key. See docs/feature/release.md.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}

android {
    namespace = "com.setes.vgr"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.setes.vgr"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Project-specific debug keystore (not the machine-wide
    // ~/.android/debug.keystore, which every Android app built on this
    // computer shares — that collided with an unrelated app's SHA-1 when
    // registering Google Sign-In OAuth clients). Not sensitive: debug-only,
    // gitignored (*.keystore), never used for a release build.
    signingConfigs {
        getByName("debug") {
            storeFile = file("vgr-debug.keystore")
            storePassword = "vgrdebug123"
            keyAlias = "vgrdebugkey"
            keyPassword = "vgrdebug123"
        }
        if (keystorePropertiesFile.exists()) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Never the debug key (decision 246; the Play Store refuses
            // it). Without key.properties there is no release config, and
            // the check below stops the build before anything is packaged.
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

// Fail closed: a release APK/AAB without the upload key would come out
// unsigned. Debug and profile builds never need the key.
gradle.taskGraph.whenReady {
    val buildsRelease = allTasks.any {
        it.project == project && (it.name == "assembleRelease" || it.name == "bundleRelease")
    }
    if (buildsRelease && !keystorePropertiesFile.exists()) {
        throw GradleException(
            "Release signing needs android/key.properties pointing at the upload key " +
                "(decision 246, docs/feature/release.md). Use --profile to try a release-like build without it."
        )
    }
}

flutter {
    source = "../.."
}
