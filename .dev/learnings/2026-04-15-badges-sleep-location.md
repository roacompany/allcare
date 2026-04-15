# Badges Phase 1 + Sleep Location Learnings (2026-04-15)

## Firestore merge:true + Codable non-optional 함정 (CR-001 Critical)

- `incrementStats`가 `FieldValue.increment` + `merge: true`로 한 번에 **한 필드만** 쓰기 → fresh user 문서는 나머지 count 필드가 존재하지 않음
- `Codable struct`에 `var totalFeeds: Int` (non-optional) 선언 시 `data(as: UserStats.self)` decode 실패 (`keyNotFound`)
- `try? await fetchStats()` → `nil` 반환 → 집계 배지 threshold check skip → **배지 영원히 획득 불가**
- **해결**: 증분 카운터 필드는 반드시 `Int?` + `?? 0` 패턴
- **문서화**: `.claude/rules/firestore-rules.md`에 규칙 추가됨

## Gamification 설계 핵심 필드 (Codex 권고)

- **`conditionVersion: Int`** — 향후 배지 조건 변경 시 마이그레이션 경로 확보. 기존 취득 배지는 `conditionVersion=1`로 고정, 신규 조건은 `2`.
- **`earnedAtDateUTC: String`** (`yyyy-MM-dd`) — 사용자 타임존 이동/기기 타임존 변경 시 "오늘 달성" 판정 일관성. 표시만 로컬 변환.
- 적용 대상: 모든 "N일 연속", "오늘 첫 기록" streak/badge 엔티티

## 육아 앱 특화 UX 원칙 (UX Reviewer)

- **풀스크린 모달 금지** — 야간 수유 세션에서 화면 밝기/소음으로 아기 깨움
- **사운드/진동 기본 OFF** — 수면 기록 직후 진동 위험
- **감성 문구 과잉 금지** — 피곤한 부모에게 "당신의 사랑이..."는 공허함 유발. 담백한 "수유 100회"
- **미획득 배지 카운트다운 금지** — 죄책감/할당량 압박 유발
- **가족 공유 기본 OFF** — 경쟁/부담 방지 (Private + 토글 패턴)

## saveBadge 결과 gate — phantom 시그널 방지 (CR-002)

- `try? await firestoreService.saveBadge(...)` → 에러 swallow → 배지 객체는 생성되어 반환됨
- Phase 2 UI: 저장 안 된 배지 스낵바 표시 → 다음 evaluate에서 `badgeExists=false` → 반복 트리거
- **해결**: `saveBadge` → `Bool` 반환 (true=신규, false=이미 존재 or 에러). `tryEarn`에서 `saved ? badge : nil`

## DateFormatter 성능 (CR-003)

- `DateFormatter`는 **thread-safe** (Apple 공식 문서) — `static let`으로 공유 가능
- 매 호출마다 할당은 retroactive sweep(Phase 2)에서 비용 큼
- 패턴: `private static let utcFormatter: DateFormatter = { ... }()`

## 하네스 엔지니어링 6축 파이프라인 (실전)

- **구조→맥락→계획→실행→검증→개선** 순환을 기능 단위로 끊어 2회 완주 (sleep-location, badges Phase 1)
- **Phase 분할 가치**: 배지 10 TODOs → Phase 1(backend) / Phase 2(UI) 분할로 범위 폭발 방지
- **HIGH risk decision_point**: 계획 단계에서 사용자 노출 → 번복 비용 최소화 (DP-01 Retroactive, DP-02 Stats 문서)
- **Cross-check 결과 사용자 결정 번복**: Q2 경로 혼합 → 단일 변경 (Tradeoff + Codex 합의)

## 병렬 Worker — 독립 파일 동시 수정

- 조건: 두 작업이 같은 파일 건드리지 않음
- TODO 2,3,4 병렬 실행으로 경과 시간 40%+ 단축
- git commit만 순차 처리

## SourceKit 경고 vs xcodebuild 결과

- **재확인된 원칙**: SourceKit 진단은 IDE 실시간 인덱싱, 빌드 결과 아님
- 이번 세션 5회+ 반복 발생 (Activity/FirestoreService/Badge "Cannot find type")
- `make build`/`make verify` 성공 로그가 truth
- **관찰**: 신규 Swift 파일 추가 직후 가장 빈번
