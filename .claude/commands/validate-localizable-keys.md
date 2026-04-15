---
description: Localizable.strings 키 누락/고아 키 검증 — BadgeCatalog.titleKey / NSLocalizedString 크로스 체크
---

# /validate-localizable-keys

목적: Swift 코드에서 참조되는 localizable 키가 실제 `Localizable.strings`에 존재하는지, 그리고 `.strings`에 있는 키가 실제로 쓰이는지 양방향 검증.

## Behavior

실행 순서:
1. **Swift 키 수집**:
   - `Grep "NSLocalizedString\(\"([^\"]+)\""` — 모든 NSLocalizedString 리터럴 키
   - `Grep "LocalizedStringKey\(\"([^\"]+)\""` — SwiftUI LocalizedStringKey 리터럴
   - `Grep "titleKey:\s*\"([^\"]+)\"|descriptionKey:\s*\"([^\"]+)\""` — BadgeCatalog 등 구조화된 키
2. **Localizable.strings 파싱**:
   - `Read BabyCare/ko.lproj/Localizable.strings`
   - 형식: `"key_name" = "value";` 추출
3. **Cross-check**:
   - **Missing**: Swift에서 참조되지만 .strings에 없음 → ❌ 반드시 추가 필요
   - **Orphan**: .strings에 있지만 Swift에서 참조 없음 → ⚠️ 확인 후 제거 고려
4. **결과 출력**:
   ```
   ✅ 참조 키 {N}개, 정의 키 {M}개
   ❌ 누락 {X}개:
     - badge.firstRecord (Badge.swift:32 참조, .strings 부재)
   ⚠️ 고아 {Y}개:
     - old.removed_key (.strings 정의, 참조 없음)
   ```
5. **선택적 수정 제안**: 누락이 있으면 추가할 항목을 edit 후보로 제안

## 주의
- 동적 키 (e.g. `"badge.\(id)"`)는 정적 grep으로 못 잡음 — 결과에 "동적 키는 런타임 테스트로 별도 검증 필요" 경고 출력
- 다국어 locale 확장 시 각 locale .strings 파일 모두 순회 필요 (현재는 ko만)

## 관련 테스트
BabyCareTests의 `testBadgeCatalog_localizableKeys_allPresent`는 이 커맨드의 런타임 버전. 커맨드는 **커밋 전** 빠른 피드백, 테스트는 **CI 안전망**.
