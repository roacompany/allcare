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

## Design (디자인 시스템)

```bash
make design-verify   # ROA 토큰 검증 (roa verify babycare)
make design-sync     # 토큰 → DesignSystem.generated.swift
make screenshots     # 주요 화면 스크린샷 캡처
```

- 디자인 토큰: `design/tokens/babycare-tokens.json`
- ROA 설정: `.roa-design.json` (brand primary: #FF9FB5)
- 위젯 다크모드: `WidgetColors` adaptive enum + `WidgetGradient.background(colorScheme)`

## Build & Deploy (Makefile)

```bash
make build       # xcodegen + xcodebuild
make test        # 단위 테스트 25개
make verify      # 빌드 + 테스트 + 디자인토큰
make deploy      # 원커맨드 배포 (bump→archive→export→upload)
make bump        # 빌드 번호 +1
make status      # 버전/커밋/테스트 상태
make clean       # 빌드 산출물 정리
```

## Architecture

- **패턴**: @MainActor @Observable MVVM, AppState 싱글톤 (18 VM)
- **서비스 분리**: ActivityTimerManager (타이머), FeedingPredictionService (예측), PercentileCalculator (성장)
- **분석**: Services/Analysis/ — 6단계 파이프라인
- **인프라**: RetryHelper (지수 백오프), OfflineQueue (쓰기 큐잉), CachedAsyncImage (2-tier 캐시), NetworkMonitor (자동 sync)
- **Firestore**: 200MB persistent cache, 19개 컬렉션
- **탭**: 홈 | 캘린더 | ➕기록 | 건강 | 설정

## Conventions

- Swift 6.0, iOS 17+, 100% SF Symbols
- 모델: `Identifiable, Codable, Hashable`, 신규 필드 optional
- 색상: `AppColors` enum (Asset Catalog 18개 Dynamic Color)
- 의학 데이터: 면책 문구 필수
- AI 가드레일: AIGuardrailService.prohibitedRules 수정 금지
- 테스트: BabyCareTests.swift 단일 파일에 append

## Must NOT Do

- Baby.gender Optional 변경 금지
- AIGuardrailService 금지어 수정 금지
- 백분위 의학적 판단 텍스트 금지
- 외부 차트 라이브러리 금지 (Apple Charts만)

## Current Status

- **Version**: v2.5.0 (빌드 41) + 미배포 커밋 다수
- **App Store**: v2.5.0 (빌드 40) READY_FOR_SALE
- **테스트**: 25개 PASS
- **규모**: ~195 Swift 파일

## Active TODO

### 즉시 (사용자 액션)
- [ ] TestFlight 빌드 배포 (make deploy)
- [ ] LMS 데이터 스팟체크 (WHO 원본 CSV 대조)
- [ ] 카탈로그 상품 30~40개 등록 (admin /catalog)
- [ ] Figma 토큰 설정 (FIGMA_TOKEN)

### 기술부채 잔여
- [ ] 페이지네이션 (대량 기록 시 무한 스크롤)

### 로드맵
- P0: 임신 모드
- P2: 사진 AI OCR, AI 실시간 제안
- P4~P6: 수면장소, 커스텀활동, Apple Health, 배지, 커뮤니티
- Admin: SERVICE_ACCOUNT, 사용자관리, 통계, 개인정보처리방침
- 웹: Google Search Console, Naver 등록
