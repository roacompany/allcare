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
make test        # 단위 테스트 107개
make lint        # SwiftLint 검사
make arch-test   # 아키텍처 경계 검사
make verify      # 빌드 + 린트 + 아키텍처 + 테스트 + 디자인토큰
make deploy      # 원커맨드 배포 (verify→bump→archive→export→upload)
make bump        # 빌드 번호 +1
make status      # 버전/커밋/테스트 상태
```

## Architecture

- **패턴**: @MainActor @Observable MVVM, AppState 싱글톤 (23 VM)
- **서비스 분리**: ActivityTimerManager, FeedingPredictionService v2 (day/night 개인화), WeeklyInsightService, PercentileCalculator, MedicationSafetyService
- **성장 차트**: GrowthView+Charts — Apple Charts AreaMark WHO 밴드(3rd~97th) + 백분위 추이 트렌드
- **인프라**: RetryHelper (지수 백오프), OfflineQueue (쓰기 큐잉+자동 sync), CachedAsyncImage (2-tier), NetworkMonitor
- **가족 공유**: Baby.ownerUserId + BabyViewModel.dataUserId() — 공유 아기 데이터 경로 자동 라우팅
- **Firestore**: 200MB persistent cache, 23개 컬렉션 상수 (FirestoreCollections), 페이지네이션 (일기 커서/구매 limit/할일 필터)
- **배지 시스템**: Badge/UserStats 모델, BadgeCatalog 8개, FirestoreService+Badge/Stats, BadgeEvaluator 단일 진입점 + Activity/Growth/Routine save path 연동. Phase 2 UI: BadgePresenter + BadgeViewModel (@Observable, arch-test baseline 0) + BadgeSnackbarView + BadgeGalleryView (3-section grid + BadgeTileView + BadgeDetailSheet) + BadgeHomeStrip (Dashboard top) + SettingsView "내 배지" row + Localizable.strings 25 keys — `.dev/specs/badges-ui/PLAN.md` (14 A-items 완료, 5 H-items QA 대기)
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

## Harness

harness-score: 96% (Grade A) — 2026-04-15

## Recent Session (2026-04-15)

### Phase 2 UI + Code Review
- 배지 Phase 2 UI 완료 (Snackbar + Gallery + HomeStrip + 26 Localizable)
- code-reviewer 다중모델 리뷰 → CR-001(공유 아기 경로) / CR-002(로컬라이즈) / CR-003(햅틱 재사용) / CR-006(@unknown default) 수정

### Feature Enhancement Rollout (master spec: `.dev/specs/feature-enhancement-rollout/PLAN.md`)
잔여 9개 항목 하네스 엔지니어링 6축 순환 (specify→execute→verify→commit→compound→context)으로 일괄 실행:

- **#4 대시보드 인사이트 카드 (T1)**: InsightService (4종 — 수유/수면/건강/마일스톤) + DashboardInsightCards
- **#5 수면 퇴행 감지 (T2)**: SleepAnalysisService (4/8/12개월 ±2주 윈도우, 최적 취침, 낮밤 비율, 품질 점수)
- **#6 예방접종 강화 (T3)**: D-day 카드 + D-14/7/1 단계별 푸시 + 부작용 기록 + 완료율 ProgressView
- **#7 할일/루틴 자동화 (T2)**: 검증 완료 (.dev/specs/done/todo-routine-automation/)
- **#8 일기 자동 요약 (T2)**: DiaryAnalysisService + 월간 분포 + N개월 회고 + 기분 트렌드 차트 + 사진 갤러리
- **#9 알레르기 추적 강화 (T3)**: FoodSafetyService + 이유식↔알레르기 자동 연동 + safe/caution/forbidden 대시보드
- **#10 병원 리포트 강화 (T2)**: HospitalChecklistService + PDF 통합 (체크리스트/백분위/활동 요약) + UIActivityViewController 공유
- **#11 제품 추천 (T3)**: ProductRecommendationService (정적 카탈로그) + 재구매 InsightService 카드 + 쿠팡 딥링크 + 인기 용품
- **#12 위젯 강화 (T3)**: NextFeeding/NextNap/TodaySummary/GrowthPercentile + Lock Screen 3종 (accessoryCircular/Rectangular/Inline)

### 누적 결과
- 테스트: 107 → 195 (+88)
- 커밋: 9개 (feature 8 + fix 1)
- arch-test: 0 violations 유지
- SwiftLint warnings: 8개 (기존 Badge.swift) 동일

## Current Status

- **Version**: v2.6.2 (빌드 52)
- **App Store**: v2.6.1 READY_FOR_SALE (v2.6.0도 READY_FOR_SALE)
- **심사 대기**: v2.6.2 (빌드 52) WAITING_FOR_REVIEW — 2026-04-11 01:18 UTC 제출
- **TestFlight**: v2.6.2 (빌드 52) — cry-analysis flag=true (stub), AdBanner 크래시 fix 포함
- **테스트**: 107개 PASS, 경고 0건
- **규모**: 225+ Swift 파일, 23개 VM, 23개 Firestore 컬렉션
- **QA**: 3-Agent ALL PASS (2026-04-04)

## Recent Changes (v2.6.2)

- **feat(cry-analysis)**: 울음 분석 기능 (베타, stub) — Health 탭 → 5초 녹음 → 5 라벨 확률 바 (hungry/burping/bellyPain/discomfort/tired). FeatureFlags.cryAnalysisEnabled gate. CryRecord 독립 Firestore 컬렉션. "신호와 유사해요" 패턴 + 면책 배너. CoreML 실모델은 v2.7+ 예정.
- **chore(privacy)**: NSMicrophoneUsageDescription + PrivacyInfo NSPrivacyCollectedDataTypeAudioData + privacy.html 울음분석 섹션
- **chore(ads)**: AdMob production App ID (ca-app-pub-6369815556964095~1504777334) + Banner Unit ID + SKAdNetworkItems 43개 확장 + app-ads.txt
- **fix(ads)**: AdBannerView `UIScreen.main` → scene-aware `safeScreenWidth()` (iOS 26.5 Beta TestFlight 51 크래시 fix — WindowScene 기반)
- feat(growth): 성장 차트 v2 — WHO AreaMark 밴드(3rd~97th) + 백분위 추이 트렌드 + "또래 상위 XX%"
- feat(analytics): Firebase Analytics (GA) 통합 — 10개 뷰 트래킹, 옵트아웃, PrivacyInfo
- feat(pattern-report): 패턴분석 v2 — 발열 연속일, 데이터 품질 경고, 기간 비교 토글, 수유 예측
- feat(timer): FloatingTimerBanner — 메인 화면 상단에 진행 중인 타이머 표시
- fix(live-activity): 실시간 카운팅 (Text(timerInterval:)) + leftover cleanup + race condition fix
- fix(ux): TimeAdjustment 미래 시점 클램프, 캘린더 월 전환 로딩 인디케이터
- docs(privacy): 개인정보처리방침 Firebase Analytics 반영
- chore(deploy): -allowProvisioningUpdates + sub-make deploy chain

## v2.7 Pre-flip Items (울음 분석 실모델 통합 시 필수)

- [ ] CreateML MLSoundClassifier로 `.mlmodel` 훈련 (Donate-a-Cry Corpus 기반)
- [ ] `CryAnalysisService.analyzeStub()` → 실모델 호출로 교체, `topLabel` 채움 (argmax)
- [ ] 히스토리 필터: stub 시절 저장된 `isStub=true` 레코드 숨김 또는 뱃지 카피 재검토
- [ ] `CryAnalysisViewModel` phase 전이 단위 테스트 추가

## Compound (개선 루프)

- **3번 반복** → Skill로 자동화
- **3번 같은 실수** → `.claude/rules/`에 규칙 추가
- **learnings**: `.dev/learnings/` (세션별 학습 기록)
- **세션 마무리**: `/wrap`으로 패턴 발견 + learnings 축적

## Verification (검증 프로세스)

```bash
make verify      # 빌드+린트+아키텍처+테스트+디자인 (에이전트 자율 루프)
make lint        # SwiftLint (.swiftlint.yml)
make arch-test   # 아키텍처 경계 검사 (Views→Services 직접 참조 탐지)
make dead-code   # 미사용 코드 탐지
```

- **CI**: `.github/workflows/ci.yml` — PR 시 make verify 자동 실행
- **리뷰**: 주요 변경 시 `/review` 또는 교차 검증 에이전트 활용
- **3-Agent QA**: Visual/UX + Code Quality + Mobile Responsive → 취합

## Active TODO

### 즉시 (사용자 액션)
- [ ] LMS 데이터 스팟체크 (WHO 원본 CSV 대조)
- [ ] 카탈로그 상품 30~40개 등록 (admin /catalog)
- [ ] Figma 토큰 설정 (FIGMA_TOKEN)

### 리팩토링 잔여
- [ ] 로컬라이제이션 (1,631개 한국어 하드코딩 → Localizable.strings 추출, 다국어 기반)

### 로드맵
- P0: 임신 모드
- P2: 사진 AI OCR, AI 실시간 제안
- P4~P6: ~~수면장소~~ ✅ (sleep-location), ~~배지 Phase 1~~ ✅ (badges), ~~badges-ui Phase 2~~ ✅ (구현 완료, 3-Agent QA + code-reviewer SHIP 대기), 커스텀활동, Apple Health, 커뮤니티
- Admin: SERVICE_ACCOUNT, 사용자관리, 통계, 개인정보처리방침
- 웹: Google Search Console, Naver 등록
