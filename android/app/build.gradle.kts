plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = java.util.Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

android {
    namespace = "com.example.myapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.myapp"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // [V1.1] 보안 강화를 위한 API 키 플레이스홀더 설정
        manifestPlaceholders["googleMapsApiKey"] = localProperties.getProperty("GOOGLE_MAPS_API_KEY_ANDROID") ?: ""
    }

    flavorDimensions.add("brand")
    productFlavors {
        create("arlens_original") {
            dimension = "brand"
            applicationId = "com.example.arlens.original"
            resValue("string", "app_name", "ARlens Original")
        }
        create("olens") {
            dimension = "brand"
            applicationId = "com.example.arlens.olens"
            resValue("string", "app_name", "O-Lens AR")
        }
        create("hapa") {
            dimension = "brand"
            applicationId = "com.example.arlens.hapa"
            resValue("string", "app_name", "HapaKristin AR")
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
