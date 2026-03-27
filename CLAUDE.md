# BabyCare (베이비케어 - AI 육아기록)

## Planning (기획 프로세스)

```
/specify [설명]           → .dev/specs/{name}/PLAN.md 생성
/specify --autopilot      → 무인 플랜 생성 (사용자 개입 없음)
/specify --quick           → 간단 작업용 경량 플랜
/execute {name}           → PLAN.md 기반 자동 실행
```

- 스펙 위치: `.dev/specs/{name}/PLAN.md` (활성) / `.dev/specs/done/{name}/` (완료 아카이브)
- 실행 컨텍스트: `.dev/specs/{name}/context/` (outputs.json, learnings.md, issues.md, audit.md)
- 완료된 스펙은 `done/`으로 이동하여 활성 목록 깔끔하게 유지
- DRAFT.md는 플랜 승인 시 삭제됨 — 의사결정 히스토리는 context/audit.md에 보존

## Design (디자인 시스템)

```bash
# 토큰 검증 (ROA Design System)
cd /Users/roque/roa-design-system && npx tsx cli/index.ts verify babycare

# 토큰 → 코드 동기화
cd /Users/roque/roa-design-system && npx tsx cli/index.ts sync babycare
# → BabyCare/BabyCare/DesignSystem.generated.swift 생성

# 스크린샷 캡처 (UI 테스트)
xcodebuild test -project BabyCare.xcodeproj -scheme BabyCare -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BabyCareUITests/ScreenshotTests
# → /tmp/babycare_screenshots/*.png
```

- 디자인 토큰: `design/tokens/babycare-tokens.json` (Asset Catalog 실제 값)
- ROA 설정: `.roa-design.json` (brand primary: #FF9FB5)
- 스크린샷: `BabyCareUITests/ScreenshotTests.swift` (주요 화면 자동 캡처)
- Figma 연동 미완: `FIGMA_TOKEN` 환경변수 설정 후 ROA Figma Plugin 사용 가능

## Build & Deploy (Makefile)

```bash
make build          # 빌드
make test           # 단위 테스트 (25개)
make verify         # 전체 검증 (빌드+테스트+디자인토큰)
make screenshots    # 스크린샷 캡처 → /tmp/babycare_screenshots/
make deploy         # 원커맨드 배포 (bump→archive→export→upload)
make bump           # 빌드 번호 +1
make status         # 현재 버전/커밋/테스트 상태
make clean          # 빌드 산출물 정리
make help           # 전체 명령어 목록
```

## Architecture

- **패턴**: @MainActor @Observable MVVM, AppState 싱글톤 (18 VM)
- **서비스**: FirestoreService + 도메인별 extension (Activity, Growth, Health, Allergy, ...)
- **분석**: Services/Analysis/ — 6단계 파이프라인 (ReferenceTable → BaselineDetector → PatternClassifier → ClinicalFilter)
- **탭**: 홈 | 캘린더 | ➕기록 | 건강 | 설정

## Conventions

- Swift 6.0, iOS 17+, 100% SF Symbols (커스텀 이미지 0개)
- 모델: `Identifiable, Codable, Hashable` 채택, 신규 필드는 optional (마이그레이션 불필요)
- 색상: `AppColors` enum (Asset Catalog 18개 Dynamic Color)
- 의학 데이터: 면책 문구 필수 ("참고용이며 의학적 진단을 대체하지 않습니다")
- 의학 출처: ReferenceTable 상단 주석 (AAP, WHO, AASM)
- AI 가드레일: AIGuardrailService.prohibitedRules 수정 금지
- 테스트: BabyCareTests/BabyCareTests.swift 단일 파일에 append

## Must NOT Do

- Baby.gender를 Optional로 변경 금지 (Firestore Codable 호환성)
- AIGuardrailService 금지어 목록 수정 금지
- 백분위를 "정상"/"비정상" 등 의학적 판단 텍스트로 표시 금지
- 외부 차트 라이브러리 도입 금지 (Apple Charts만)
- FirestoreService 기존 메서드 시그니처 변경 시 호출부 동시 수정 필수

## Current Status

- **Version**: v2.5.0 (빌드 41) + 미배포 12커밋
- **App Store**: v2.5.0 (빌드 40) READY_FOR_SALE
- **테스트**: 25개 PASS
- **규모**: 190 Swift 파일, 모델 21, 서비스 41, VM 18, 뷰 76

## Active TODO

### 즉시 (사용자 액션)
- [ ] TestFlight 빌드 배포 (make deploy)
- [ ] LMS 데이터 스팟체크 (WHO 원본 CSV 대조)
- [ ] 카탈로그 상품 30~40개 등록 (admin /catalog)
- [ ] Figma 토큰 설정 (FIGMA_TOKEN 환경변수)

### 로드맵
- P0: 임신 모드
- P1: 재주문 강화
- P2: 사진 AI OCR, AI 실시간 제안
- P4~P6: 수면장소, 커스텀활동, Apple Health, 배지, 커뮤니티
- 기술부채: 오프라인, 페이지네이션, VM분리, 에러재시도, N+1, 이미지캐싱, 위젯다크모드
- Admin: SERVICE_ACCOUNT, 사용자관리, 통계, 개인정보처리방침
- 웹: Google Search Console, Naver 등록
