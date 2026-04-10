
## Code Review — 프로덕션 런칭 전 처리

- [ ] **CR-001**: #error로 Release 빌드 차단 상태. AdMob 계정 등록 후 `#else` 블록에서 `#error` 제거 + 실제 production Banner Unit ID로 교체
- [ ] **CR-003**: 작은 화면(iPhone SE)에서 FloatingTimerBanner + FloatingMiniPlayer + AdBanner 3개 동시 활성 시 총 ~200pt 높이 → 실기기 확인 필요. 필요 시 VStack에 maxHeight 제약 추가
- [ ] **CR-005**: SKAdNetworkItems 현재 9개 (Google 권장 89+). Google 공식 문서(https://developers.google.com/admob/ios/quick-start#update_your_infoplist)에서 최신 리스트 복사하여 project.yml에 반영 (광고 attribution 완전성 위해). TestFlight에는 9개로도 동작, App Store 런칭 전 확장 권장
