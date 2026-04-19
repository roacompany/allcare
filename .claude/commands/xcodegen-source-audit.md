---
description: 새 Swift 파일 추가 후 xcodegen project.yml sources에 양쪽 target 모두 등록됐는지 감사 — main app glob + widget extension 명시 누락 회귀 예방.
---

# xcodegen-source-audit

**트리거**: "xcodegen 추가", "새 파일 project.yml", "sources 누락", 새 Swift 파일 add 후 widget이 import해야 할 때.

**목적**: BabyCare 프로젝트는 `BabyCare/` 글롭으로 main app target 자동 추가, widget extension은 명시적 path 추가가 필요한 구조. 한쪽만 추가하면 "Cannot find 'X' in scope" 빌드 실패.

회귀 history:
- 빌드 56: AddBabyView 진입점 누락 패턴
- 빌드 59: PregnancyDateMath widget 누락 (이번 세션 발견)

## 실행 단계

### 1. 변경된 신규 .swift 파일 목록 추출
```bash
git status --porcelain | grep '^??.*\.swift$' | awk '{print $2}'
git diff --cached --name-only --diff-filter=A | grep '\.swift$'
```

### 2. 각 파일에 대해 3점 체크

**(a) main app glob 포함 확인**:
- 파일이 `BabyCare/` 하위면 자동 포함 ✅
- 그 외 위치면 main app sources에 명시 필요

**(b) Widget extension 필요 여부**:
- 파일이 `WidgetDataStore`/`*Attributes`/pure helper 등 widget 사용 가능성 있음?
- `BabyCareWidget/` 하위 코드가 이 파일을 import할 가능성 grep:
  ```bash
  grep -l "import.*BabyCare\|<파일의 type 이름>" BabyCareWidget/
  ```

**(c) project.yml widget sources에 명시됐는지**:
```bash
grep "<파일경로>" project.yml
```
- BabyCareWidgetExtension 섹션 sources에 path 항목 있어야 함
- 패턴: `      - path: BabyCare/Utils/PregnancyDateMath.swift`

### 3. project.pbxproj 검증
xcodegen generate 후:
```bash
grep -c "<파일이름>" BabyCare.xcodeproj/project.pbxproj
```
- main app만: 4 occurrences (PBXBuildFile + PBXFileReference + group + Sources)
- widget도 추가: 6 occurrences (위 4 + widget 추가 PBXBuildFile + Sources)

FeedingTimerAttributes.swift 패턴 참조 (6 occurrences = 양쪽 target).

### 4. Build smoke
```bash
make build 2>&1 | grep -E "error:.*Cannot find" | head
```
- 결과 0건이어야 통과

## 출력 형식

```
## xcodegen sources audit

### 신규 파일 N개 검사
- BabyCare/Utils/X.swift
  - main app glob: ✅ (BabyCare/ 하위)
  - widget 필요: ✅ (BabyCareWidget/Y.swift에서 import 패턴 발견)
  - project.yml widget sources: ❌ 누락 → 추가 필요:
    ```yaml
        sources:
          ...
          - path: BabyCare/Utils/X.swift
    ```
  - pbxproj occurrences: 4 (widget 미포함)

### 권장 조치
1. project.yml BabyCareWidgetExtension sources에 path 추가
2. xcodegen generate
3. make build 재실행
```

## 참조

- `.dev/specs/done/pregnancy-mode/context/learnings.md` (XcodeGen 파일 공유 섹션)
- 회귀 패턴: 같은 파일을 두 target이 sources로 명시하면 xcodegen이 별도 BuildFile 생성. 한쪽만 명시 시 다른 target은 "Cannot find" 빌드 실패.
