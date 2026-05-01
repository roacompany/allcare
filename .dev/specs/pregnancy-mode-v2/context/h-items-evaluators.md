# H-items 평가자 + Evidence 포맷 정의

**작성일**: 2026-04-23
**작성자**: P0-4 Worker (claude-sonnet-4-6)
**참조**: PLAN.md Verification Summary (H-1 ~ H-12), v2.7.1.md QA evidence 샘플

---

## H-items 평가자 테이블

| H | 영역 | 평가자 | 기준 | Evidence 포맷 | 기한 | 비고 |
|---|------|--------|------|---------------|------|------|
| H-1 | 태동 햅틱 + 2시간+ 장시간 세션 안정성 | QA (팀원 지정) | UIImpactFeedbackGenerator 진동 강도/패턴 주관 적절성 확인; 2시간 세션 중 메모리 경고/크래시 없음; UI 응답성 유지 | 실기기 KickSession 2시간 완료 스크린샷 (타임스탬프 포함) + Xcode Memory Gauge 또는 기기 콘솔 로그 (메모리 경고 0건) | P1 merge 후 TestFlight 배포 시점부터 3일 이내 | XCUITest timeout 제약으로 자동 검증 불가. 실기기 전용 |
| H-2 | 출산 전환 + 축하 애니메이션 | Product + QA | WriteBatch 실 호출 후 Pregnancy.outcomeType = born, Baby 자동 생성 확인; 애니메이션 timing/감정 적절성 팀 컨펌 | TestFlight pregnancy→born 전환 완료 스크린샷 3장 (전환 전/중/후) + Firestore Console WriteBatch 성공 로그 캡처 | P2 merge 후 TestFlight 배포 시점부터 3일 이내 | transitionState=pending → born 원자적 처리 확인 필수 |
| H-3 | DashboardPregnancyHomeCard 시각 품질 (라이트/다크) | 디자이너 | ROA 디자인 토큰 준수 (make design-verify PASS 전제); 라이트/다크 대비비 WCAG AA; 타이포그래피/여백 팀 기준 충족 | `make screenshots` 출력 캡처 — DashboardPregnancyHomeCard 라이트 1장, 다크 1장 + 디자이너 LGTM 서명 | P1 merge 후 TestFlight 배포 시점부터 3일 이내 | design-verify 통과 후에도 실기기 시각 판단 필수 |
| H-4 | pregnancy-weeks.json 37주 의료 검증 | **산부인과 전문의 (외부) — AI 에이전트 불가** | ACOG 및 대한산부인과학회 기준 콘텐츠 정확성; 각 주차 발달 설명의 의학적 사실 여부; 위험 징후 안내 문구 적절성 | 전문의 서명 검토 의견서 (PDF 또는 이메일) + 수정 요청 항목 반영 diff + 출처 URL 명시 문서 | **외부 dependency: 전문의 명단 협의 필요, 예상 2주 (사용자 선제 연락 필수)** | 출시 전 필수 gate. v2.8 타임라인 critical path. AI 자동 생성 콘텐츠이므로 반드시 전문의 검수 |
| H-5 | RemoteConfig off 실기기 (비행기 모드 fallback) | QA | 실 RemoteConfig fetch 성공 → 캐시 만료 → 비행기 모드 전환 시 pregnancyModeEnabled 기본값(false) fallback 동작; 임신 진입점 미노출 확인 | TestFlight 실기기 비행기 모드 설정 스크린샷 + 앱 임신 진입점 미노출 스크린샷 (AddBabyView, Dashboard, Settings 각 1장) | P1 merge 후 TestFlight 배포 시점부터 3일 이내 | feature_flag_smoke.sh는 빌드 자동 검증 한정. 실 네트워크 시나리오는 실기기 필수 |
| H-6 | 위젯 visual 3종 (small/medium/accessoryCircular) × 라이트/다크/잠금화면 | 디자이너 + QA | WidgetKit adaptive color 실기기 렌더링; 각 사이즈별 레이아웃 잘림 없음; 잠금화면 accessoryCircular 텍스트 가독성 | 실기기 홈화면 위젯 스크린샷 6장+ (small 라이트/다크, medium 라이트/다크, accessoryCircular 라이트/잠금화면) | P2 merge 후 TestFlight 배포 시점부터 3일 이내 | 시뮬레이터 위젯 렌더링 불안정 → 실기기 전용 |
| H-7 | HealthKit 임신 데이터 opt-in 실기기 | QA | 권한 요청 시스템 alert 실 노출; 허용 시 HKCategoryTypeIdentifierPregnancy 데이터 기록; 거부 시 앱 정상 동작 (크래시 없음) | 권한 허용 케이스 스크린샷 (alert + 건강앱 데이터 확인) + 거부 케이스 스크린샷 (앱 정상 동작) 각 1장 | P2 merge 후 TestFlight 배포 시점부터 3일 이내 | 시뮬레이터 권한 alert 불안정으로 실기기 전용 |
| H-8 | Accessibility XXXL 전체 진입점 시각 | 디자이너 | ViewThatFits 분기 후 Dynamic Type XXXL에서 모든 임신 진입점 가시성; 텍스트 잘림/오버플로 없음; 탭 타겟 최소 44pt | 시뮬레이터 Dynamic Type XXXL 스크린샷 — AddBabyView, DashboardPregnancyHomeCard, HealthPregnancyView 각 1장 | P1 merge 후 TestFlight 배포 시점부터 3일 이내 | 빌드 61에서 fix 완료됐으나 v2 재설계 후 재검증 필수 |
| H-9 | transitionState=pending Recovery UI 실 orphan | QA + Engineer | Firebase Console에서 실 계정 transitionState=pending 주입 후 앱 재시작 시 Resume UI 자연 노출; 복구 플로우 완주 후 transitionState 정상화 | Firebase Console 실 계정 document 편집 스크린샷 + Resume UI 노출 스크린샷 + 복구 완료 후 Firestore 상태 스크린샷 | P3+P4 merge 후 TestFlight 배포 시점부터 3일 이내 | 빌드 56-61 기간 실 orphan 문서 보유 계정 사용 권장 (P0-3 pending-spec 분석 결과 반영) |
| H-10 | Privacy Policy 건강 데이터 항목 법적 검토 | **법무 (외부) — AI 에이전트 불가** | 개인정보보호법 제24조(민감정보) 준수; App Store 심사 가이드라인 5.1.1 건강/의료 정보 처리 규정 준수; privacy.html HealthKit/임신 데이터 수집·이용·보관 항목 명시 완결성 | 갱신된 privacy.html 리뷰 + 법무 검토 의견서 (법무팀 이메일 또는 서명 문서) | **외부 dependency: 법무 담당자 연락, 예상 1주 (사용자 선제 연락 필수)** | App Store 심사 거절 리스크 — 출시 전 필수 gate. 법무 의견서 수령 전 배포 금지 |
| H-11 | Partner visibility 실 배포 검증 | QA + Engineer | firestore.rules collectionGroup Partner 규칙이 실제 배포 환경에서 partner에게 owner pregnancy read 허용하는지 확인; sharedWith 배열에 파트너 uid 포함 시 pregnancy document 정상 조회 | Firebase Rules Simulator 3 시나리오 결과 스크린샷 (owner 조회/partner 조회/비인가 거부) + 실 계정 sharedWith 파트너 앱에서 owner pregnancy 표시 스크린샷 | P3+P4 merge 후 TestFlight 배포 시점부터 3일 이내 | P0-5 rules 배포 완료 후 검증 가능 |
| H-12 | RemoteConfig Hybrid 심사 safe 제출 | Engineer | FeatureFlags.pregnancyModeEnabled = true 빌드 제출 + Firebase Console pregnancyRolloutPct = 0 유지 상태에서 App Store 심사 통과; 2.5.2(기능 숨김) 위반 없음 | App Store Connect 심사 결과 화면 스크린샷 + Firebase Console rollout 0% 유지 로그 (심사 기간 스냅샷) | App Store 제출 후 심사 결과 수령 시점 | 심사 중 rollout 0% 절대 유지 필요. Engineer 상시 모니터링 |

---

## 외부 Dependency 상세

### H-4: 산부인과 전문의 의료 검증

| 항목 | 내용 |
|------|------|
| 담당 | 산부인과 전문의 (외부, 사용자가 명단 협의) |
| 검토 대상 | `BabyCare/Resources/pregnancy-weeks.json` — 4~40주 37개 항목 |
| 예상 일정 | **전문의 명단 확정 + 2주** (사용자 선제 연락 필수) |
| Blocker | 전문의 연락처 미확보 시 v2.8 출시 불가 |
| 후속 액션 | 수정 요청 항목 반영 후 scripts/pregnancy_weeks_sanity.py 재실행 + 전문의 재확인 |
| 담당자 할당 금지 | AI 에이전트 검토 결과는 sanity check 전용 (의학적 정확성 보증 불가) |

### H-10: Privacy Policy 법적 검토

| 항목 | 내용 |
|------|------|
| 담당 | 법무 담당자 (외부, 사용자가 연락) |
| 검토 대상 | `/Users/roque/allcare/privacy.html` — HealthKit 임신 데이터, 건강 데이터 수집·이용·보관 항목 |
| 예상 일정 | **법무 연락 + 1주** (사용자 선제 연락 필수) |
| Blocker | 법무 의견서 미수령 시 배포 금지 (App Store 심사 5.1.1 거절 리스크) |
| 후속 액션 | 의견서 반영 후 allcare repo push → GitHub Pages 배포 |
| 담당자 할당 금지 | AI 에이전트는 초안 작성 보조만 가능. 법적 판단은 반드시 법무 인간 검토 |

---

## TestFlight "3일 무회귀" Metric 구체화

TestFlight 내부 배포 후 3일간 다음 기준을 모두 충족해야 다음 Phase merge 허가:

| Metric | 기준 | 측정 방법 |
|--------|------|----------|
| Crashlytics crash-free rate | **>= 99%** | Firebase Console → Crashlytics → 임신 관련 사용자 세션 crash-free rate |
| 임신 관련 crash 건수 | **0건** | Crashlytics 이슈 목록 — `PregnancyViewModel`, `KickSession`, `PregnancyWidgetDataStore`, `HealthKitPregnancyService` 관련 crash 0 |
| 내부 테스터 최소 규모 | **N명 (사용자 결정)** — 권장 최소 3명 | Firebase Console → App Distribution 또는 TestFlight 설치 확인 |
| 임신 핵심 플로우 완주 | 테스터 1명 이상이 등록→태동기록→위젯확인 전 플로우 완주 | QA 체크리스트 self-report |

> 테스터 규모 N은 사용자가 결정하며, 이 문서는 최소 3명을 권장한다. TestFlight DAU 정확도는 내부 테스터 규모에 비례한다.

---

## plan-reviewer + codex SHIP Input 범위

| 단계 | 트리거 | 실행 내용 |
|------|--------|----------|
| **PR 분할 1 (P1)** | P1 작업 완료 + PR open 시 | `hoyeon:code-reviewer` (Gemini + Codex + Claude 교차) + `/review` diff 검토. SHIP 판정 필요 |
| **PR 분할 2 (P2)** | P2 작업 완료 + PR open 시 | 동일. 특히 WriteBatch/Firestore 스키마 변경 집중 검토 |
| **PR 분할 3 (P3+P4)** | P3+P4 작업 완료 + PR open 시 | 동일. firestore.rules collectionGroup + transitionState Recovery UI 집중 검토 |
| **최종 merge 전** | 전 PR merge 완료 후 v2.8 브랜치 최종 | 풀 diff 기준 `hoyeon:code-reviewer` 1회 추가 실행. SHIP 판정 후 merge 허가 |

> plan-reviewer는 각 PR의 PLAN.md TODO 체크 1:1 대조 수행. codex SHIP은 diff 기반 코드 품질 SHIP/NEEDS_FIXES 판정.

---

## 참조

- PLAN.md Verification Summary: H-1 ~ H-12 (lines 185-198)
- QA Evidence 포맷 샘플: `.dev/qa-evidence/v2.7.1.md`
- External Dependencies Strategy: PLAN.md lines 215-249
- Verification Gaps: PLAN.md lines 204-211
