# ARlens 화이트 라벨링(White Labeling) 가이드

ARlens 플랫폼을 기반으로 각 브랜드(O-Lens, HapaKristin 등) 전용 앱을 빌드하기 위한 가이드입니다.

## 1. 빌드 커맨드 (Flavor 적용)

빌드 시 `--dart-define`을 통해 `BRAND_ID`를 주입해야 해당 브랜드의 데이터와 테마가 적용됩니다.

### Android 빌드
```bash
# O-Lens 전용 앱 빌드
flutter build apk --flavor olens --dart-define=BRAND_ID=O-Lens

# HapaKristin 전용 앱 빌드
flutter build apk --flavor hapa --dart-define=BRAND_ID=HapaKristin

# 오리지널 ARlens 빌드
flutter build apk --flavor arlens_original --dart-define=BRAND_ID=default
```

### iOS 빌드
```bash
# O-Lens 전용 앱 빌드
flutter build ios --flavor olens --dart-define=BRAND_ID=O-Lens
```

---

## 2. 브랜드별 리소스(아이콘/스플래시) 설정

Flavor에 따라 자동으로 리소스를 교체하려면 안드로이드/iOS의 소스 세트 구조를 활용해야 합니다.

### Android 리소스 위치
- `android/app/src/arlens_original/res/`: 기본 아이콘 및 이름
- `android/app/src/olens/res/`: O-Lens 전용 아이콘 및 이름
- `android/app/src/hapa/res/`: HapaKristin 전용 아이콘 및 이름

각 폴더 내에 `mipmap-` 폴더와 `values/strings.xml`을 배치하면 빌드 시점에 자동으로 합쳐집니다.

### iOS 리소스 위치
Xcode에서 각 Flavor(Scheme)에 대응하는 `Asset Catalog`를 생성하거나, 빌드 타임 스크립트를 통해 `AppIcon`을 교체하도록 설정할 수 있습니다.

---

## 3. 작동 원리

1. **Build Time**: `android/app/build.gradle.kts`에 정의된 Flavor에 의해 패키지명(`applicationId`)과 앱 이름이 결정됩니다.
2. **Runtime**: `lib/main.dart`에서 `--dart-define`으로 주입된 `BRAND_ID`를 읽어 `BrandProvider`에 전달합니다.
3. **Initialization**: `BrandProvider`는 해당 ID로 Supabase에서 브랜드 정보(로고, 테마 컬러)를 가져와 앱 전체 UI에 실시간 반영합니다.
4. **Data Isolation**: `LensProvider`는 주입된 `BRAND_ID`를 기반으로 해당 브랜드의 렌즈들만 필터링하여 로드합니다.
