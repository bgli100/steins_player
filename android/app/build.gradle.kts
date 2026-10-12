import java.io.File
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The release key. No key material is committed: the values come from `-P`
// arguments (build.ps1 passes them or writes the file) or from the git-ignored
// `android/key.properties`. Without them the release build falls back to the
// debug key, which some devices (vivo/iQOO outside developer mode) refuse to
// install.
val keyProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.reader(Charsets.UTF_8).use { load(it) }
}

fun signingValue(property: String, key: String): String? =
    (findProperty(property) as String?)?.takeIf { it.isNotBlank() }
        ?: keyProperties.getProperty(key)?.takeIf { it.isNotBlank() }

val releaseStoreFile = signingValue("RELEASE_STORE_FILE", "storeFile")?.let {
    val path = File(it)
    if (path.isAbsolute) path else rootProject.file(it)
}
val releaseStorePassword = signingValue("RELEASE_STORE_PASSWORD", "storePassword")
val releaseKeyAlias = signingValue("RELEASE_KEY_ALIAS", "keyAlias")
val releaseKeyPassword = signingValue("RELEASE_KEY_PASSWORD", "keyPassword")
val hasReleaseSigning = releaseStoreFile?.exists() == true &&
    releaseStorePassword != null && releaseKeyAlias != null && releaseKeyPassword != null

if (!hasReleaseSigning) {
    logger.warn(
        "No Android release key configured (build.local.json, -P RELEASE_STORE_FILE " +
            "or android/key.properties); the release APK is signed with the debug key."
    )
}

android {
    namespace = "com.lullaby.steins_player"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.lullaby.steins_player"
        // Android 10 (API 29) and above.
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = releaseStoreFile
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
                // minSdk is 29 and Android 9 (API 28) already verifies v3, so
                // v3 alone covers every supported device; v1 would only be used
                // by Android 6 and older. AGP writes the schemes the minSdk
                // needs (v3 here), the flags record the intent.
                enableV1Signing = false
                enableV2Signing = true
                enableV3Signing = true
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }

    androidResources {
        // The bundle is dominated by the work videos and covers, which are
        // already compressed. aapt2 stores these extensions by default; keeping
        // the list explicit guards against the packer deflating ~2.7 GB of
        // media again.
        noCompress += listOf("mp4", "png")
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
}

flutter {
    source = "../.."
}
