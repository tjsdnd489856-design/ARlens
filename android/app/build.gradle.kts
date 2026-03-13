plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
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
    }

    // [신규] 화이트 라벨링을 위한 Flavor 설정
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
