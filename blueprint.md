# ARlens 프로젝트 개발 블루프린트 (Blueprint)

이 문서는 ARlens 프로젝트의 현재 상태, 설계 구조 및 작업 내역을 기록하여 지속 가능한 개발을 돕는 가이드라인입니다.

## 1. 프로젝트 개요
- **목적**: 사용자가 실시간 카메라를 통해 다양한 AR 렌즈(필터)를 체험하고, 관리자가 이를 CMS를 통해 실시간으로 배포/관리하는 서비스.
- **주요 기술 스택**: Flutter (Web/Mobile), Supabase (DB, Storage), Google ML Kit (Face Detection).

## 2. 시스템 아키텍처 및 인프라
### 2.1 Supabase 연동 (`lib/services/supabase_service.dart`)
- **패턴**: 싱글톤(Singleton) 서비스 클래스.
- **초기화**: `main()` 함수에서 `SupabaseService.initialize()`를 호출하여 부팅 순서 보장.
- **보안**: URL 및 Anon Key의 미세 공백으로 인한 에러 방지를 위해 `.trim()` 처리 적용.

### 2.2 데이터베이스 (Table: `lenses`)
| 컬럼명 | 타입 | 설명 |
| :--- | :--- | :--- |
| id | uuid (PK) | 고유 식별자 (자동 생성) |
| name | text | 렌즈 이름 |
| description | text | 상세 설명 |
| tags | text[] | 태그 배열 (필터링용) |
| thumbnailUrl | text | Storage의 썸네일 주소 |
| arTextureUrl | text | Storage의 AR 텍스처 주소 |
| createdAt | timestamptz | 생성 일시 |

### 2.3 스토리지 (Bucket: `lens-assets`)
- **경로 구조**: 
  - `thumbnails/`: 렌즈 리스트용 이미지
  - `textures/`: 얼굴에 입혀질 AR 그래픽 소스
- **보안 로직**: 파일 업로드 시 `타임스탬프_폴더명_asset.확장자`로 이름을 변환하여 인코딩 오류 및 중복 방지.

## 3. 기능별 구현 상세
### 3.1 어드민 대시보드 (`lib/screens/admin/`)
- **디자인**: Clean Light Mode, Responsive Grid (maxCrossAxisExtent: 200).
- **필터링**: 좌측 사이드바를 통한 태그별 다중 선택 필터링 시스템.
- **CRUD**:
  - **Create**: 이미지 업로드와 함께 DB 데이터 생성.
  - **Read**: Shimmer Skeleton UI를 사용한 부드러운 로딩.
  - **Update**: 기존 데이터를 불러와서 부분 수정 (update 쿼리).
  - **Delete**: DB 삭제 시 Storage의 관련 파일 2종을 함께 삭제하는 트랜잭션급 로직.

### 3.2 유저 카메라 화면 (`lib/screens/camera_screen.dart`)
- **초기화**: 카메라 권한 요청 버튼 및 실패 시 안내 문구 제공.
- **실시간 연동**: DB와 연동된 하단 렌즈 슬라이더. 렌즈 선택 시 즉시 AR 렌즈 페인터에 반영.
- **안정성**: 더미 데이터 로직을 제거하고 실제 DB 데이터가 0개일 때의 예외 처리 완료.

## 4. 해결된 주요 버그 및 기술 부채
- **NotInitializedError**: static 변수에서 인스턴스를 즉시 호출하던 문제를 Getter 방식으로 변경하여 해결.
- **Method invocation error**: `withOpacity()`가 포함된 위젯 앞의 불필요한 `const` 키워드 전수 제거.
- **Sync Bug**: 삭제 후 유저 사이트에 데이터가 남던 현상을 `notifyListeners()`와 리스트 즉시 제거 로직으로 해결.

## 5. 향후 작업 권장 사항
- **권한 관리**: 현재는 `/admin-secret-page` 주소만 알면 접근 가능하므로, Supabase Auth를 이용한 관리자 로그인 기능 추가 필요.
- **AR 최적화**: ML Kit의 감지 속도와 렌즈 렌더링 프레임 최적화.
- **에셋 관리**: 배포 시 선택한 이미지의 크기를 최적화(Resize)해서 올리는 로직 검토.
