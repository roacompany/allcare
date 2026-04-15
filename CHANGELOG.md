# Changelog

All notable changes to BabyCare are documented here.

## [2.7.0] - 2026-04-15

### Added — Feature Enhancement Rollout (9 Items)

**대시보드**
- 컨텍스트 인사이트 카드 4종 (수유/수면 예측/건강 알림/성장 마일스톤) — `InsightService`

**수면 분석**
- 수면 퇴행 자동 감지 (4/8/12개월 ±2주, -20% 임계)
- 최적 취침 시간 추천 (최근 7일 밤잠 중앙값 ±30분)
- 낮잠 vs 밤잠 비율 트렌드
- 수면 품질 점수 (총수면 + 깨는 횟수 + 낮잠 적정성)

**예방접종**
- D-day 카운트다운 카드 + 대시보드 알림
- D-14 / D-7 / D-1 단계별 푸시 알림
- 부작용 기록 (6 type × 3 severity)
- 완료율 ProgressView (0/34 + 지연 N건 배지)

**일기**
- 월간 기분 분포 자동 요약
- 1/3/6/12개월 전 오늘 회고 카드
- Apple Charts 기반 월별 기분 트렌드
- 사진 갤러리 모드 (3열 LazyVGrid)

**식품 안전 (이유식 ↔ 알레르기 연동)**
- 이유식 기록 시 알레르기 반응 자동 제안
- 식품별 시도 히스토리 타임라인 (첫 시도 → 재시도 → 안전 확인)
- 안전 / 주의 / 금지 분류 대시보드
- 최근 90일 이유식 데이터 자동 로드

**병원 리포트**
- 소아과 방문 체크리스트 자동 생성 (다음 접종 D-day / 성장 이상 / 증상 키워드)
- 성장 백분위 요약 + 최근 2주 활동 요약 PDF 임베드
- PDF 공유 버튼 (AirDrop / Messages / Mail)

**제품 추천**
- 월령 기반 자동 추천 (0~36개월 정적 카탈로그 30개)
- 소모품 재구매 푸시 알림 + 대시보드 카드
- 쿠팡 딥링크 (SafariView)
- 인기 용품 섹션 (구매 기록 기반 Top N)

**위젯**
- 다음 수유 예상 위젯 (FeedingPredictionService v2)
- 다음 낮잠 예상 위젯
- 오늘 활동 요약 위젯 (수유/수면/기저귀)
- 성장 백분위 위젯 (WHO 밴드 기반, 면책 문구 포함)
- Lock Screen 위젯 3종 (iOS 17+ accessoryCircular / Rectangular / Inline)

### Changed

- 배지 Phase 2 코드 리뷰 반영: 공유 아기 경로(`babyVM.resolvedUserId`), `LocalizedStringKey("badge.detail.close")`, `UINotificationFeedbackGenerator` 인스턴스 재사용, `@unknown default`
- `Vaccination` 모델: `sideEffectRecords: [VaccineSideEffect]?` + `daysUntilScheduled` computed property (startOfDay 비교)
- `HealthViewModel`: `nextVaccination`, `vaccinationCompletionRate`, `vaccinationCompletionText`
- `PDFReportService`: `RenderContext` struct로 파라미터 정리, 3개 페이지 추가

### Fixed

- `HealthView`: `solidFoodActivities`가 `todayActivities`로 제한되던 문제 → 최근 90일 fetch
- `GrowthView.saveRecord` 호출 시 `baby` 파라미터 전달 → 위젯 동기화 활성화

### Internal

- 단위 테스트 107 → 195 (+88)
- `make verify` ALL CHECKS PASSED
- arch-test 0 violations 유지
- harness-score 96% Grade A 유지

---

## [2.6.2] - 2026-04-11

### Added
- 울음 분석 (베타, stub) — Health 탭 → 5초 녹음 → 5 라벨 확률 (hungry/burping/bellyPain/discomfort/tired)
- AdMob production App ID + Banner Unit ID + SKAdNetworkItems 43개 확장
- 성장 차트 v2 (WHO AreaMark 밴드 3rd~97th + 백분위 추이)
- Firebase Analytics (GA) 통합 (10개 뷰 트래킹)
- 패턴분석 v2 (발열 연속일, 데이터 품질 경고, 기간 비교)
- FloatingTimerBanner (메인 화면 진행 중 타이머)

### Fixed
- AdBannerView `UIScreen.main` → scene-aware `safeScreenWidth()` (iOS 26.5 Beta 크래시 fix)
- Live Activity 실시간 카운팅 + leftover cleanup + race condition
- TimeAdjustment 미래 시점 클램프
- 캘린더 월 전환 로딩 인디케이터
