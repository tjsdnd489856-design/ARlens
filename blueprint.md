# ARlens Project Blueprint (V1.1 Full Compliance)

## 1. 프로젝트 개요
ARlens는 안경 및 렌즈 브랜드를 위한 B2B SaaS 가상 착용 플랫폼입니다. 단일 소스 코드로 다수의 브랜드 전용 앱을 생성하는 화이트 라벨링 기술과, 정밀한 고객 행동 데이터 분석을 통한 CRM 마케팅 솔루션을 제공합니다.

---

## 2. 핵심 시스템 명세 (V1.1 완료)

### **A. 고성능 AR 렌더링 엔진**
- **실시간 트래킹:** ML Kit 기반 안면/안구 좌표 추출 및 실시간 피팅.
- **하이퍼 리얼리즘:** `RadialGradient` 동공 마스크, 가장자리 블러링, 제품별 `BlendMode`(`softLight`, `multiply` 등) 동적 적용.
- **메모리 최적화:** 렌즈 교체 시 `ui.Image.dispose()` 명시적 호출 및 `isImageLoading` 플래그를 통한 중복 로딩 차단.

### **B. B2B 관리자 플랫폼 (Web & Mobile)**
- **반응형 레이아웃:** `LayoutBuilder` 기반 (웹: 고정 사이드바 / 모바일: 하단 탭바) 전용 UI 제공.
- **비즈니스 인사이트:** 기간 필터(주/월/전체)가 적용된 실시간 통계 차트 및 성과 요약.
- **자동 리포트 엔진:** 한글화된 고화질 PDF 분석 보고서 자동 생성 (브랜드 테마 반영).
- **마케팅 CRM:** 커스텀 푸시 메시지 템플릿 저장 및 실시간 모바일(iOS/Android) 알림 미리보기 UI.

### **C. 데이터 및 자원 관리**
- **무한 스크롤:** `LensProvider`를 통한 20개 단위 페이지네이션 로딩.
- **지능형 캐시:** `ARTextureCacheManager`(200MB 제한, LRU 정책)를 통한 텍스처 관리.
- **트랜스포메이션:** Supabase Storage API를 활용한 썸네일 리사이징(용량 90% 절감).
- **딥 트래킹:** `AnalyticsService`를 이용한 익명/로그인 유저 행동 정밀 로깅.

### **D. O2O 및 인프라**
- **스마트 매장 관리:** Google Places API 기반 주소 자동완성 및 좌표 자동 변환 시스템.
- **위치 기반 서비스:** 유저 위치 기준 매장 거리순 정렬 및 상세 정보 제공.
- **화이트 라벨링:** Flutter Flavor 시스템 연동 및 빌드 타임 `BRAND_ID` 환경 변수 주입.
- **보안 설정:** 네이티브 API 키 은닉(Android: `local.properties`, iOS: `Environment`) 및 Supabase RLS 정책 완결.

---

## 3. 기술 스택 요약
- **Core:** Flutter (Web/Mobile)
- **Backend:** Supabase (Auth, DB, Storage, Edge Functions Ready)
- **Maps:** Google Maps SDK (JS for Web, Native for Mobile)
- **Deployment:** Vercel (Admin Web), GitHub Actions (Flavor-specific APK Build)

---

## 4. 로컬 개발 환경 가이드
- **.env:** `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GOOGLE_MAPS_SERVER_API_KEY` 설정 필수.
- **Android:** `android/local.properties` 내 `GOOGLE_MAPS_API_KEY_ANDROID` 추가.
- **iOS:** Xcode Scheme 설정 내 `GOOGLE_MAPS_API_KEY_IOS` 환경 변수 추가.

---

## 5. 차기 개발 목표 (V1.2 Ready)
1. **실제 FCM 연동:** Firebase Cloud Messaging을 통한 실제 푸시 발송 및 토큰 관리 기능.
2. **지도 검색 고도화:** 유저용 지도 화면 내 매장명/지역명 검색 바 추가.
3. **온보딩 UX 개선:** 단계별 이전 버튼(Back) 추가 및 입력값 임시 저장 기능.
4. **대시보드 리팩토링:** 매장 등록 시 위치를 미리 확인하는 '미니 지도 뷰' 추가.
