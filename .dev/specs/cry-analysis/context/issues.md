## TODO 7
- [ ] `make test` 기본 destination이 `iPhone 17 Pro` 시뮬레이터인데 ABRT 크래시 발생. Worker가 `iPhone 16e`로 fallback하여 테스트 통과. Makefile destination 수정 필요할 가능성 — 사용자 확인 후 `iPhone 16e` 또는 안정적인 모델로 업데이트 검토.

## Code Review Pre-flip Items (v2.7 필수)

코드 리뷰(Claude) 결과 SHIP. Feature flag가 false이므로 production 도달 불가라 현재는 비차단. `FeatureFlags.cryAnalysisEnabled = true`로 flip 전에 반드시 해결:

- [ ] **CR-001 (warning)**: `CryAnalysisService.configureForRecording()`에서 `SoundPlayerService.shared.stop()` 호출 누락. 녹음 시작 시 백색소음/자장가 재생 중이면 silently interrupted 상태로 남음. PLAN.md Assumption row 9가 명시한 조율이 구현부에서 빠짐.
  - Fix: `configureForRecording()` 최상단에 `SoundPlayerService.shared.stop()` 추가, `restoreAfterRecording()`에서 필요 시 resume.

- [ ] **CR-002 (warning)**: `CryAnalysisViewModel.start()` 내 `try? await Task.sleep(nanoseconds:)` 가 cancellation을 swallow. 녹음 중 View 이탈 시 Task가 detached하여 AVAudioSession이 `.playAndRecord` 상태로 남을 수 있음.
  - Fix: `@State private var recordingTask: Task<Void, Never>?` 저장, `.onDisappear { recordingTask?.cancel() }`, `try?` → `try` 로 변경 + `guard !Task.isCancelled else { service.restoreAfterRecording(); return }`.

- [ ] **CR-003 (warning)**: `babyId.isEmpty` guard 부재. `selectedBaby`가 nil일 때 `vm.start(babyId: "")` 진행 → 저장 시 `.../babies/""/cryRecords/...` orphan 문서 생성 가능.
  - Fix: `CryAnalysisViewModel.start()` 최상단 또는 View 호출 사이트에 `guard !babyId.isEmpty else { return }`.

- [ ] **CR-005 (info)**: Stub 단계에 저장된 `isStub: true` 레코드가 flag flip 후 production 사용자의 History에 "테스트" 뱃지로 노출. `history.filter { !$0.isStub }` 또는 뱃지 카피 "베타" 로 변경 검토.

## Code Review Non-blocking Items (v2.7 nice-to-have)

- CR-004 (info): `analyzeStub()`에 v2.7 `topLabel = argmax(probabilities)` 설정 TODO 주석 추가
- CR-006 (info): `CryAnalysisViewModel` Phase 전이 단위 테스트 추가 (PLAN.md Verification Gap에 이미 기록됨)
- CR-008 (info): App Store 리뷰 노트에 "베타 기능, feature flag로 숨김 처리" 명시 권장
- CR-009 (info): `CryAnalysisViewModel`에 `private let db = Firestore.firestore()` 프로퍼티 추출 (스타일 일관성)
