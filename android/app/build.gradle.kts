plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.keepi"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.keepi"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion  // ← REVERTIDO a 21 para compatibilidad con Android 5
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // flutter_appauth: esquema para que la app reciba el redirect de Google.
        // Debe coincidir con GOOGLE_MOBILE_REDIRECT_URI en .env (ej: com.example.keepi:/oauth2redirect).
        // IMPORTANTE: Usa el cliente "Aplicación web" en Google Cloud y añade ese redirect allí;
        // el cliente Android ya no permite custom URI scheme.
        manifestPlaceholders["appAuthRedirectScheme"] = "com.example.keepi"
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
