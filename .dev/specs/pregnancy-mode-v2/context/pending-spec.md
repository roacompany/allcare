# markTransitionPending 호출 경로 Spec

**작성일**: 2026-04-23
**작성자**: P0-3 Worker Agent
**결정값**: `pending_is_valid = "valid"`

---

## 1. 코드베이스 실사 결과

gap-analyzer의 "명시적 호출 0건" 분석은 **부정확**했다.
실제 grep 결과:

```
FirestoreService+Pregnancy.swift:189  — 정의
PregnancyViewModel.swift:365          — 호출 (transitionToBaby 메서드 내)
```

### FirestoreService+Pregnancy.swift:189-192 (정의)

```swift
/// 전환 실패 복구용: transitionState=pending 상태에서 재시도 시 호출.
func markTransitionPending(_ pregnancyId: String, userId: String) async throws {
    let ref = pregnancyRef(userId: userId).document(pregnancyId)
    try await ref.setData(["transitionState": "pending", "updatedAt": Date()], merge: true)
}
```

### PregnancyViewModel.swift:359-381 (호출처)

```swift
func transitionToBaby(babyName: String, gender: Baby.Gender, birthDate: Date,
                      userId: String) async throws -> Baby {
    guard let p = activePregnancy else {
        throw PregnancyError.noActivePregnancy
    }
    // 전환 중 마커 (실패 복구용).
    try await firestoreService.markTransitionPending(p.id, userId: userId)   // line 365

    let newBaby = Baby(...)
    try await firestoreService.transitionPregnancyToBaby(
        pregnancy: p,
        newBaby: newBaby,
        userId: userId
    )
    activePregnancy = nil
    PregnancyWidgetSyncService.clear()
    return newBaby
}
```

실행 순서:
1. `markTransitionPending` → Firestore `transitionState = "pending"` 기록
2. `transitionPregnancyToBaby` (WriteBatch) → `transitionState = "completed"` + Baby 생성 (atomic)

---

## 2. 3가지 Scenario 분석

### Scenario (a): 호출 누락 버그 — v2에서 추가 필요

**가정**: v1 코드에 호출이 없고, v2에서 WriteBatch 시작 전 `markTransitionPending()`을 추가해야 함.

**평가**: **실제와 불일치**. v1 코드(`PregnancyViewModel.swift:365`)에 이미 호출이 존재한다.
그러나 이 Scenario의 논리 자체는 타당하다 — 만약 호출이 없었다면, 앱 크래시 시 `transitionState`가
`nil` 또는 `"ongoing"`으로 남아 Resume UI 진입 조건을 판별할 방법이 없다.

**결론**: Resume UI 유효성 근거로는 올바른 방향. `pending_is_valid = "valid"`.

### Scenario (b): 의도적 미구현 — WriteBatch atomic으로 충분

**가정**: WriteBatch가 원자적이므로 pending 마킹이 불필요하고, Resume UI도 제거해야 함.

**평가**: **부분적으로 타당하지만 충분하지 않음**.
WriteBatch는 서버 측 원자성을 보장하지만, 클라이언트가 `batch.commit()` 직전에 크래시하면
서버에 쓰기가 전달되지 않는다. 이 경우:
- `transitionState = nil` → 앱 재시작 시 pregnancy가 `ongoing` 상태로 남음
- Baby 문서도 생성되지 않음
- 사용자 관점: 출산 전환 시트를 다시 열어야 하지만 어떤 UI가 노출되어야 하는지 불명확

`pending` 마킹이 있으면 `transitionState = "pending"` 상태를 감지해서 Resume UI를 노출할 수 있다.
없으면 항상 새 전환 흐름을 시작해야 하고, 중복 Baby 생성 위험이 발생한다.

**결론**: Scenario (b) 채택 시 Resume UI 제거 가능하지만 중복 쓰기 방어 로직 추가 필요.
`pending_is_valid = "remove"` 이 되려면 idempotency 보장이 선제 조건.

### Scenario (c): 코드 존재, 정상 구현 — v2에서 보존 권장

**가정**: `markTransitionPending`은 현재 올바르게 구현되고 호출되고 있으며,
gap-analyzer의 "호출 0건" 분석이 잘못된 것. v2 재설계 시 이 패턴을 보존한다.

**평가**: **실제 코드와 일치**. v1 기준으로 보면:
- 정의: `FirestoreService+Pregnancy.swift:189`
- 호출: `PregnancyViewModel.swift:365`
- 설계 의도: 전환 중 크래시 → 재시작 시 `transitionState == "pending"` 감지 → Resume UI 노출

이 패턴은 "2단계 commit" 내결함성 설계로, Firebase가 오프라인 상태이거나 앱이 중간에 종료될 경우
데이터 정합성을 보장하는 표준적인 방법이다.

**결론**: Scenario (c) 채택. v2에서도 동일 패턴 보존. Resume UI 유효. `pending_is_valid = "valid"`.

---

## 3. 채택 시나리오 및 근거

**채택: Scenario (c) — 코드 존재 확인, v2 보존**

### 근거

1. **v1 호출 존재 확인**: `PregnancyViewModel.transitionToBaby:365`에서 WriteBatch commit 전에
   `markTransitionPending`을 명시적으로 호출하고 있음. gap-analyzer 분석 오류.

2. **2단계 commit 내결함성**: `pending` 마킹 → WriteBatch commit 순서는 다음 실패를 감지 가능하게 함:
   - 앱이 `markTransitionPending` 직후 크래시: `transitionState = "pending"` → Resume UI 노출
   - WriteBatch 실패 (네트워크): `transitionState = "pending"` 유지 → 재시도 가능
   - WriteBatch 성공: `transitionState = "completed"` → 정상 종료

3. **Resume UI 필요성**: 출산 전환은 되돌릴 수 없는 작업(임신 종료 + Baby 생성)이므로
   중간 실패 복구를 위한 명시적 UI가 필요하다.

4. **Orphan 문서 처리**: v1 빌드 56-61 기간 중 `pending` 상태 문서가 실제 존재할 수 있음.
   이 문서들에 대한 Recovery UI가 없으면 사용자가 영구적으로 빠져나올 방법이 없음.

**`pending_is_valid = "valid"`** — P2-2 Resume UI 구현 진행.

---

## 4. 테스트 시나리오 3개

### Test Scenario 1 (Normal): 정상 전환

**Given**: `activePregnancy.transitionState == nil` (또는 "ongoing")
**When**: `transitionToBaby()` 호출, `markTransitionPending` 성공, WriteBatch 성공
**Then**:
- Firestore: `pregnancy.transitionState == "completed"`, `pregnancy.outcome == "born"`, Baby 문서 생성
- ViewModel: `activePregnancy == nil`
- Widget: `PregnancyWidgetSyncService.clear()` 호출됨
- UI: 출산 축하 화면 노출, 이후 baby UI로 전환 (`babies.isEmpty == false`)

**검증 포인트**:
- `transitionState` 최종값이 "completed"
- Baby 문서가 생성되어 `babies` 컬렉션에 존재
- `activePregnancy`가 nil로 설정됨

### Test Scenario 2 (Pending): 크래시 후 Resume

**Given**: Firestore에 `transitionState == "pending"` 문서 존재
  (= `markTransitionPending` 성공, WriteBatch commit 전 앱 크래시)
**When**: 앱 재시작 후 `loadActivePregnancy()` 호출
**Then**:
- `activePregnancy.transitionState == "pending"` 감지
- Resume UI 노출: "전환이 완료되지 않았습니다. 다시 시도하시겠습니까?"
- 사용자가 확인 시 `transitionToBaby()` 재시도 (idempotent 보장 필요)
- WriteBatch의 Baby 생성이 `merge: false`이므로 중복 생성 없음 (이미 생성됐다면 overwrite)

**검증 포인트**:
- `loadActivePregnancy` 후 `transitionState == "pending"` 조건 분기 동작
- Resume UI 버튼 tap → `transitionToBaby` 재호출 성공
- 최종 `transitionState == "completed"`

### Test Scenario 3 (Orphan): 레거시 Pending 문서 복구

**Given**: v1 빌드 56-61 기간 (2026-04-17 ~ 2026-04-19) 생성된 `transitionState == "pending"` 문서.
  Baby 문서가 이미 생성된 경우(WriteBatch 성공 후 로컬 상태만 crashing) 또는 미생성인 경우 모두 포함.
**When**: v2(pregnancy-mode-v2) 앱 첫 실행 시 `loadActivePregnancy()` 호출
**Then**:
- `transitionState == "pending"` 감지 → Recovery UI 노출
- Baby 문서 존재 여부 체크:
  - Baby 존재: "전환이 완료되었습니다" 메시지 + `transitionState` = "completed"로 업데이트
  - Baby 미존재: Resume UI → 재시도
- 어떤 경우도 `activePregnancy`를 삭제하거나 데이터를 유실하지 않음

**검증 포인트**:
- v1 Firestore 스키마와 v2 호환성 (동일 필드명 `transitionState`)
- Baby 존재 체크 로직 (orphan 감지)
- "데이터 삭제 절대 금지" 원칙 준수

---

## 5. v2 구현 지침 (P2-1 참고용)

P2-1에서 `markTransitionPending` 호출을 구현할 때:

1. **호출 위치**: WriteBatch `commit()` 직전, `transitionPregnancyToBaby` 호출 직전 유지 (v1 패턴 보존)
2. **에러 처리**: `markTransitionPending` 자체 실패 시 전환 중단 (WriteBatch 진입 금지)
3. **Idempotency**: `merge: true`로 이미 구현됨 — 재호출 안전
4. **Recovery 조건 감지**: `loadActivePregnancy` 후 `transitionState == "pending"` 체크
5. **Orphan 조건**: Baby 컬렉션에서 해당 pregnancy 출신 Baby 존재 여부 추가 확인

---

## 결정 요약

| 항목 | 값 |
|------|-----|
| `pending_is_valid` | `"valid"` |
| 채택 Scenario | (c) — 코드 존재 확인, v2 보존 |
| Resume UI | 구현 진행 (P2-2) |
| 근거 | v1 호출 존재, 2단계 commit 내결함성, Orphan 문서 복구 필요 |
