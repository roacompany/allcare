# Harness Engineering 초기 구축 (2026-04-14)

## 발견

### SwiftLint 기존 코드 호환
- 엄격한 규칙으로 시작하면 391 warnings + 15 errors 발생
- `comma`(108건), `redundant_string_enum_value`(38건)가 대부분
- **교훈**: 기존 프로젝트에 lint 도입 시 규칙을 완화하고 점진적으로 강화할 것
- disabled: comma, redundant_string_enum_value, implicit_optional_initialization 등

### 아키텍처 위반 baseline 패턴
- arch_test.sh 처음 실행 시 17건 위반 발견
- Views에서 FirestoreService 등 직접 참조가 주요 원인
- **교훈**: baseline 패턴(현재 위반 수 기록, 증가만 차단)이 기존 코드베이스에 효과적
- 신규 위반 추가만 차단 → 점진적 리팩토링 가능

### WHO LMS 변수명 (L, M, S)
- PercentileCalculator의 L, M, S는 의학 표준 변수명
- SwiftLint identifier_name excluded에 추가 필요
- **교훈**: 도메인 특화 변수명은 lint 예외로 관리

### Xcode 26.4 시뮬레이터 런타임
- Xcode 업데이트 후 시뮬레이터 런타임이 자동으로 따라오지 않음
- `xcodebuild -downloadPlatform iOS` 필요 (8.46GB)
- `xcodebuild -runFirstLaunch`도 필요

## 규칙화 (→ .claude/rules/ 반영)

- SwiftLint 도입 시: disabled_rules부터 시작, 점진 강화
- arch_test: baseline 패턴 적용, 새 위반만 차단
- WHO 의학 변수(L, M, S): identifier_name excluded
