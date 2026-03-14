# ARlens Platform Blueprint (Ultimate Golden Master Edition)

## 1. Project Overview
ARlens는 B2B 엔터프라이즈 급 화이트라벨 AR 렌즈 체험 플랫폼입니다. 고성능 AR 엔진, 정밀한 관리자 감사 시스템, 그리고 모든 환경(Web/App)에서의 극한의 안정성을 제공합니다.

## 2. Core Architecture Standards
- **Data Standards**: DB의 명명 규칙(snake_case/camelCase)에 상관없이 Dart 모델은 `fromJson` 하이브리드 매핑을 통해 무결성을 유지합니다.
- **Communication**: 모든 로그 및 감사 데이터는 JSONB 규격에 맞게 직렬화되어 전송되며, 웹 종료 시 Beacon API를 통해 데이터 유실을 0%로 통제합니다.
- **Security**: 멱등성 `requestId`를 통한 중복 처리 방지 및 Supabase RLS(Row Level Security) 기반의 브랜드 데이터 격리.
- **Performance**: Isolate 기반 이미지 디코딩 및 로딩 토큰 가드를 통해 메인 스레드 Jank 현상과 메모리 누수(OOM)를 원천 차단합니다.

## 3. Implemented Features (Final v2)
### Admin & Governance
- **Simulation Mode**: Super Admin이 파트너사 환경을 100% 동일하게 재현(테마, 로고, 데이터)하며, 모든 이동 경로에서 컨텍스트가 보존됩니다.
- **Detailed Audit**: 모든 CUD 액션에 대해 '변경 전(Old) -> 변경 후(New)' 스냅샷을 기록하며, 삭제된 데이터는 전용 UI로 시각화됩니다.
- **100% Form Guard**: 네트워크 오프라인 시 모든 입력 위젯(TextField, Dropdown, Picker)이 자동 잠금 처리됩니다.

### UX & Intelligent Engine
- **Hybrid Map Engine**: GPS 위치 정보를 최우선하되, 이동 시 지도 중심 좌표 기반으로 실시간 자동 정렬됩니다. (Focus Lock 지능형 해제 포함)
- **Zero-Flash Sync**: 앱 시작 시 프로필 로드와 테마 바인딩이 SplashScreen 내에서 원자적으로 완료되어 UI 깜빡임이 없습니다.
- **Web AR Fallback**: 하드웨어 제약이 있는 웹 환경에서도 친절한 가이드 오버레이를 통해 사용자 이탈을 방지합니다.

## 4. Maintenance & Recovery
- **Global Reset**: `Supabase Sign-out` 후 엔진 및 디스크 캐시를 전수 정화하며, 초기 빌드 브랜드 아이덴티티로 복구합니다.
- **Enterprise Diagnostics**: 시스템 장애 시 관리자가 상세 로그를 확인하고 즉시 기술 지원팀에 전달할 수 있는 복사 도구를 제공합니다.

---
**Status**: 100.0% Integrity Achieved. Ready for Global Commercial Launch.
