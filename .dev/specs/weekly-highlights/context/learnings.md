# Learnings — weekly-highlights

## TODO 1
- `isHighlightV2Enabled`는 async (RC `fetchAndActivate`가 async) — 호출부는 `Task { await ... }` 패턴 필요
- `highlight_enabled` RC default=false + `highlight_ticker_pct` default=0 → 전체 off 안전 배포
- Layer 3 cache는 기존 pregnancy 패턴(UserDefaults)과 동일. PLAN 명세의 'Keychain' 언급은 pregnancy 구현과 일치시키기 위해 UserDefaults로 진행
