# Learnings — weekly-highlights

## TODO 1
- `isHighlightV2Enabled`는 async (RC `fetchAndActivate`가 async) — 호출부는 `Task { await ... }` 패턴 필요
- `highlight_enabled` RC default=false + `highlight_ticker_pct` default=0 → 전체 off 안전 배포
- Layer 3 cache는 기존 pregnancy 패턴(UserDefaults)과 동일. PLAN 명세의 'Keychain' 언급은 pregnancy 구현과 일치시키기 위해 UserDefaults로 진행

## TODO 2
- `project.yml` path: BabyCare (폴더 전체) 방식 → 신규 .swift 파일은 xcodegen 자동 포함, project.yml 수정 불필요
- `deleteHighlightAICache(weekKey:)`는 `whereField(weekKey)` 쿼리 + batch delete로 다건 무효화 — RC version invalidation 시그널 처리에 적합
- `HighlightFirestoreProviding` extension은 FirestoreService+Highlight.swift 하단에 협소 protocol 선언 (PregnancyFirestoreProviding 패턴과 동일)
