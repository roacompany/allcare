# BabyCare (베이비케어 - AI 육아기록)

## Planning (기획 프로세스)

```
/specify [설명]           → .dev/specs/{name}/PLAN.md 생성
/specify --autopilot      → 무인 플랜 생성
/specify --quick           → 경량 플랜
/execute {name}           → PLAN.md 기반 자동 실행
```

- 스펙: `.dev/specs/{name}/PLAN.md` (활성) / `.dev/specs/done/{name}/` (아카이브)
- 컨텍스트: `.dev/specs/{name}/context/` (outputs.json, learnings.md, issues.md, audit.md)

## Design (디자인 시스템)

```bash
make design-verify   # ROA 토큰 검증 (100%)
make design-sync     # 토큰 → DesignSystem.generated.swift
make screenshots     # 주요 화면 스크린샷 캡처
```

- 디자인 토큰: `design/tokens/babycare-tokens.json`
- ROA 설정: `.roa-design.json` (brand: #FF9FB5)
- 위젯 다크모드: `WidgetColors` adaptive enum

## Build & Deploy (Makefile)

```bash
make build       # xcodegen + xcodebuild
make test        # 단위 테스트 25개
make verify      # 빌드 + 테스트 + 디자인토큰
make deploy      # 원커맨드 배포 (bump→archive→export→upload)
make bump        # 빌드 번호 +1
make status      # 버전/커밋/테스트 상태
```

## Architecture

- **패턴**: @MainActor @Observable MVVM, AppState 싱글톤 (18 VM)
- **서비스 분리**: ActivityTimerManager, FeedingPredictionService, PercentileCalculator, MedicationSafetyService
- **인프라**: RetryHelper (지수 백오프), OfflineQueue (쓰기 큐잉+자동 sync), CachedAsyncImage (2-tier), NetworkMonitor
- **가족 공유**: Baby.ownerUserId + BabyViewModel.dataUserId() — 공유 아기 데이터 경로 자동 라우팅
- **Firestore**: 200MB persistent cache, 21개 컬렉션 상수 (FirestoreCollections), 페이지네이션 (일기 커서/구매 limit/할일 필터)
- **분석**: Services/Analysis/ — 6단계 파이프라인
- **탭**: 홈 | 캘린더 | ➕기록 | 건강 | 설정

## Conventions

- Swift 6.0, iOS 17+, 100% SF Symbols
- 모델: `Identifiable, Codable, Hashable` 채택, 신규 필드 optional
- Firestore 컬렉션명: 반드시 `FirestoreCollections.*` 상수 사용 (하드코딩 금지)
- 색상: `AppColors` enum (Asset Catalog 18개 Dynamic Color)
- 의학 데이터: 면책 문구 필수
- AI 가드레일: AIGuardrailService.prohibitedRules 수정 금지
- 테스트: BabyCareTests.swift 단일 파일에 append
- 공유 아기 데이터: `babyVM.dataUserId()` 사용 필수 (authVM.currentUserId 직접 사용 금지)

## Must NOT Do

- Baby.gender Optional 변경 금지
- AIGuardrailService 금지어 수정 금지
- 백분위 의학적 판단 텍스트 금지
- 외부 차트 라이브러리 금지 (Apple Charts만)
- 데이터 로딩/저장 시 authVM.currentUserId 직접 사용 금지

## Current Status

- **Version**: v2.6.1 (빌드 44)
- **App Store**: v2.5.0 (빌드 40) READY_FOR_SALE
- **심사 대기**: v2.6.0 (빌드 43) WAITING_FOR_REVIEW
- **TestFlight**: v2.6.1 (빌드 44)
- **테스트**: 25개 PASS, 경고 0건
- **규모**: ~200 Swift 파일
- **QA**: 3-Agent ALL PASS (2026-04-04)

## Active TODO

### 즉시 (사용자 액션)
- [ ] LMS 데이터 스팟체크 (WHO 원본 CSV 대조)
- [ ] 카탈로그 상품 30~40개 등록 (admin /catalog)
- [ ] Figma 토큰 설정 (FIGMA_TOKEN)

### 잔여 MEDIUM 2건
- [ ] 미래 날짜 기록 가능 (DatePicker 시간 제한) — TimeAdjustmentSection.swift
- [ ] 캘린더 월 전환 로딩 인디케이터 없음 — CalendarView.swift

### 로드맵
- P0: 임신 모드
- P2: 사진 AI OCR, AI 실시간 제안
- P4~P6: 수면장소, 커스텀활동, Apple Health, 배지, 커뮤니티
- Admin: SERVICE_ACCOUNT, 사용자관리, 통계, 개인정보처리방침
- 웹: Google Search Console, Naver 등록
