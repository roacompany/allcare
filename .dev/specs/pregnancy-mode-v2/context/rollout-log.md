# v2.8.0 Rollout Log

**버전**: v2.8.0 (MARKETING_VERSION)
**빌드 번호**: 62 → **63** (make deploy 실행 시 bump)
**작성일**: 2026-04-23
**작성자**: Worker Agent — P4-2 scaffold

---

## P0-2b 의존성 상태 ✅ RESOLVED

| 항목 | 상태 | 비고 |
|------|------|------|
| `feat/firebase-11.8.0-compat` → main 머지 | **✅ DONE** | PR #3 squash-merged 2026-04-24T01:15:34Z → `7d80f93` on main |
| main `project.yml` Firebase 버전 | **11.9.0** | merge commit 7d80f93 |
| pregnancy-mode-v2 Firebase 버전 | **11.9.0** (sync됨) | merge commit `caeb7fe` (Merge main) |
| `make verify` (merge 후) | ✅ ALL CHECKS PASSED | DerivedData clean 후 재빌드 필요했음 |

---

## App Store 심사 상태 ✈️ WAITING_FOR_REVIEW

| 항목 | 값 |
|------|------|
| 버전 | **v2.8.0** |
| 제출 일시 | 2026-05-01 18:12 UTC (2026-05-02 03:12 KST) |
| state | `WAITING_FOR_REVIEW` |
| Release Type | `AFTER_APPROVAL` (승인 후 자동 출시) |
| ASC Version ID | `7fecf273-ea07-4f07-810e-92d0a131fdd6` |
| Review Submission ID | `642e330e-3769-4e79-ab2e-2447f7c71899` |
| Build | 64 (Delivery `51a6cd4d-e298-4b55-b2d6-c6bfdb00895f`) |
| Privacy Policy | https://roacompany.github.io/allcare/privacy.html (allcare commit `817b787`, v2.8.0 §3 라이브) |
| Release Notes (ko) | "v2.8.0 — 안정성 강화 및 성능 개선..." (315자) |
| H-12 RC 게이팅 | `pregnancy_mode_enabled = false` 유지 — 심사관이 임신 UI 미노출 |

심사 평균 12-24h, 최대 48h. 결과:
- **APPROVED** → AFTER_APPROVAL이라 자동 출시 (사용자에게 즉시 노출)
- **REJECTED** → 사유 확인 + fix + 재제출 (재심사 ~24h)

## TestFlight 업로드 상태 ✅ COMPLETE

| 항목 | 상태 |
|------|------|
| 빌드 64 | **✅ UPLOAD SUCCEEDED** (AdMob child-directed=false fix + PatternReport Keychain) |
|   Delivery UUID | `51a6cd4d-e298-4b55-b2d6-c6bfdb00895f` |
|   업로드 일시 | 2026-05-01 23:31 KST |
|   포함 fix | `5b6ac5f` AdMob child-directed=false, `9d5de14` PatternReport Keychain |
| 빌드 63 | ✅ UPLOAD SUCCEEDED |
|   Delivery UUID | `09fa6305-8981-4593-b2a1-de1e3d150463` |
|   업로드 일시 | 2026-04-24 10:33 KST |

**빌드 64 deploy 절차**:
- `make deploy` chain은 ui-test 단계에서 시뮬레이터 destination 매칭 실패 (iOS 26.2 mkstemp 이슈) → 단계 분해 실행
- ui-test 단독 (iOS 26.4 simulator ID 명시): 18 XCUITest 0 failures PASS
- bump(63→64) → archive → export → upload (수동 keychain unlock + search list 갱신 필요)
- **개선 필요**: Makefile DEST를 ID 명시(`id=E8CF2728-...`)로 영구 변경, sub-make 변수 전파 이슈 해결

---

## RemoteConfig Rollout 타임라인

| 단계 | 날짜 | 상태 | 비고 |
|------|------|------|------|
| TestFlight 업로드 | _(make deploy 후)_ | [ ] PENDING | 빌드 번호 기재 필요 |
| 내부 테스터 배포 | D+0 | [ ] PENDING | TestFlight 승인 대기 |
| 3일 무회귀 모니터링 | D+0 ~ D+3 | [ ] PENDING | Crashlytics crash-free >= 99% 확인 필요 |
| Crashlytics 24h 확인 | D+1 | [ ] PENDING | pregnancy crash 0건 |
| Crashlytics 72h 확인 | D+3 | [ ] PENDING | pregnancy crash 0건 |
| **RC 100% rollout** | **D+3 이후** | **[ ] PENDING — Firebase Console 사용자 직접** | `pregnancy_mode_enabled = true` |
| App Store 제출 | D+7 이후 (권장) | [ ] PENDING | RC 100% 안정 확인 후 |

**RC rollout 절차** (사용자 직접 — Firebase Console):
1. Firebase Console → Remote Config → `pregnancy_mode_enabled` 편집
2. 조건 없음(모든 사용자) → Value: `true`
3. Publish changes

---

## Crashlytics 모니터링 체크리스트

3일 무회귀 확인 항목:

- [ ] D+0: crash-free rate >= 99%
- [ ] D+0: pregnancy 관련 crash 0건 (PregnancyViewModel/KickSession/PregnancyWidgetDataStore)
- [ ] D+1: crash-free rate >= 99%
- [ ] D+1: pregnancy crash 0건
- [ ] D+2: crash-free rate >= 99%
- [ ] D+3: crash-free rate >= 99% — **RC rollout 조건 충족**
- [ ] D+3: RC 100% rollout 실행 (Firebase Console)
- [ ] D+4: RC rollout 후 24h Crashlytics 모니터링
- [ ] D+4: pregnancy crash 0건 확인

```
Crashlytics crash-free: [기재 필요 — TestFlight 배포 후 기록]
```

---

## TestFlight 내부 테스터 피드백 체크리스트

| 시나리오 | 테스터 | 상태 | 비고 |
|----------|--------|------|------|
| Resume UI (transitionState=pending) | QA | [ ] | orphan recovery 플로우 |
| baby-only 사용자 (임신 UI 미노출) | QA | [ ] | gating 검증 |
| both (임신 + 아기 공존) | QA | [ ] | baby > pregnancy 우선순위 |

---

## P0-2b (Firebase 11.8.0) Merge 체크리스트

```
[ ] feat/firebase-11.8.0-compat → main PR 생성
[ ] main PR 머지 완료 (commit 204cf49 포함)
[ ] pregnancy-mode-v2 worktree rebase/sync
[ ] make verify PASS (Firebase 11.8.0 환경)
[ ] make deploy 실행 가능 상태 확인
```

---

## 배포 Readiness 요약

| 항목 | 상태 |
|------|------|
| MARKETING_VERSION 2.8.0 | DONE |
| QA evidence v2.8.0.md (PASS 마커) | DONE |
| make qa-check | PASS |
| make arch-test | PASS (0 violations) |
| P0-2b Firebase 11.8.0 main 머지 | **BLOCKED** |
| H-1~H-12 Human QA | **모두 PENDING** |
| make deploy | **DEFERRED — 사용자 실행** |
| RC 100% rollout | **DEFERRED — Firebase Console 사용자 직접** |

**deploy_readiness**: `BLOCKED_P0-2B`

---

## 롤백 계획

긴급 롤백 (RC 100% 후 심각한 regression 발생 시):

```
Firebase Console → Remote Config → pregnancy_mode_enabled → false → Publish
```

- Firestore 데이터 삭제 금지 (feedback_no_data_deletion.md 준수)
- 앱 재배포 불필요 (RC false로 즉시 UI hidden)
- 빌드 롤백은 App Store Connect에서 이전 버전 복원

---

## 참조

- PLAN.md P4-2 (line 1706): TestFlight v2.8.0 업로드 + RemoteConfig 100% rollout
- `.dev/qa-evidence/v2.8.0.md`: QA evidence 파일 (PASS 마커 포함)
- `project.yml`: MARKETING_VERSION 2.8.0 (이 파일 작성 시점)
- P0-2b: `feat/firebase-11.8.0-compat` commit `204cf49` (main 미머지)
- Codex Rec-6: 3단계 rollout → TestFlight 검증 + 직접 100% (DAU 규모 보강 필요)
