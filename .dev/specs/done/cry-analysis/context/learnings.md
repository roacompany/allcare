## TODO 1
- project.yml의 info.properties 블록은 라인 127 근처 NSCalendarsFullAccessUsageDescription 다음에 추가
- PrivacyInfo.xcprivacy는 tab-indented XML plist, NSPrivacyCollectedDataTypes 배열 끝에 새 dict 추가
- privacy.html 섹션 2는 ul 리스트, 새 li 항목 추가

## TODO 2
- Swift Dictionary `[CryLabel: Double]`는 JSON 객체로 인코딩 불가 → `[String: Double]` 내부 저장 + typed computed property (`labelProbabilities`) 패턴 사용
- AuthViewModel/DiaryViewModel의 nonisolated(unsafe) 경고 2건은 pre-existing (TODO 2 원인 아님)
- BabyCare 모델은 불변 record 타입에 `let` 사용 (Activity는 mutable tracking이라 var 사용)
- FirestoreCollections는 `enum`(caseless) + static let 패턴 — 신규 상수는 동일 패턴 따름
- TODO 2 worker가 부수적으로 project.yml CURRENT_PROJECT_VERSION 49→50 bump했으나 TODO 2 범위 밖. 배포 시점 충돌 가능성 주의

## TODO 3
- `CryRecord.init(probabilities:)`는 `[String: Double]` 타입 — `CryLabel` 값은 `.rawValue`로 매핑 후 주입
- `.allowBluetooth`는 iOS 8부터 deprecated → `.allowBluetoothHFP` 사용 (경고 방지)
- `CryAnalysisService`는 `@Observable` 없이 `@MainActor final class` 만 — stored observable state 없음
- SourceKit이 macOS 컨텍스트에서 `AVAudioSession` 미가용 경고 표시 — 실제 iOS 빌드는 정상, IDE 인덱싱 한계

## TODO 4
- BabyCare ViewModel 패턴은 `@MainActor` 를 클래스 선언에만 (메서드 개별 x)
- `make build`는 xcodebuild `-quiet` 플래그 사용 — stdout warning 숨김, stderr에만 표시
- `Phase.result(CryRecord)` Equatable은 CryRecord 전체가 아닌 `id` 기반 비교로 구현 (explicit ==)
- `FirestoreCollections.cryRecords`는 Constants.swift:84에 이미 존재 (TODO 2에서 추가됨)
- `try? await Task.sleep` 는 cancellation을 swallow하므로 녹음 중 취소 시 restoreAfterRecording() 누락 가능성 — 경미, cancel() 경로가 있으므로 OK

## TODO 7
- `@MainActor` test 함수는 각 테스트에 개별 데코레이터 필요 (클래스 레벨 아님)
- `make test` 기본 destination(iPhone 17 Pro)가 ABRT 크래시 — iPhone 16e는 안정. Makefile 업데이트 검토
- `JSONEncoder` codable round-trip 패턴: 기존 AllergyRecord 테스트와 동일하게 `.iso8601` dateEncodingStrategy
- `CryRecord` init은 all-fields required (isStub), topLabel은 optional default nil

## TODO 5
- `OnboardingRow`/`DisclaimerBanner` 서브뷰의 `body` 속성명은 `View` protocol의 `body: some View`와 충돌 → `description` 등 다른 이름 사용
- `babyVM.selectedBaby?.id` 가 현재 아기 ID 가져오는 표준 패턴 (HealthView.swift 참조)
- `babyVM.dataUserId(currentUserId:)` nil-coalescing 체인: `babyVM.dataUserId(currentUserId: authVM.currentUserId) ?? authVM.currentUserId ?? ""`
- `UIImpactFeedbackGenerator(style: .medium).impactOccurred()` 인라인 호출 패턴 (저장 인스턴스 아님)
- `.onChange(of:)` Swift 6 compatible 2-arg closure: `(oldValue, newValue) in`
- Charts BarMark 가로 확률 바: `chartXScale(domain: 0...1)` 정규화 필요
- `.presentationDetents([.medium, .large])` iOS 16+ 패턴

## TODO 6
- `HealthSectionCard` 시그니처: `icon, iconColor, title, subtitle, badge: String?, badgeColor` — 6 params required
- `AppColors.indigoColor`는 Asset Catalog 동적 컬러 — hardcoded Color 금지 원칙 준수
- feature flag는 NavigationLink를 outer-level `if` 블록으로 감싸야 함 (conditional modifier 아님) — 플래그 false 시 zero rendering
