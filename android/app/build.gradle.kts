import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firma de release: variables de entorno (CI, secretos de GitHub) o android/key.properties (local, no versionado).
// Sin ninguna de las dos se firma con la clave de depuracion (solo para pruebas locales; no se puede actualizar sobre una instalacion firmada con otra clave).
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
fun signProp(env: String, key: String): String? = System.getenv(env)?.takeIf { it.isNotBlank() } ?: keyProps.getProperty(key)

android {
    namespace = "com.careway.vigor_app"
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
        applicationId = "com.careway.vigor_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Health Connect (connect-client, plugin health) exige minSdk 26 (Android 8.0). Antes era 23.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("vigorRelease") {
            val path = signProp("VIGOR_KEYSTORE_PATH", "storeFile")
            if (path != null) {
                storeFile = file(path)
                storePassword = signProp("VIGOR_KEYSTORE_PASSWORD", "storePassword")
                keyAlias = signProp("VIGOR_KEY_ALIAS", "keyAlias") ?: "vigor"
                keyPassword = signProp("VIGOR_KEY_PASSWORD", "keyPassword") ?: signProp("VIGOR_KEYSTORE_PASSWORD", "storePassword")
                storeType = "pkcs12"
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (signProp("VIGOR_KEYSTORE_PATH", "storeFile") != null) signingConfigs.getByName("vigorRelease") else signingConfigs.getByName("debug")
            // La SDK Veepoo usa reflexion y proxies dinamicos: R8 renombra sus interfaces y rompe con ClassCastException ($Proxy cannot be cast to C0.a).
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

dependencies {
    // SDK Veepoo (Apache-2.0) como submodulo git: github.com/HBandSDK/Android_Ble_SDK
    listOf("jar_base", "jar_core").forEach { d ->
        implementation(fileTree(mapOf("dir" to "../third_party/Android_Ble_SDK/android_sdk_source/$d", "include" to listOf("*.jar", "*.aar"))))
    }
    implementation("no.nordicsemi.android:mcumgr-core:2.7.4")
    implementation("no.nordicsemi.android:mcumgr-ble:2.7.4")
    implementation("no.nordicsemi.android.support.v18:scanner:1.4.2")
    implementation("androidx.localbroadcastmanager:localbroadcastmanager:1.1.0")
    implementation("androidx.work:work-runtime-ktx:2.9.1")
    // Tests unitarios JVM (logica pura de Kotlin). org.json real: el de android.jar solo tiene metodos vacios en la JVM.
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20231013")
}

flutter {
    source = "../.."
}
