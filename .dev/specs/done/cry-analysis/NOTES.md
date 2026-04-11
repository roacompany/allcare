# Cry Analysis Feature — Session Handoff Notes

> ChatterBaby 스타일 울음 분석 기능. 이전 세션(2026-04-10)에서 탐색 + 분석까지 완료.
> 다음 세션에서 이 문서를 로드해 `/specify --autopilot`으로 PLAN.md 생성하면 됨.

---

## 기능 개요

BabyCare iOS에 아기 울음소리 분석 기능 추가.
- 부모가 녹음 버튼 → 5-10초 마이크 녹음
- CoreML 온디바이스 분류 → 5가지 이유 (hungry, burping, belly_pain, discomfort, tired)
- 확률 바 차트로 결과 표시 (단정적 라벨 금지)
- Health 탭 섹션 카드로 진입 (독립 CryAnalysisView)
- 의학 판단 금지, 면책 필수

---

## 사용자 확정 결정 (4개 DP — 모두 B 옵션)

### DP-01: 데이터 저장 방식 → **B**
- `babies/{babyId}/cryRecords/{recordId}` **독립 Firestore 컬렉션**
- Activity 모델 수정 금지
- `FirestoreCollections.cryRecords` 상수 추가
- 이유: 기존 21개 컬렉션 스키마 오염 방지, 롤백 쉬움

### DP-02: 분석 결과 처리 → **B**
- 자동 Activity 연계 금지
- 결과 화면에 **명시적 "저장" 버튼**만 제공
- 이유: 오분류가 공식 기록으로 굳어지는 것 방지

### DP-03: .mlmodel 파일 → **B**
- Placeholder `.mlmodel` 번들 포함 금지
- **CryAnalysisService 인터페이스 + CryAnalysisView UI만 구현**
- CoreML 연결부는 stub (실제 훈련된 모델 준비 후 서비스 레이어만 교체)
- Feature flag로 UI 진입점 gate 가능
- 이유: Boundaries 명시 위반 방지, 오도적 결과의 production slip 방지

### DP-04: 통계/패턴 분석 → **B**
- MVP에서는 제외
- v2 로드맵 이관
- 대신 단순 "세션 히스토리 목록" (라벨 + 타임스탬프)만 제공
- PatternReport에 울음 이유별 차트 추가 금지
- 이유: 부정확 모델 기반 통계는 오정보, App Store 4.0 위반 리스크

---

## 기술 스택 (external-researcher 조사 결과)

### 프레임워크
- **SoundAnalysis.framework** (iOS 15+, system framework, 새 의존성 없음)
- `SNClassifySoundRequest(mlModel:)` — custom .mlmodel 주입 가능
- **AVAudioEngine** + `SNAudioStreamAnalyzer` — 실시간 스트림 분석
- AVAudioRecorder는 단순 녹음에만 사용 (file-based)

### Swift 6 Concurrency
- `AVAudioPCMBuffer`는 non-Sendable → actor-wrapped `AudioCaptureActor` 필요
- `SNResultsObserving` observer는 `@MainActor`로 격리
- tap callback 안에서 `DispatchQueue.sync` 사용 (actor 경계 회피)

### 모델 (향후 훈련 필요)
- **Donate-a-Cry Corpus** (github.com/gveres/donateacry-corpus)
  - 9 classes → MVP에서 5 class 사용: hungry, burping, belly_pain, discomfort, tired
  - 457 samples + augmentation (~2000)
  - ODbL license (상업 사용 가능)
  - iOS .caf + Android .3gp → 16kHz mono WAV 변환 필요
- **CreateML MLSoundClassifier** (macOS)로 transfer learning 훈련
- 출력 `.mlmodel`: 50~100KB (transfer learning head만)
- 추론 지연: 5~20ms per 1s window (Neural Engine)

### 번들링
- `.mlmodel` 파일은 project.yml의 `sources`에 추가 (resources 아님)
- Xcode가 자동으로 `.mlmodelc`로 컴파일
- XcodeGen은 PR #457로 `.mlmodel` 확장자 compile 지원

---

## 탐색 결과 요약 (이전 세션)

### 기존 audio 인프라
- `BabyCare/Services/SoundPlayerService.swift` — **playback only** (AVAudioPlayer, AVPlayer)
- `AVAudioSession.setCategory(.playback)` — 재생 전용
- **녹음 인프라 전무**: AVAudioRecorder / AVAudioEngine / SoundAnalysis 사용 없음
- `NSMicrophoneUsageDescription` **없음** → project.yml 추가 필요

### Activity 모델 (수정 금지)
- `BabyCare/Models/Activity.swift:29-124` — ActivityType enum
- `.feeding / .sleep / .diaper / .health` 4개 category
- `CaseIterable` → switch문 전수 검토 필요하므로 새 케이스 추가 위험
- 대신 **독립 CryRecord 모델** 사용

### Health 탭 (진입점)
- `BabyCare/Views/Health/HealthView.swift:12-178`
- NavigationLink 섹션 카드 패턴 (`HealthSectionCard`)
- 현재 10개 섹션 (이미 스크롤 필요)
- 신규 카드 위치: **"아기 소리" 다음, "일기" 이전** (audio 관련 그룹핑)

### Services 디렉토리
- `BabyCare/Services/` 54개 파일
- 신규: `CryAnalysisService.swift` (actor-based)
- 참고 패턴: `ActivityTimerManager`, `FeedingPredictionService` (static enum 패턴)

### FirestoreCollections
- `BabyCare/Utils/Constants.swift:65-87` — 21개 상수
- **추가 필요**: `static let cryRecords = "cryRecords"`
- 경로: `users/{userId}/babies/{babyId}/cryRecords/{recordId}`

### 기존 규약 (CLAUDE.md)
- @MainActor @Observable MVVM
- Swift 6.0, iOS 17+
- 의학 판단 텍스트 금지
- AIGuardrailService.prohibitedRules 수정 금지
- `babyVM.dataUserId()` 필수 (authVM.currentUserId 직접 사용 금지)
- 테스트는 `BabyCareTests.swift` 단일 파일에 append
- 새 패키지/의존성 추가 금지 (SoundAnalysis는 system framework이라 OK)

### 권한 추가 필요
**project.yml `info.properties`**:
```yaml
NSMicrophoneUsageDescription: "아기 울음 분석을 위해 마이크 접근 권한이 필요합니다. 녹음은 기기 내에서만 처리되며 외부로 전송되지 않습니다."
```

**PrivacyInfo.xcprivacy**:
```xml
<key>NSPrivacyCollectedDataTypes</key>
<array>
  <dict>
    <key>NSPrivacyCollectedDataType</key>
    <string>NSPrivacyCollectedDataTypeAudioData</string>
    <key>NSPrivacyCollectedDataTypeLinked</key>
    <false/>
    <key>NSPrivacyCollectedDataTypeTracking</key>
    <false/>
    <key>NSPrivacyCollectedDataTypePurposes</key>
    <array>
      <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
    </array>
  </dict>
</array>
```

### privacy.html 업데이트 필요
- "2. 개인정보의 수집 및 이용 목적"에 울음 분석 항목 추가
- 오디오는 온디바이스에서만 처리, 외부 전송 없음 명시

---

## UX reviewer 주요 권고 (반드시 준수)

### MUST DO
- 녹음 버튼 최소 44pt × 44pt, 한 손 조작 가능
- 면책 배너를 결과 카드 상단에 고정 (caption 텍스트로 숨기지 말 것)
- 최초 사용 시 1회 면책 onboarding
- 결과는 확률 바 차트 형태 (예: 배고픔 52% / 불편 31% / 졸림 17%)
- 결과 언어: "배고픔 신호와 유사해요" (O), "배고픔" (X)
- VoiceOver accessibility announcement (녹음 중/완료 상태)
- 진동 피드백 (UIImpactFeedbackGenerator)

### MUST NOT DO
- 단정적 라벨 ("배고픔", "통증") 단독 표시
- 자동 Activity 기록 생성
- 매 결과마다 전체 화면 alert 면책
- RecordingView HealthType에 케이스 추가 (기록 시트와 혼선)
- PatternReport에 울음 이유 통계 차트 추가
- "가능성이 높습니다" 같은 AI 판단 표현 (AIGuardrailService 금지어)

### 빠른 진입 고려
- Dashboard `quickActionsSection`에 단축 진입 버튼 고려 (Phase 2+)
- 아기를 안고 있을 때 2탭 이내 녹음 시작 가능해야 함

---

## 다음 세션 진행 순서

1. **이 NOTES.md 확인** → 컨텍스트 복원
2. `/specify --autopilot BabyCare 울음 분석 기능 구현 - 이전 세션 NOTES.md 결정 따름` 실행
3. 탐색은 생략 가능 (이미 완료) — `.dev/specs/cry-analysis/NOTES.md` 참조 지시
4. plan-reviewer 통과 후 `/execute`
5. PLAN.md TODO 예상:
   - TODO 1: 권한 추가 (project.yml + PrivacyInfo.xcprivacy)
   - TODO 2: CryRecord 모델 + FirestoreCollections 상수
   - TODO 3: CryAnalysisService (actor, AVAudioEngine + SoundAnalysis stub)
   - TODO 4: CryAnalysisViewModel (@MainActor @Observable)
   - TODO 5: CryAnalysisView (녹음 UI + 면책 배너 + 확률 바 stub)
   - TODO 6: HealthView 섹션 카드 추가
   - TODO 7: privacy.html 업데이트
   - TODO 8: 단위 테스트 (CryRecord 모델, Service actor 인터페이스)
   - TODO Final: make verify

---

## 범위 밖 (차후 세션)

- 실제 `.mlmodel` 훈련 (CreateML + Donate-a-Cry corpus 전처리)
- 통계/패턴 분석 UI
- Dashboard 빠른 진입 단축 버튼
- 자동 Activity 연계 (UX 검증 후 선택적)
- 백그라운드 녹음 (UIBackgroundModes audio)
- 가족 공유 기기 간 온보딩 상태 동기화

---

## 참고 문서 링크 (다음 세션용)

- SoundAnalysis: https://developer.apple.com/documentation/soundanalysis
- MLSoundClassifier: https://developer.apple.com/documentation/createml/mlsoundclassifier
- Donate-a-Cry: https://github.com/gveres/donateacry-corpus
- XcodeGen mlmodel: https://github.com/yonaskolb/XcodeGen/pull/457
- Privacy manifest audio: https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacycollecteddatatypes
- App Store 선례: Cry Analyzer (id1303091708), ChatterBaby (id1347345855)

---

**Session**: 2026-04-10 (handoff)
**Status**: Exploration + analysis complete, awaiting /specify in next session
