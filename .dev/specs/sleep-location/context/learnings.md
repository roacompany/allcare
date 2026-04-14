# Learnings

## TODO 1
- ActivityEnums.swift의 SleepMethodType은 `extension Activity` 내부 중첩 선언
- Swift enum String rawValue는 case 이름과 동일 — case 선언 순서만 바꾸면 rawValue 유지됨
- SourceKit "Cannot find type 'Activity'" 경고는 IDE 인덱싱 false positive, `make build` 통과 확인됨 (프로젝트 known issue)

