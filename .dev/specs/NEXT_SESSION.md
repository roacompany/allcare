# BabyCare 다음 세션 인계 — 2026-05-15

> 마지막 세션: CI Test 인프라 부채 완전 해소 (PR #7 + #8) + v2.8.3 빌드 68 코드 verification 완료.
> 현재 main: `28b4c13` (clean). 모든 작업 commit + push + 머지 완료.

---

## 한 줄 요약

**v2.8.3 빌드 68 App Store 제출 준비 완료**. CI 370/370 PASS, 코드 회귀 0, RC 3-Layer gating 안전. 다음 액션은 PO/Claude 둘 다 선택 가능.

---

## 새 세션 시작 시 첫 5분

```bash
cd /Users/roque/BabyCare
git status                      # clean 확인
git log --oneline -5            # 28b4c13 (docs) → c291e33 (PR #8) → afd5aff (docs) → 2c57c1f (PR #7)
cat .dev/specs/NEXT_SESSION.md  # 이 파일 다시 읽기
```

---

## 즉시 진행 가능한 액션 (Claude 자동 가능)

### A. App Store v2.8.3 심사 제출 ⭐ Recommended
- **트리거**: "App Store 제출", "v2.8.3 제출", "asc-submit"
- **소요**: ~3분 (ASC API 5-step 자동화)
- **선결**: 빌드 68 = VALID ✅, 코드 회귀 0 ✅, CI green ✅
- **스킬**: `asc-submit`
- **완료 시**: `WAITING_FOR_REVIEW` 상태, AFTER_APPROVAL 자동 출시 (12-48h)

### B. Phase 2 ML CoreML 베이스라인 작업
- **트리거**: "Phase 2 ML 시작", "CoreML 베이스라인"
- **소요**: 1-2주 (별도 PR + 합성 데이터 + InsightScorer 프로토콜 swap)
- **참조**: `BabyCare/Services/Insights/`

### C. 로컬라이제이션 (영어 지원)
- **트리거**: "로컬라이제이션 시작"
- **소요**: 대규모 (1,631개 한국어 하드코딩 → Localizable.strings 추출)
- **권장**: A/B 완료 후 진행

---

## PO (사용자) 액션 필요

### 1. TestFlight 빌드 68 실기기 검증 (이미 설치 완료, 5분)
체크리스트:
- [ ] 앱 정상 launch (login screen 표시)
- [ ] 대시보드 정상 렌더 (인사이트 카드 v1 표시 — V2 RC OFF 상태)
- [ ] 임신 모드 진입 (Settings → Add Baby → 임신 등록)
- [ ] 기존 기능 회귀 없음 (기록/캘린더/건강/설정 4탭)

### 2. AI 의료 감수 (H-3, 25 샘플)
- Admin batch Cron 결과 기반
- `babycare-admin` Vercel Cron 02 KST daily 실행 결과 확인
- 25 샘플 medical professional 검토
- 결과에 따라 Weekly Highlights v2 RC 활성화 여부 결정

### 3. Firebase Console RC 단계 활성화 (감수 통과 후)
```
highlight_enabled: false → true
highlight_ticker_pct: 0 → 5 → 25 → 50 → 100 (단계적, Crashlytics 모니터링)
```
- 5%부터 시작 권장 (~24h 관찰)
- Crashlytics 무회귀 확인 후 다음 단계
- 완료 시간: 1-2주 단계적

### 4. AdMob Console 차단 항소 (코드는 이미 폐기)
- AdMob Console에서 차단 사유 확인
- 항소 제출
- 통과 시: `FeatureFlags.adsEnabled=true` 1줄 복구 (자동 가능)

### 5. H-10 법무 검토 (1주 external)
- `https://roacompany.github.io/allcare/privacy.html` §3 임신 데이터 보강
- 외부 법무 자문 → 결과 반영

---

## 오늘 완료한 작업 (참고)

### PR #7 — CI Test 인프라 fix (`2c57c1f`)
- **진짜 root cause**: stub plist `API_KEY` 35자 (39자 필수) → `+[FIRInstallations validateAPIKey:]` SIGABRT
- 4 iter 추측 fix 후 `-resultBundlePath` artifact + verbose log로 stack trace 확보 → 1줄 fix
- 학습: **`-quiet` 플래그가 데이터 가리면 추측 commit 누적. diagnostic 인프라부터 깔 것.**

### PR #8 — CI Test 사전 부채 5건 fix (`c291e33`)
- root cause 4종:
  1. **timezone**: KST 자정 → UTC 어제 → CI runner Calendar.current 다른 month 인식 (Diary 2건) → 4/15 정오로 변경
  2. **단일 변수로 두 분기 검증**: `reduceMotion=true` 한 변수로 양쪽 → 3 case 분리 + production helper 추출 (testable)
  3. **assertionFailure가 throw 전 SIGTRAP**: HighlightAISummaryService → 제거 (throw가 계약)
  4. **stillbirth duration 0초**: 직전 AISummary host crash 연쇄 → AISummary fix로 자동 해결
- 370/370 PASS, multi-model 리뷰 (Gemini+Claude SHIP) + CR-001 (testable helper) 적용

### v2.8.3 빌드 68 코드 Verification (제출 보류, 보고서 작성 완료)
- ASC API: 빌드 68 VALID, 만료 2026-08-10
- Build 68 → main HEAD diff: 사용자 영향 0 (테스트 인프라 변경만)
- Weekly Highlights v2 핵심 파일 5개 모두 존재 + Dashboard XOR 통합 정합
- RC 3-Layer gating 검증: default OFF (안전한 staged rollout)
- **결론: App Store 제출 GO**

---

## 인프라 상태 (2026-05-15 18:00 KST)

| 항목 | 상태 |
|---|---|
| Branch | main = `28b4c13` (clean) |
| CI Test | ✅ 370/370 PASS, 0 skip |
| Build/Lint/Arch | ✅ ALL GREEN |
| 빌드 68 ASC | ✅ VALID |
| v2.8.3 AppStoreVersion | ❌ 미생성 (제출 전 정상) |
| RC `highlight_enabled` | ❌ false (default, OFF) |
| RC `highlight_ticker_pct` | ❌ 0 (default, OFF) |
| TestFlight 빌드 68 | ✅ 사용자 실기기 설치 완료 |

---

## 알려진 부채 / 후속 PR 후보

- 시뮬레이터 install 권한 (macOS 25.5 Tahoe) — System Settings 수동 허용 필요. `/Applications/Utilities/Terminal.app` Developer Tools 권한.
- AdMob 항소 후 코드 복구 (1줄)
- Phase 2 ML 활성화 (4주+ 데이터 누적 후)
- 로컬라이제이션 (영어 지원)
- Admin Insights RC 라이브 가중치
- H-4 산부인과 전문의 pregnancy-weeks 의료 검증 (2주 external)

---

## 다음 세션 진입 트리거 예시

| 의도 | 입력 |
|---|---|
| App Store 제출 | "v2.8.3 제출" / "asc-submit" |
| 실기기 검증 결과 보고 | "검증 완료" / "회귀 없음" |
| 회귀 발견 시 디버깅 | "X 안 됨" / "Y가 깨졌어" |
| RC 활성화 가이드 | "RC 활성화" / "highlight 5% 시작" |
| Phase 2 ML 시작 | "Phase 2 시작" / "CoreML" |
| 다른 작업 | 자유 입력 |
