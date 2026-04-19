# QA Evidence — v{VERSION} 빌드 {BUILD}

**검증 일자**: YYYY-MM-DD
**검증자**: {이름}
**기기**: iPhone / iPad 모델
**iOS 버전**: iOS X.Y

## 3-Agent QA 결과

### 1. Visual / UX
- [ ] 디자인 토큰 일관성 (AppColors, SF Symbols)
- [ ] 라이트/다크 모드 전환 시 깨짐 없음
- [ ] iPhone SE / 기본 / Pro Max 레이아웃 확인
- [ ] 한국어 텍스트 폭 적정 (줄바꿈/생략 자연스러움)

### 2. Code Quality
- [ ] `make verify` ALL CHECKS PASSED
- [ ] 신규 코드 arch-test 위반 없음
- [ ] 주요 변경점 코드 리뷰 완료

### 3. Mobile Responsive
- [ ] 회전 대응 (iPad)
- [ ] 키보드 입력 시 레이아웃 가림 없음
- [ ] Safe area / 홈 인디케이터 침범 없음

## 신규 기능 시나리오 검증

- [ ] {기능 A} 주요 플로우 end-to-end
- [ ] {기능 B} edge case (네트워크 단절, 권한 거부 등)

## 버그 발견 시 Fix 커밋

- {commit SHA}: {설명}

## 결과

**PASS** / FAIL

(deploy gate는 'PASS' 문자열 존재로 판단 — FAIL 시 이 줄을 FAIL로 변경하면 차단됨)
