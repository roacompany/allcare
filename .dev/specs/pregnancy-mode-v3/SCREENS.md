# 임신모드 v3 — 화면별 명세 ("임신 노트")

작성 2026-06-11 · IA.md("임신 노트") 주요 10화면 상세. 순수 UX/구성(코드·데이터모델 제외). 10영역 병렬 상세화 종합.

## PregnancyNoteRootView — "임신 노트" 4탭 셸 (보라/라일락 액센트). IA.md 화면 인벤토리 #1 (신규). 임신모드 v3 독립 공간의 컨테이너 루트. 진입 = both는 육아홈 PortalCard 탭 → fullScreenCover로 이 화면 / pregnancyOnly는 이 화면이 앱 루트(fullScreenCover 아님, NavigationStack 루트). 내부 4탭(여정/기록/검진/더보기) 각각 독립 NavigationStack을 품는 보라 액센트 TabView. 상단 "공간칩"([← 육아로] + "🤰 임신N주")은 both에서만 노출, pregnancyOnly는 숨김(나갈 곳 없음).

**한 줄**: 육아 핑크 공간과 시각적으로 단절된 보라/라일락 "임신 노트" 4탭 셸 — 한 번에 한 공간만 보이고, both는 좌상단 칩으로 0.5초 만에 어느 공간인지 인지하며 닫기 1번이면 정확히 떠났던 육아 홈으로 돌아온다.

**레이아웃**
위→아래 z축/구조 순서:

(0) 공간 배경 — 화면 전체가 보라/라일락 정체성을 입는다. surfacePrimary 위에 아주 옅은 라일락 워시(tintPurple 8~10% 그라데이션 톱→투명)로 "여기는 육아(핑크)가 아니다"를 비언어적으로 신호. 다크모드는 동일 hue의 저채도 보라.

(1) [both 전용] 상단 공간칩 — 안전영역 상단, 첫 탭의 NavigationStack 타이틀바 위 또는 좌측 leading에 고정. 좌측 = [← 육아로] 칩(chevron.backward + "육아로" 라벨, 캡슐, tintPurple 배경/보라 전경). 우측(또는 칩 내부 trailing) = "🤰 임신 24주" 컨텍스트 라벨(figure.and.child.holdinghands + "임신 N주" + D-day 보조). pregnancyOnly에서는 이 칩 전체가 렌더되지 않음(빈 leading) — 가역 종료 동선이 없으므로.

(2) 탭 콘텐츠 영역 — 선택된 탭의 독립 NavigationStack이 전체 폭을 채움. 4개 스택은 각자 스크롤 위치/푸시 깊이/선택 상태를 독립 보존.

(3) 하단 탭바 — 보라 틴트 TabView. 4탭:
  ① 여정 — "point.topleft.down.curvedto.point.bottomright.up" 또는 "timeline.selection"; 라벨 "여정". 선택 시 채워진 변형.
  ② 기록 — "square.and.pencil"; 라벨 "기록".
  ③ 검진 — "stethoscope"(기존 DashboardPregnancyView nextVisitCard와 동일 심볼 계승); 라벨 "검진".
  ④ 더보기 — "ellipsis.circle"; 라벨 "더보기".
탭바 selectedColor = 보라 액센트, unselected = secondary. 4개는 위계상 매일(①②) 좌측, 가끔/1회성(③④) 우측 배치로 자연스러운 사용빈도 좌→우 감소.

셸 자체는 자식 탭의 sticky 헤더/카드를 직접 그리지 않는다 — 레이아웃 책임은 각 탭 루트 View(PregnancyJourneyView 등)에 위임. 셸의 레이아웃 = 배경 정체성 + (조건부)공간칩 + TabView 4슬롯.

**컴포넌트**
신규(이 셸 전용):
- PregnancyNoteRootView (TabView 컨테이너, @State selectedTab) — body root에 단일 TabView, 각 탭 item에 자식 View를 NavigationStack로 감싸 배치.
- PregnancySpaceChip (공간칩) — [← 육아로] 가역 종료 + "🤰 임신N주" 컨텍스트. both에서만 인스턴스화. 닫기 액션은 부모(fullScreenCover dismiss)로 클로저 전달.
- 4 탭 루트(이 화면이 호스팅, 별도 명세 대상): PregnancyJourneyView(① · DashboardPregnancyView 승격) / PregnancyTrackingHubView(②) / PrenatalCareView(③) / PregnancyMoreView(④).

탭바 정체성 토큰:
- 액센트 = 보라/라일락. 현재 자산에 임신 전용 accent 토큰 부재 → DS2.Color.tintPurple(pastelPurple #D9B5FF, 배경/칩용) + DS2.Color.pumping(#B56FD1, 전경/선택 틴트용)을 잠정 사용하되, 구현 시 DS2.Color.pregnancy 전용 토큰 신설 권장(육아 #FF9FB5와 1:1 대응되는 단일 진실 출처). 자체 hex 직접 사용 금지(AppColors/DS2 경유).
- 공간 아이콘 = figure.and.child.holdinghands (ContentView 온보딩 "임신 중이에요" 버튼·AddBabyView와 이미 동일 심볼 사용 → 일관).

재사용 셸 프리미티브(DS2Components):
- DS2Card / DS2Section / DS2ListRow / DS2EmptyState / DS2Button — 자식 탭이 카드/섹션/행/CTA에 사용(셸은 직접 안 그림). 공간칩도 DS2Button(.secondary) 변형 또는 캡슐 커스텀.
- DS2.Spacing(8pt grid) / DS2.Radius / DS2.Font / ds2Shadow.

주입(environment): PregnancyViewModel, AuthViewModel, BabyViewModel/AppState를 부모에서 그대로 상속(@Environment). 셸은 자체 ViewModel 없음 — 신규 전역 상태 0(IA 핵심결정: activeSpace 폐기).

**상태**
셸 레벨 상태(최소):
- selectedTab: 0~3 — 마지막 선택 탭. fullScreenCover라 dismiss 후 재진입 시 보존(부모 보유 권장 → cover 재생성에도 마지막 탭 유지). 기본값 = ① 여정.
- 진입 컨텍스트: both vs pregnancyOnly — AppContext(또는 v3의 케어 프로필 리스트)에서 파생, 공간칩 노출 여부만 결정. 셸 내부에 모드 토글 상태머신 없음.

데이터 파생 상태(자식이 소비, 셸은 칩 라벨에만 사용):
- 주차/D-day 표시: pregnancyVM.currentWeekAndDay / dDay. 미설정(예정일 없음)이면 칩 "🤰 임신중"(주차 생략) + D-day 숨김.
- 다태아: 칩은 단태 기준 라벨 유지, 경고는 자식 탭(①)이 multiFetusDisclaimer로 처리.

생애주기 종속 상태(봉인 — DESIGN.md §2.3·IA 손실분기):
- outcome=ongoing: 정상 보라 공간, 4탭 전부 활성.
- outcome=born(출산 봉인): 정상 흐름에선 이 셸이 더 이상 진입되지 않음(PortalCard 소멸/AppContext 재해석). 잔존 진입 시 ①이 "임신 여정 다시보기"(읽기전용 아카이브)로 강등.
- outcome ∈ {miscarriage/stillbirth/terminated}(손실 봉인): "조용한 모드" — 셸 액센트가 보라/축하 톤 → 차분한 중립 톤으로 리스킨, 주차 freeze(칩 주차 진행 정지), QuickLog/검진/진통/스탬프 등 '진행' UI 숨김(자식 탭 책임), 데이터는 100% 보존(조용한 열람만).

a11y 상태: Dynamic Type 확대 시 공간칩 라벨은 ViewThatFits로 "육아로"→아이콘만 축소(AccessibilityXXXL truncate 방지, AddBabyView H-8 선례). VoiceOver: 칩 = "육아 공간으로 돌아가기, 버튼" / 컨텍스트 = "현재 임신 24주, D-112" 읽기. 탭바 = 표준 SwiftUI 탭 a11y.

**상호작용**
- 공간칩 [← 육아로] 탭 → fullScreenCover dismiss(both 한정) → 떠났던 육아 홈에 상태 그대로 착지(스크롤·선택탭 자동 보존, 신규 상태 저장 불필요). 단일 가역 제스처 = 학습비용 0.
- 공간칩 "🤰 임신N주" 영역 탭(선택) → ① 여정 탭으로 점프 + 헤더 스크롤 톱(컨텍스트 라벨을 "지금 어디" 인디케이터 겸 ① 바로가기로).
- 탭바 탭 전환 → 해당 탭의 독립 NavigationStack 표시, 각 스택 푸시 깊이/스크롤 유지. 같은 탭 재탭 → 해당 스택 루트로 pop + 톱 스크롤(표준 패턴).
- pregnancyOnly: 좌상단 칩/닫기 일절 없음 → 사용자는 임신 노트를 떠날 수 없고(앱 루트라 정상), 시스템 스와이프-다운 dismiss도 비활성(fullScreenCover 아님).
- 자식 탭 ② QuickLog/기록 저장 → ① 여정 해당 주차 카드로 자동 역류(셸은 탭 간 데이터 전달 매개 안 함, 공유 ViewModel/Firestore 리스너로 반영).
- 딥링크(위젯 PregnancyDDayWidget / 푸시 "[둘째 임신] 검진 D-2") 진입 → 셸 곧장 열고 selectedTab을 타겟 탭(③ 검진 등)으로 세팅 + 해당 카드까지 도달.
- 출산 CTA / 손실 정리는 셸이 직접 트리거하지 않음 — ①막달 birthCTABanner(기존 재사용) / ④설정 "임신 정보 정리"가 각각 PregnancyTransitionSheet·PregnancyTerminationView를 sheet로 제시.

**전이**
- 진입(both): 육아홈 PregnancyPortalCard 탭 → .fullScreenCover(보라 공간이 아래→위로 슬라이드 커버). 커버 등장과 함께 라일락 배경 워시 페이드인 → "다른 공간 진입" 명확.
- 진입(pregnancyOnly): 앱 콜드스타트/AppContext resolve 시 이 화면이 NavigationStack 루트로 즉시 표시(모달 전이 없음).
- 종료(both): [← 육아로] → cover dismiss(위→아래) → 육아 핑크 홈 복원. 보라→핑크 전환이 "공간 이동"을 색으로 확증.
- 탭 전환: 표준 TabView 크로스페이드(커스텀 cross-dissolve 금지 — 안1 다경로 전환마찰 회피).
- 출산 전환 완료: PregnancyTransitionSheet WriteBatch(atomic) 성공 → outcome=born → fullScreenCover dismiss → 육아 모드 자동 착지 + 출산축하 + "임신 여정 다시보기" 링크. 셸은 재진입되지 않도록 AppContext/프로필 리스트 재해석에 위임.
- 손실 전환: PregnancyTerminationView 확정 → 즉시 셸 리스킨(보라→중립 톤, 주차 freeze) → both였으면 조용히 육아 복귀(둘째 상실이 첫째 육아 화면 침범 금지) / pregnancyOnly였으면 임신 공간 조용히 종료. 축하 톤/애니메이션 0.
- 크래시 복구: transitionState/birthEvent pending orphan → 다음 진입 시 PregnancyRecoveryModal 재개(기존 자산).

**한국 디테일**
- 칩/헤더 표기 = NN주N일 + D-day 한국 관례("임신 24주", "D-112"). 예정일 미설정 시 주차 생략하고 "임신중"만(DashboardPregnancyView dDay==nil 분기 계승).
- D-day 0/경과: "오늘이 출산 예정일이에요!" / "예정일 경과 +N일"(기존 dDayCard 카피 그대로 ①에서 재사용).
- 한국 산전검진 일정이 ③검진 탭의 1급 시민(셸은 ③로 라우팅): 11~13주 NT/1차 기형아, 15~20주 정밀초음파, 24~28주 임신성당뇨 자동 주차매핑. 국민행복카드 바우처 잔액·안내 + 산모수첩 디지털 미러(커머스 0, 정보카드만).
- 막달(37주+) 진통 타이머(5-1-1)·2시간 10회 태동은 ①/②에서 동적 승격, 셸은 해당 탭 도달만 보장.
- 태아 크기 비유(양귀비씨→복숭아→수박, pregnancy-weeks.json 37주)·태교·만삭사진은 ①/④ 콘텐츠로 셸이 호스팅.
- 알림 출처 prefix "[둘째 임신] 24주 검진 D-2": 푸시 탭 시 이 셸을 열고 해당 탭으로 직행(공간 라벨링으로 첫째 육아 알림과 혼동 차단).
- 광고 0 / 커머스 0 = 구조적 강점(셸 어디에도 광고 슬롯/구매 CTA 없음).
- 의료 면책: 셸은 직접 면책 배너를 안 그리지만 ①진입 시 disclaimerBanner(기존)·다태 multiFetusDisclaimer가 노출되도록 ① 라우팅 보장.

**재사용 자산**
기존 그대로(코드 변경 없이 셸이 호스팅/라우팅):
- DashboardPregnancyView → ① 여정 탭으로 승격(dDayCard/weekProgressCard/checklistPreviewCard/nextVisitCard/birthCTABanner/disclaimerBanner/multiFetusDisclaimer 전부 계승). ⚠ 단 이 View는 body root에 NavigationStack 없음(push-only로 이미 PR #9에서 해소) → 셸의 탭 NavigationStack 안에 그대로 배치 가능. 중첩 NavigationStack 금지 규칙 준수.
- PregnancyRecordingSheets(KickRecordingSheet/PregnancyWeightEntrySheet) → ② 기록 탭의 QuickLog 시트.
- PregnancyTransitionSheet / PregnancyRecoveryModal / PregnancyTerminationView → 출산·복구·손실(셸이 sheet로 제시, 위치만 다름).
- PregnancyDDayWidget / PregnancyWidgetDataStore → 딥링크 진입 소스.
- KickSession / PregnancyChecklistItem / pregnancy-weeks.json(37주) → 자식 탭 데이터.
- PregnancyViewModel(currentWeekAndDay/dDay/activePregnancy/checklistItems/prenatalVisits) → 칩 라벨 + 자식 공유.
- AppContext 4-state(현 v2) — 셸은 both/pregnancyOnly 판별에만 사용. (v3 DESIGN.md는 AppContext 폐기→케어 프로필 리스트 전환 예정이나, 이 셸 명세는 진입 컨텍스트만 소비하므로 어느 모델이든 호환.)

신규 필요:
- PregnancyNoteRootView(셸) / PregnancySpaceChip / DS2.Color.pregnancy 전용 보라 토큰(권장) / PregnancyPortalCard(both 진입문, DashboardPregnancyHomeCard 격상).
- DS2Components(DS2Card/Section/ListRow/EmptyState/Button) — 기존, 자식 탭이 사용.

**엣지**
- both에서 활성 임신이 갑자기 종료(다른 기기에서 파트너가 출산/손실 확정, 실시간 리스너 반영) → 셸이 열려있는 상태에서 outcome 변경 감지 시: born이면 부드럽게 dismiss + 육아 착지, 손실이면 즉시 조용한 톤 리스킨(보라/진행 UI 사라짐) — 열린 채 모순된 보라 축하 공간 유지 금지.
- 예정일 미설정(dDay=nil): 칩은 "🤰 임신중"(주차/D-day 숨김), ①은 dDayCard "예정일 미설정" 안내 분기 노출. 칩이 빈 "임신 주"로 깨지지 않게 옵셔널 가드.
- pregnancyOnly인데 공간칩/닫기 노출되면 = orphan 회귀(빌드56 유형) → AppContext×진입점 매트릭스 XCUITest 전수 고정 필수. both↔pregnancyOnly 판별 단일 소스.
- fullScreenCover 위 4탭 각자 NavigationStack에서 push 후 toolbar 결합 → PR #9 latent crash 핫스팟. 자식 push View는 body root NavigationStack 금지(셸 탭 스택만 사용), toolbar 전수 QA.
- selectedTab 휘발: cover dismiss→재진입 시 마지막 탭 유실되면 컨텍스트 깨짐 → selectedTab을 부모(cover 호출측)가 보유해 보존.
- 딥링크 도착 시 활성 임신 부재(이미 출산/손실) → 셸 진입 대신 적절한 폴백(육아 홈 또는 아카이브 "지난 임신")로 라우팅, 빈 보라 셸 표시 금지.
- 다태아: 칩/주차는 단태 기준, 자식 ①이 "단태아 기준 정보입니다. 다태임신은 담당 의료진과 상의" 경고 노출 보장.
- 다크모드/Reduce Transparency: 라일락 배경 워시가 .regularMaterial/투명 의존 시 Reduce Transparency에서 불투명 폴백 필요(LoginView a11y 선례 `b53b87a`). 보라 hue는 다크에서 저채도로.
- Dynamic Type AccessibilityXXXL: 공간칩 라벨 truncate → ViewThatFits 축소(H-8 선례).
- 손실 후 새 임신: 셸은 자동 권유 0(출구 존중) — 사용자 자발 등록 시에만 새 ongoing 셸 진입.

---

## ①여정 — PregnancyJourneyView (임신 노트 4탭 중 첫 탭, 앱의 척추)

**한 줄**: "오늘 내 임신이 어디쯤인지" 한 화면에서 즉시 파악하고, 위로 올리면 지나온 주차의 기억이 아래로 내리면 다가올 주차의 준비가 끊김 없이 이어지는 보라/라일락 톤의 주차 타임라인 척추 화면.

**레이아웃**
세로 스크롤 1개(LazyVStack, 주차 단위 lazy 페이징). 위→아래 섹션 순서:

1) sticky 상단 헤더(스크롤해도 상단 고정, 압축형):
   - 좌측: "임신 N주 M일" (한국식 NN주N일 표기)
   - 우측: "D-NN" (출산까지) / "오늘이 예정일이에요" / "+N일 경과" 3분기
   - 하단 한 줄: 40주 진행바(가는 라인, 보라 채움) — 헤더가 접히기 전 풀 카드, 스크롤로 접히면 진행바만 얇게 잔류
   - both 모드일 때만: 헤더 최상단에 공간칩 행([← 육아로] + "🤰임신N주") — 임신 노트 진입 시 4탭 공통으로 노출되는 칩이며 여정 탭에서도 sticky 헤더 위에 얹힘

2) "오늘" 섹션(현재 주차 앵커, 화면 진입 시 기본 스크롤 위치 = 여기. 첫 화면은 항상 가볍게):
   a. 데일리팁 카드 — 그 날 1개(주차 tip 텍스트 + 전구 아이콘, 라일락 배경 8% 틴트). 가볍게 1줄~2줄
   b. 아기 크기 비교 카드 — "N주차: OO 크기" (과일/사물 비유 + 잎 아이콘). 1탭 → 주차 상세 드릴다운
   c. QuickLogStrip — 가로 1줄 칩 3개(태동 / 증상 / 체중), 각 1탭 시 하단 시트(.sheet) 즉시 오픈. 빠른 기록 전용, 깊은 화면 아님
   d. 동적 승격 카드(조건부, 0~2개만 노출. 우선순위 정렬): 검진 D-2 이내 임박 / 37주+ 진통 타이머 / (둘 다 없으면 미노출)
   e. 미완 체크리스트 상위 3 카드 — 미완 항목 최대 3개 미리보기 + "전체보기"

3) 위로 스크롤(과거): 지난 주차 카드들 — 한 주차 = 1개 응집 카드(그 주에 남긴 기록·초음파 사진·일기를 한 묶음으로). 최신(직전 주) → 더 과거 순. 데이터 없는 주차는 옅은 "기록 없음" 플레이스홀더로 축약

4) 아래로 스크롤(미래): 다가올 주차 콘텐츠 카드(주차별 milestone/팁 프리뷰) + 예정 검진 마일스톤(11~13주 NT, 15~20주 정밀초음파, 24~28주 임당 등 한국 산전검진 일정이 해당 주차에 핀으로 표시). 40주까지

5) 최하단: 의료 면책 배너(고정 톤, "일반 참고 자료이며 의학적 진단을 대체하지 않습니다")

**컴포넌트**
- StickyJourneyHeader: 주차/일·D-day·40주 ProgressView(보라 tint). 압축 시 진행바만 잔류
- SpaceChipRow(both 전용): [← 육아로] 칩 + "🤰임신N주" 칩
- DailyTipCard: SF Symbol(lightbulb.fill) + 1~2줄 팁, 라일락 8% 배경
- BabySizeCompareCard: leaf.fill + "OO 크기" + 주차 라벨, 탭 가능(chevron)
- QuickLogStrip: 3 QuickLogChip(태동=figure.walk/heart 계열, 증상=note.text, 체중=scalemass) — ViewThatFits로 a11y XXXL 시 2줄 폴백
- PromotedCard(동적): 검진 임박(stethoscope, 인디고 캡슐 D-N) / 진통 타이머(timer, 보라, 37주+) — 같은 카드 셸 재사용
- ChecklistPreviewCard: checklist 아이콘 + 미완 3행(circle) + "전체보기"
- PastWeekCard: 주차 헤더 + 그 주 기록 썸네일 그리드(초음파/일기/측정 응집), 빈 주는 EmptyWeekPlaceholder
- UpcomingWeekCard: milestone + 팁 프리뷰 + 해당 주차 검진 핀(VisitMilestonePin)
- VisitMilestonePin: 한국 산전검진(NT/정밀초음파/임당/국민행복카드 바우처 안내)
- MedicalDisclaimerBanner: info.circle.fill, 주황 틴트(기존 패턴 유지)
- MultiFetusDisclaimer(다태아 시): 보라 틴트 "단태아 기준 정보"
색상: 임신=보라/라일락 액센트(육아 핑크 #FF9FB5와 시각 분리), SF Symbols 100%, 진행/추이 차트는 Apple Charts

**상태**
- 로딩: sticky 헤더 자리 + "오늘" 섹션 스켈레톤(주차/D-day/팁 placeholder). 과거/미래 주차 카드는 lazy 로드되므로 스크롤 도달 시 개별 스켈레톤
- 예정일 미설정: D-day 영역 = "예정일 미설정 · 임신 정보에서 설정" CTA(calendar.badge.exclamationmark, 보라 0.5 투명). 진행바는 주차 추정 가능 시 표시, 불가 시 0
- 빈 주차(과거 데이터 없음): EmptyWeekPlaceholder("이 주차엔 기록이 없어요" + 옅은 톤), 카드 높이 최소화
- 동적 승격 카드 없음(평시): "오늘" 섹션은 데일리팁+크기비교+QuickLog+체크리스트만 → 가볍게 유지
- 진통 타이머 활성(37주+): 진행 중이면 승격 카드가 라이브 상태(경과/간격 표시) 우선 정렬 최상단
- 다태임신: 크기비교/주차 정보 위에 다태아 면책(보라) 노출, 단태 기준 명시
- 예정일 경과(+N): 출산 CTA 톤 강조(출산했어요 진입 유도는 ④/전환 흐름 자산으로 연결)
- 오프라인: 캐시 기반 렌더(기존 200MB 영속 캐시), 새 기록은 오프라인 큐로 적재 후 자동 sync. 헤더에 동기화 보류 표시 없이 조용히 처리

**상호작용**
- 화면 진입: 스크롤 위치 = "오늘" 앵커(현재 주차)에 자동 정렬. 첫 페인트는 헤더+오늘 섹션만(가볍게)
- 위 스와이프: 지난 주차 카드 lazy 페이징 로드(한 번에 약 1~2주차 단위)
- 아래 스와이프: 다가올 주차 + 검진 마일스톤 lazy 로드
- QuickLogChip 1탭: 해당 .sheet 즉시 표시(태동/증상/체중). 시트 저장 시 닫히고 "오늘" 섹션·해당 주차 카드 즉시 갱신
- 태동 칩 → 태동 시트: 세션 시작/카운트(+1 탭마다 햅틱), 목표 10회(ACOG), 2시간 경과 시 안내. 긴 세션 안정성 고려
- 아기 크기 비교 카드 1탭: 해당 주차 상세(드릴다운) — 여정은 항상 가볍게, 깊이는 드릴다운으로
- 체크리스트 "전체보기" 탭: ④ 더보기 도구함 또는 체크리스트 화면으로 이동(여정에서는 미완 상위 3만)
- 검진 임박 승격 카드 탭: ③ 검진 탭(해당 방문)으로 이동
- 진통 타이머 카드 탭: 진통 타이머 화면(5-1-1 규칙 안내)
- 데일리팁/면책 배너: 비인터랙티브(읽기 전용)
- both 공간칩 [← 육아로] 탭: 임신 노트 fullScreenCover 닫고 육아 홈 복귀(닫기 1번)
- Pull-to-refresh: 현재 주차·검진·체크리스트 최신화

**전이**
- 진입(both): 육아 홈 최상단 PortalCard 탭 → fullScreenCover로 임신 노트 → 여정 탭 활성. 닫기 1번 = 육아 복귀
- 진입(pregnancyOnly): 임신 노트가 앱 루트, 여정 탭이 기본 탭
- 탭바: 여정 ↔ 기록 ↔ 검진 ↔ 더보기 4탭 전환(여정은 항상 맨 왼쪽 척추)
- QuickLog/드릴다운: .sheet 또는 push로 모달/상세 진입, 닫으면 여정 동일 스크롤 위치 복귀
- 출산/종료 전환: 출산 CTA → PregnancyTransitionSheet(출산 등록 → 육아 모드 전환) / 종료 → PregnancyTerminationView. 진행 중 전환 미완료(pending) 시 다음 진입에서 PregnancyRecoveryModal 재개
- 검진/진통 카드 → 해당 탭/화면 push 후 back 시 여정 복귀

**한국 디테일**
- 주차 표기: "임신 N주 M일"(NN주N일), 출산 카운트다운 "D-NN / 오늘이 예정일 / +N일 경과"
- 한국 산전검진 마일스톤을 미래 주차 핀으로: 11~13주 NT(목투명대), 15~20주 정밀초음파, 24~28주 임당(임신성 당뇨) — 각 핀에 "이 시기 검진" 안내
- 국민행복카드(임신·출산 바우처) 안내는 검진 마일스톤 카드에서 ③ 검진 탭으로 연결(여정은 핀 표시까지만)
- 산모수첩/태교/만삭사진은 ④ 더보기·서가·추억 영역 — 여정에서는 직접 노출 안 함
- 태동: ACOG "2시간 10회" 표준(태동 시트 목표 10회·2시간 경과 안내)
- 진통 타이머: 5-1-1 규칙(5분 간격·1분 지속·1시간 지속), 37주+에서만 승격 카드 노출
- 광고 0·커머스 0: 어떤 카드/시트에도 광고·상품 추천·딥링크 없음(육아 모드의 쿠팡 딥링크와 격리)
- 의료 면책 배너 상시, 다태임신 시 단태 기준 명시 — 백분위/정상·위험 같은 의학적 판단 텍스트 금지
- 임신 데이터는 Analytics/Crashlytics 커스텀 파라미터 전송 금지(민감 건강정보) — 화면 이벤트 태깅 시 weekKey/babyId 등 식별자 제외

**재사용 자산**
- DashboardPregnancyView: 여정 "오늘" 섹션의 직계 전신(D-day 카드/40주 진행바/주차 카드/체크리스트 프리뷰 상위3/다음 검진 카드/면책·다태 배너/출산 CTA가 거의 1:1 매핑) → 여정 탭으로 승격·재배치. NavigationStack 중첩 금지 룰 준수(여정은 push 측이므로 부모 스택 사용)
- DashboardPregnancyHomeCard: both 모드 육아 홈의 PortalCard 진입점 역할(여정 자체가 아니라 진입 카드)
- PregnancyRecordingSheets: QuickLogStrip의 태동/체중 시트(KickRecordingSheet·PregnancyWeightEntrySheet) 그대로 사용, 증상은 PregnancySymptom 기반 시트 추가
- KickSession: 태동 시트(2시간/10회 ACOG, kicks 배열 임베딩) 그대로 — KickEvent 별도 서브컬렉션 생성 금지
- pregnancy-weeks.json(4~40주, week/fruitSize/milestone/tip): 데일리팁·아기 크기 비교·과거/미래 주차 카드 콘텐츠 소스
- PregnancyDDayWidget / PregnancyWidgetDataStore: sticky 헤더 D-day·진행바와 동일 계산 로직(lmpDate/dueDate 동적) 정합
- PregnancyTransitionSheet / PregnancyTerminationView / PregnancyRecoveryModal: 출산 CTA·종료·pending 재개 전환
- PregnancyRegistrationView: 예정일 미설정 상태의 "임신 정보 설정" CTA 대상
- 신규 필요: PregnancyJourneyView 셸 + 주차 응집 PastWeekCard/UpcomingWeekCard + VisitMilestonePin + 동적 PromotedCard(진통 타이머 화면은 미존재, 신규)

**엣지**
- 예정일 미설정: 진행바/D-day 불확정 → 미설정 CTA 우선, 주차 추정만 가능하면 표기
- 주차 < 4 또는 > 40: pregnancy-weeks.json은 4~40주만 → 범위 밖은 가장 가까운 항목으로 폴백(기존 currentWeekInfo 매칭 로직 유지), 40주+ 경과는 "예정일 경과" 톤
- EDD 변경 이력: eddHistory append-only(덮어쓰기 금지) — 헤더 D-day는 최신 EDD 기준, 과거 카드는 기록 시점 유지
- 다태임신: 단태 기준 면책 노출, 크기/주차 정보 신뢰도 단서 표기
- 첫 진입(데이터 0): 과거 주차 전부 빈 플레이스홀더 → 화면이 비어 보이지 않게 "오늘" 섹션+미래 프리뷰로 채움
- 긴 태동 세션(2시간+): 세션 안정성·중복 카운트 방지, 2시간 경과 시 안내 후에도 기록 지속 가능
- 빠른 연속 QuickLog 탭: 시트 중복 오픈 방지(한 번에 1개 시트)
- 동적 승격 카드 동시 다발(검진 D-2 + 37주 진통): 우선순위로 최대 1~2개만, 나머지는 해당 탭에서 확인
- both에서 임신 종료/출산 전환 직후: 여정 진입 막고 육아 홈/전환 결과로 라우팅(activePregnancy 단독 체크 금지, AppContext 기준)
- 오프라인 기록: 오프라인 큐 적재 후 sync, sync 전에도 낙관적 UI로 "오늘"·주차 카드 반영
- a11y 대형 텍스트(XXXL): QuickLogStrip·헤더 ViewThatFits 폴백으로 truncate 방지, 진행바/면책 텍스트 줄바꿈 허용
- 닫기 동선 혼동 방지: both는 닫기 1번=육아 복귀가 불변(여정 내 push 화면이 열려 있으면 먼저 back 후 공간 닫기)

---

## ②기록/추적 허브 ("임신 노트" 4탭 중 두 번째 탭) — 임신 중 셀프 추적 도구 모음 화면. 매일 쓰는 도구(태동·체중·증상/기분)와 상태가 있을 때 쓰는 도구(혈압/혈당·진통 간격), 선택 모듈(약/수분/수면)을 하나의 스크롤 허브에 모은다. 모든 입력은 저장 시 ①여정 탭의 해당 주차 카드로 역류한다.

**한 줄**: "오늘 내 몸과 아기를 한 곳에서 가볍게 기록" — 도구 그리드에서 탭하면 전용 입력으로 들어가고, 저장하면 ①여정 주차에 자동 반영되는 라일락 톤 추적 허브.

**레이아웃**
위→아래 섹션 순서:

[0] 상단 공간칩 (both 모드만, 화면 최상단 고정) — 좌측 "[← 육아로]" 캡슐 버튼 + 우측 "🤰 임신 N주" 라벨. pregnancyOnly 모드에서는 숨김(이 공간이 앱 루트라 돌아갈 육아 홈이 없음). 탭 컨테이너 공통 칩이므로 ②기록 탭 자체가 그리지 않고 임신 노트 셸에서 상속.

[1] 탭 헤더 "기록" + 선택적 D-day 미니라벨("D-NN" 또는 "N주 N일", 회색 보조). NavigationStack 타이틀은 inline.

[2] 오늘 요약 스트립 (가로 1줄, 가벼움) — 오늘 이미 기록한 항목 개수를 칩으로: "태동 1세션 · 체중 1 · 증상 2" 형태. 아무것도 없으면 "오늘 첫 기록을 남겨보세요" 안내 한 줄. (탭하면 해당 도구로 점프하지 않고 단순 상태 표시 — 위계상 ②는 항상 가벼움)

[3] 세그먼트 컨트롤 — [매일 도구] / [상태별] / [선택 모듈] 3 세그먼트. 기본 선택 = [매일 도구]. (도구 수가 많아 한 화면에 다 펼치면 피로 → 세그먼트로 묶음. 위계: 매일=①②, 가끔=③④ 원칙을 탭 내부에도 반영)

[4] 도구 카드 그리드/리스트 (선택된 세그먼트에 따라 내용 교체):
  • [매일 도구] 세그먼트:
    - 태동 카운터 카드 (가장 위, 큼) — 원형 미리보기 + "오늘 N회 / 10회" + 진행 상태. 탭 → 태동 카운터 풀스크린(KickSessionView 재사용).
    - 체중 + 증가 그래프 카드 — 미니 라인 스파크 + "최근 NN.Nkg (+N.Nkg)" + BMI 권장밴드 점. 탭 → 체중 상세(증가밴드 그래프 풀).
    - 증상/기분 스탬프 카드 — 오늘 찍은 스탬프 썸네일 가로 스크롤 + "+ 스탬프" CTA. 탭 → 주차별 추천칩 스탬프 시트.
  • [상태별] 세그먼트:
    - 혈압/혈당 카드 — 최근 값 2개("120/80 · 공복 95") + 임당 목표선 표시 여부 라벨. 탭 → 혈압/혈당 상세 그래프+입력.
    - 진통 간격 타이머 카드 — "5-1-1 기준 · 초산/경산" 안내 + 큰 "진통 시작" 버튼. 탭/버튼 → 진통 타이머 풀스크린.
  • [선택 모듈] 세그먼트:
    - 약 복용 카드 (토글로 켜야 노출) / 수분 카드 / 수면 카드. 각 카드 우상단 "표시" 스위치. 꺼진 모듈은 흐린 placeholder + "켜기" 버튼.

[5] 빠른 기록 FAB 또는 하단 고정 바 — "+ 빠른 기록" (현재 세그먼트 맥락에 맞는 가장 흔한 입력 시트를 바로 띄움: 매일=태동 또는 증상, 상태별=혈압/혈당).

모든 섹션 공통: 카드 = .regularMaterial 배경 + cornerRadius 16, 액센트는 임신 보라/라일락(육아 핑크 금지). 의료 수치 카드(혈압/혈당·진통)는 상단에 오렌지 면책 배너 1줄 또는 카드 내 info.circle 캡션 필수.

**컴포넌트**
재사용(그대로/소폭):
- KickSessionView (태동 풀스크린: 원형 시작/탭 버튼 88pt·경과타이머·카운터·목표달성 라벨·이전기록 리스트·2시간 자동정지·UIImpactFeedbackGenerator 햅틱·ACOG 면책 배너) — 허브 카드 탭 시 push/풀스크린으로 그대로 호출. AppColors.primaryAccent → 보라/라일락 토큰 치환 필요(현재 핑크 계열일 수 있음, 델타).
- KickRecordingSheet (NavigationStack + KickSessionView + "닫기") — 빠른 기록 진입점.
- PregnancyWeightView (체중 라인차트 + 임신 전 RuleMark + "임신 전 대비 +N.Nkg" + 기록 리스트 + WeightEntryFormSheet medium detent) — 체중 카드 상세. 현재 차트 색 AppColors.sageColor → 보라 토큰 + Korean BMI 권장 증가밴드 AreaMark 추가(델타).
- PregnancyWeightEntrySheet / PregnancySymptomMemoSheet (PregnancyRecordingSheets.swift의 medium 시트 3종) — 빠른 기록·스탬프 진입점. 증상 시트는 현재 자유 메모+Severity 세그먼트만 → 주차별 추천칩 추가(델타).
- HealthPregnancySectionCard (HealthPregnancyView 내부 카드: 아이콘 박스 50pt + 제목 + 서브타이틀 + 배지 캡슐 + chevron) — 허브 도구 카드의 베이스 컴포넌트로 승격/재사용.

신규:
- PregnancyTrackingHubView (이 화면 루트, 세그먼트 + 그리드).
- TodaySummaryStrip (오늘 기록 개수 칩 스트립).
- TrackingToolCard (HealthPregnancySectionCard 변형: 미니 차트/원형 미리보기 슬롯 추가, 보라 토큰).
- SymptomMoodStampSheet (주차별 추천칩: pregnancy-weeks.json 주차의 흔한 증상/기분 칩 + 자유 추가 + 강도 세그먼트). PregnancySymptomMemoSheet 확장.
- BloodPressureGlucoseView + 입력 시트 (Apple Charts 2계열 + 임당 목표선 RuleMark, 공복/식후 구분).
- ContractionTimerView (진통 간격 타이머: 큰 시작/정지 버튼·간격·지속·5-1-1 판정 라벨·초산/경산 토글·세션 리스트). KickSession의 세션+타이머+햅틱 패턴 차용하되 별도 화면.
- OptionalModuleToggleCard (약/수분/수면 모듈 표시 스위치 + 꺼짐 placeholder).

토큰/심볼: AppColors 임신 보라/라일락 액센트, SF Symbols(hand.tap.fill 태동·scalemass.fill 체중·face.smiling 기분·heart.text.square 혈압·drop.fill 혈당/수분·stopwatch 진통·pills.fill 약·bed.double.fill 수면), Apple Charts(체중·혈압/혈당), 오렌지 info.circle 면책.

**상태**
- 로딩: pregnancyVM 데이터 fetch 중 — 각 카드 자리에 redacted/skeleton 또는 미니 ProgressView. 오늘 요약 스트립은 "—".
- 빈 상태(신규/오늘 기록 0): 오늘 요약 스트립 = "오늘 첫 기록을 남겨보세요". 각 도구 카드 서브타이틀 = 권유 카피("태동을 기록해보세요 (10회 목표)" / "체중을 기록해보세요" / "오늘 컨디션을 스탬프로"). 체중 차트 카드는 ContentUnavailableView(scalemass) — PregnancyWeightView 기존 패턴.
- 부분 데이터: 카드별 독립 — 태동만 있고 체중 없음 등 각자 채워짐.
- 태동 진행 중(currentKickSession != nil): 태동 카드에 "진행 중 N회" 라이브 표시 + 카운트 색 진행/달성 분기(미달=보라, 달성=초록 + star.fill "목표 달성").
- 진통 타이머 진행 중: 진통 카드가 라이브 간격 표시("마지막 간격 4분 30초"), 5-1-1 충족 시 카드 강조 + "병원 연락을 고려하세요" 비지시적 안내(의료 단정 금지).
- 모듈 꺼짐: 약/수분/수면 카드 흐림 + "켜기" 스위치 off.
- 임신 전 체중 미입력: 증가밴드/RuleMark 숨김, 절대값만.
- 주차 미상(LMP/EDD 불완전): 증상 추천칩 = 주차별 대신 범용 칩으로 폴백.
- 에러: pregnancyVM.errorMessage 노출 시 카드 상단 인라인 경고(저장 실패 등), 시트는 저장 실패 시 dismiss 안 함(기존 패턴: errorMessage==nil일 때만 dismiss).
- both 모드: 상단 공간칩 노출 / pregnancyOnly: 공간칩 숨김.
- 접근성: Dynamic Type XXXL에서 카드 HStack→ViewThatFits 세로 폴백(진입점 truncate 방지, 빌드61 H-8 선례), 햅틱은 시스템 설정 존중, 색상 단독 의존 금지(목표달성=색+아이콘+텍스트).

**상호작용**
- 세그먼트 전환: [매일]/[상태별]/[선택] 탭 → 그리드 콘텐츠 크로스페이드, 선택 상태 보라 하이라이트.
- 태동 카드 탭 → 태동 카운터 화면. 원형 "시작" → 세션 시작 + 1초 타이머. 큰 탭 버튼(88pt) → UIImpactFeedbackGenerator(.light) 햅틱 + 카운트+1, 10회 도달 시 UINotificationFeedbackGenerator(.success). "세션 종료" → 저장 후 닫기. 2시간 초과 자동 정지.
- 체중 카드 탭 → 체중 상세. 우상단 "+" → WeightEntryFormSheet(medium). 단위 kg/lb 세그먼트, ko_KR DatePicker, decimalPad. 저장 → 차트·"임신 전 대비" 갱신.
- 증상/기분 카드 "+ 스탬프" → SymptomMoodStampSheet. 주차별 추천칩 멀티선택 + 강도(약/중간/심함) 세그먼트 + 자유 메모. 저장.
- 혈압/혈당 카드 탭 → 입력+그래프. 공복/식후 토글, 수축기/이완기·혈당 숫자 입력, 임당 목표선 on/off. 저장 → 2계열 차트 갱신.
- 진통 "진통 시작" 버튼 → ContractionTimer 시작. 매 진통마다 "수축 시작/끝" 탭으로 간격·지속 기록, 5-1-1(5분 간격·1분 지속·1시간 지속) 판정 라벨 라이브 갱신. 초산/경산 토글로 안내 문구 조정. 햅틱 피드백.
- 빠른 기록 바/FAB → 현재 세그먼트 맥락 시트(medium detent).
- 공간칩 "[← 육아로]" → fullScreenCover 닫기(육아 홈 복귀, both만).
- 모든 저장 성공 → 스낵바/햅틱 success + 오늘 요약 스트립 즉시 갱신 + ①여정 해당 주차 카드 역류.
- 당겨서 새로고침: 허브 스크롤 pull-to-refresh로 pregnancyVM 재fetch.

**전이**
- ②기록 허브 → 태동 카운터(KickSessionView): NavigationStack push 또는 .sheet(KickRecordingSheet) — 빠른기록 경로는 시트, 카드 탭은 push.
- ②기록 허브 → 체중 상세(PregnancyWeightView): push. 체중 상세 → 입력: .sheet medium.
- ②기록 허브 → 증상 스탬프(SymptomMoodStampSheet): .sheet medium.
- ②기록 허브 → 혈압/혈당 상세: push. → 입력 .sheet.
- ②기록 허브 → 진통 타이머(ContractionTimerView): 풀스크린 또는 push(타이머 집중 화면, 진행 중 실수 이탈 방지 위해 풀스크린 권장 + 명시적 닫기).
- 저장 완료 → 시트 dismiss(errorMessage==nil 시) → 허브 복귀, 데이터 역류로 ①여정 주차 카드/홈 요약 동기 갱신.
- 공간칩 "← 육아로" → 임신 노트 fullScreenCover 전체 dismiss → 육아 홈(닫기 1번 = 육아 복귀, IA 규칙).
- 탭 간 이동: ②기록 ↔ ①여정/③검진/④더보기 = 임신 노트 내부 TabView 전환(상태 보존). 신규 상태머신 없음 — 기존 AppContext(.both/.pregnancyOnly)만 사용.
- 출산/종료 전환 발생 시: 임신 노트 자체가 PregnancyTransitionSheet/PregnancyTerminationView 경유로 닫히고 육아/아카이브로 — ②기록 화면이 직접 처리하지 않고 셸이 처리.

**한국 디테일**
- 주차 표기: "N주 N일" + "D-NN"(D-day) 동시 노출(PregnancyDateMath/PregnancyDDayWidget 일관).
- 태동: ACOG "2시간 내 10회" 기준선·면책("태동 감소·변화 시 즉시 의료진 연락, 참고용") — KickSessionView 기존 카피 유지.
- 체중: 한국 임신 전 BMI 기준 권장 총 증가 밴드(저체중/정상/과체중/비만 구간별 권장 kg 범위)를 Apple Charts AreaMark로 표시 — 단, "정상/위험" 의학 단정 텍스트 금지(밴드+절대값만, 백분위 판단 금지 룰 준용).
- 혈당: 임신성 당뇨(임당) 목표선(공복/식후 1~2시간 기준선)을 RuleMark로 — 목표 수치는 일반 참고 안내, 진단 단정 금지.
- 진통: 5-1-1 규칙(5분 간격·1분 지속·1시간 지속) + 초산/경산 구분 안내. "병원 연락 고려" 비지시적 표현(의료 명령 금지).
- 산전검진 맥락 연계: 혈압/혈당·체중은 한국 산전검진 일정(11~13주 NT, 15~20주 정밀초음파, 24~28주 임당검사) 도래 시 ③검진 탭과 교차 안내(역류). 단 ②는 도구 제공, 일정 관리는 ③.
- 산모수첩/태교/만삭사진은 ④더보기 소관 — ②에서 직접 노출 X(중복 금지).
- 광고 0·커머스 0(국민행복카드 등 상거래 유도 금지). 임신 데이터는 Analytics/Crashlytics 파라미터 포함 절대 금지(민감 건강정보, 화면 내 모든 로깅 logSilent/비식별).
- 모든 수치 단위 한국 기본(kg, mmHg, mg/dL), 날짜·시간 ko_KR 로케일.

**재사용 자산**
직접 재사용(파일 경로):
- /Users/roque/BabyCare/BabyCare/Views/Health/KickSessionView.swift — 태동 카운터 풀스크린(원형 버튼·햅틱·세션·2h 자동정지·ACOG 면책·이전기록).
- /Users/roque/BabyCare/BabyCare/Views/Health/PregnancyWeightView.swift — 체중 라인차트 + 임신 전 RuleMark + 증가량 + WeightEntryFormSheet.
- /Users/roque/BabyCare/BabyCare/Views/Pregnancy/PregnancyRecordingSheets.swift — KickRecordingSheet / PregnancyWeightEntrySheet / PregnancySymptomMemoSheet(빠른 기록 진입점 3종, medium detent).
- /Users/roque/BabyCare/BabyCare/Views/Health/HealthPregnancyView.swift — HealthPregnancySectionCard(도구 카드 베이스로 승격), 서브타이틀 상태 카피 패턴.
- /Users/roque/BabyCare/BabyCare/Models/KickSession.swift — kickCount/reachedTarget/durationSeconds/exceededTwoHours·KickEvent 임베딩(서브컬렉션 금지 룰).
- /Users/roque/BabyCare/BabyCare/Models/PregnancySymptom.swift — memo+Severity(약/중간/심함), 스탬프 시트 기반.
- /Users/roque/BabyCare/BabyCare/Resources/pregnancy-weeks.json — 주차별 증상 추천칩 소스(주차 콘텐츠).
- /Users/roque/BabyCare/BabyCare/ViewModels/PregnancyViewModel.swift — startKickSession/recordKick/endKickSession/addWeightEntry/addSymptom·currentKickSession/kickSessions/weightEntries·dataUserId() 공유 패턴.

간접/연계:
- DashboardPregnancyView·DashboardPregnancyHomeCard(①여정·홈 역류 대상), PregnancyDDayWidget/PregnancyDateMath(주차·D-day 계산), PregnancyTransitionSheet/PregnancyTerminationView/PregnancyRecoveryModal(셸 전환), AppColors(보라/라일락 토큰).

델타(재사용+수정 필요):
- KickSessionView/PregnancyWeightView의 AppColors.primaryAccent·sageColor → 임신 보라/라일락 토큰 치환.
- PregnancyWeightView에 Korean BMI 권장 증가밴드 AreaMark 추가.
- PregnancySymptomMemoSheet → 주차별 추천칩(SymptomMoodStampSheet) 확장.
- 신규 컬렉션(혈압/혈당·진통) 추가 시 Narrow Protocol 5단계 + arch-test Rule3 baseline 0 준수 필수.

**엣지**
- 태동: 2시간 초과 세션 자동 정지(KickSession.exceededTwoHours·타이머 가드) — 백그라운드/장시간 세션에서 타이머 invalidate 누락 방지(onDisappear stopTimer 유지). 같은 날 다중 세션 허용, 오늘 요약은 세션 수로 집계.
- 진통 타이머: 앱 백그라운드/화면잠금 중 경과 시간 손실 위험 → 시작 시각 기준 절대시간 계산(타이머 카운트에만 의존 금지). 진행 중 실수 이탈 방지(풀스크린 + 명시적 종료). 5-1-1 판정은 안내일 뿐 의료 단정 금지.
- 체중: 단위 kg/lb 혼재 입력 시 환산/일관 표시. 임신 전 체중 미입력이면 증가밴드 숨김. 비정상 입력(음수·극단값) 방어.
- 혈압/혈당: 공복/식후 라벨 누락 시 목표선 비교 무의미 → 입력 시 구분 필수. 목표선은 참고선, "정상/위험" 텍스트 금지.
- 데이터 역류 실패: 저장은 됐으나 ①여정 갱신 지연 시 stale 방지 — pregnancyVM 단일 소스 관찰로 자동 동기, 수동 새로고침 fallback.
- 모드 전이: 입력 도중 출산/유산/종료 전환 발생 시(셸 레벨) 미저장 시트 안전 처리 — 진행 중 세션/타이머 무손실 종료.
- 가족 공유: 파트너가 본 ② 화면은 dataUserId() 경유 owner 경로 — 쓰기 권한/읽기전용 구분(공유 임신은 sharedWith). authVM.currentUserId 직접 사용 금지.
- 접근성: Dynamic Type XXXL 카드 truncate → ViewThatFits 세로 폴백(H-8 선례). Reduce Motion 시 세그먼트 크로스페이드/달성 애니메이션 축소. 햅틱 시스템 설정 존중.
- 빈/오프라인: OfflineQueue 경유 쓰기 큐잉 — 오프라인 저장 후 동기. 첫 주 데이터 없음과 실제 0 구분(빌드 가드 선례, 빈 dict 버그 회피).
- 로깅: 임신 수치는 Analytics/Crashlytics 파라미터 절대 미포함, 진단은 logSilent + AppLogger.pregnancy(비식별).

---

## ③검진 — PrenatalCareView (임신 노트 4탭 중 3번째 탭, 한국 산전관리 허브)

**한 줄**: 한국 산전검진 일정·국민행복카드 바우처·산모수첩 수치를 "검진 객체" 하나로 묶어 주차별 자동 매핑하고, 다음 검진 D-day부터 진료 준비까지 한 흐름으로 잇는 임신 노트의 한국 차별화 심장 화면.

**레이아웃**
위→아래 세로 스크롤(ScrollView + LazyVStack, 16pt 좌우 인서트, 섹션 간 20pt). 상단 inline 네비 타이틀 "검진" + 우상단 [+] (검진 일정 추가). 탭 자체 상단에 4탭 공통 공간칩 바([← 육아로] + "🤰임신 28주 3일", both 모드만 노출 / pregnancyOnly는 칩 숨김).

[섹션 0 — 면책 배너] (스크롤 최상단 고정 아님, 첫 섹션) info.circle.fill + "검진 일정과 수치는 참고용이에요. 의학적 판단은 담당 의료진과 함께 하세요." 라일락 톤(보라 0.12 배경 + 0.4 stroke), 1줄.

[섹션 1 — 다음 검진 히어로 카드] 가장 크고 시선 1순위. 라일락 그라데이션 카드. 상단: D-day 대형 캡슐("D-5" / "오늘" / "D+2 지연")·우측 작은 주차 라벨("28주차 검진"). 중앙: 검진명 + 병원명 + 예정 일시(ko_KR 로케일). 하단 가로 칩: 이 검진이 한국 표준 일정과 매핑되면 자동 라벨(예: "🩺 임신성 당뇨 검사 GTT"·"💉 정밀초음파"). CTA 2개: [진료 준비 메모] [완료 체크]. 검진이 0건이면 이 카드 대신 빈 상태 안내 카드(아래 states).

[섹션 2 — 한국 산전검진 타임라인(주차 자동 매핑)] 🔴핵심. 헤더 "한국 산전검진 일정" + 보조문 "내 주차에 맞춰 자동으로 알려드려요". 세로 타임라인(좌측 척추 라인 + 노드). 각 노드 = 표준 검진 항목 한 줄(예: 11~13주 NT·15~20주 정밀초음파·24~28주 임당 GTT·산전 기형아 1차/쿼드). 상태 점: 지난 권장창=완료/누락 / 현재 권장창=강조(라일락 펄스 도트) / 미래=비활성 회색. 현재 주차 위치에 "지금 여기" 마커. 각 노드 탭→해당 검진 객체 상세(없으면 "이 검진 추가하기" CTA로 폼 프리필).

[섹션 3 — 국민행복카드 바우처 카드] 🔴핵심. 카드 헤더 "국민행복카드 (임신·출산 진료비)". 큰 잔액 숫자 + 진행 바(사용액/총지원액). 보조 라벨: 단태아/다태아 지원 한도 안내, 사용 가능 기간(분만예정일 이후 기준 안내). 하단 "사용처 보기" 디스클로저(병의원·약국 등 일반 안내) + "잔액 직접 입력" 인풋(앱은 카드사 미연동·수동 기록). 면책: "실제 잔액은 카드사·정부24에서 확인하세요." 커머스/결제 링크 0.

[섹션 4 — 산모수첩 디지털 미러] 🔴핵심. 헤더 "산모수첩" + 보조문 "검진 때 받은 수치를 여기에 모아두세요". 가로 스크롤 또는 2열 그리드의 최신 수치 칩(혈압·체중·자궁저높이·태아 추정체중·혈당 등 한국 산모수첩 항목). 각 칩=항목명 + 최신값 + 측정일. 헤더 우측 "전체 보기"→누적 수치 표(Apple Charts 추이 가능 항목은 미니 sparkline). 검진 객체에 수치가 입력되면 자동으로 여기 미러링.

[섹션 5 — 주차별 체크리스트] 헤더 "이번 주 할 일" (현재 삼분기 우선). 체크 항목 행(prenatal-checklist.json 번들 + 사용자 추가). 토글 즉시 반영 + 완료율 미니 바. "전체 체크리스트"→PregnancyChecklistView 풀 화면.

[섹션 6 — 진료 준비 질문 메모] 헤더 "진료 때 물어볼 것". 다음 검진에 연결된 질문 리스트(체크 가능한 메모 행) + "질문 추가" 인라인 인풋. 검진 완료 시 "물어봤어요" 토글로 소거.

[섹션 7 — 음식 안전 빠른 조회] 컴팩트 검색 진입 행: 돋보기 + "임신 중 먹어도 될까? (예: 회, 커피, 약)". 탭→음식/약물 안전 조회 시트(빠른링크, 도구함 K영역 자산). 면책 동반.

**컴포넌트**
- PrenatalCareView (탭 루트, ScrollView + LazyVStack)
- PrenatalDisclaimerBanner (재사용: PregnancyChecklistView의 ChecklistDisclaimerBanner를 라일락 변형으로 일반화)
- NextVisitHeroCard (신규): D-day 캡슐 + 표준매핑 칩 + 진료준비/완료 CTA. D-day 텍스트·색상은 PrenatalVisit.daysUntilScheduled/isOverdue/isDueSoon 로직 재사용
- KoreanPrenatalTimelineCard (신규): 표준 검진 스케줄 노드 리스트. 노드 = PrenatalScheduleNodeRow (완료/현재창/미래 3상태 점 + "지금 여기" 마커)
- HappyCardVoucherCard (신규): 잔액 진행 바 + 단태/다태 한도 라벨 + 사용처 디스클로저 + 잔액 입력 필드
- MaternalRecordMirrorCard (신규): MeasurementChip 그리드(항목/값/측정일) + "전체 보기" → MaternalRecordDetailSheet(수치 표 + 항목별 Apple Charts sparkline)
- WeeklyChecklistMiniCard (신규 요약): 행=PregnancyChecklistItemRow 패턴 재사용, 완료율 ProgressView, "전체" → PregnancyChecklistView(기존 풀 화면)
- VisitQuestionMemoCard (신규): 질문 행(토글) + 인라인 추가 입력
- FoodSafetyQuickRow (신규 진입 행) → FoodSafetySheet (기존 음식안전 자산 빠른링크)
- 입력 시트: PrenatalVisitFormSheet (기존 재사용·확장 — 표준 검진 유형 프리필 + 수치 입력 필드 추가) / 진료준비·질문 시트 / 바우처 잔액 입력 인라인
- 토큰: DS2 Color.accent(보라 #primaryAccent 라일락 액센트), Spacing/Radius/Shadow.sm·md, SF Symbols(stethoscope·cross.case·creditcard·book.closed·checklist·magnifyingglass), Apple Charts(수치 추이만)

**상태**
- 로딩: 카드 골격 redaction(.redacted placeholder) — 검진/수치/바우처 비동기 로드 중. LoadingStateful 패턴.
- 빈 상태(검진 0건): 히어로 카드 자리에 ContentUnavailableView 풍 카드 "stethoscope" + "아직 등록된 검진이 없어요 / 첫 산전 진찰을 추가해보세요" + [검진 추가] CTA. 타임라인·바우처·산모수첩 섹션은 권장 일정/안내문으로 채워져 항상 가치 노출(빈 화면 금지).
- 정상: 모든 섹션 데이터 표시.
- 다음 검진 임박(D-14 이내, isDueSoon): 히어로 캡슐 주황 강조 + (옵션) 상단 가벼운 알림 톤.
- 지연(isOverdue): 히어로 캡슐 빨강 "D+N 지연" + "일정 다시 잡기" 보조 CTA.
- 표준창 도래: 타임라인 현재 노드 라일락 펄스 도트 + 히어로에 "이번 주 권장: 임당검사" 배너 칩.
- 바우처 미입력: 잔액 숫자 자리에 "잔액을 입력해두면 한눈에 볼 수 있어요" + [입력]. 진행 바 0.
- 산모수첩 미입력: 미러 그리드 자리에 "검진 수치를 기록해보세요" 안내 + 대표 항목 가이드 칩(비활성).
- 에러: 카드 하단 인라인 errorMessage(스낵바 아님) + 재시도. logSilent 경유 진단.
- 오프라인: 캐시 데이터 표시 + 상단 "오프라인 — 변경은 연결 시 반영" 배너(OfflineQueue). 쓰기는 큐잉.
- 출산 전환 pending(transitionState=pending): 검진 탭 진입 시 PregnancyRecoveryModal 우선 노출(orphan resume) — 임신 노트 공통 가드.
- 접근성: Dynamic Type XXXL에서 히어로 CTA·칩 ViewThatFits로 줄바꿈/세로 적층, Reduce Motion 시 펄스 도트 정적, VoiceOver는 "D-5, 임신성 당뇨 검사, 6월 20일 예정" 결합 라벨.

**상호작용**
- 히어로 [완료 체크] 탭 → 검진 isCompleted 토글(낙관적 업데이트 + 실패 rollback, OptimisticReplaceable) → 타임라인 노드도 완료로 동기화 + 완료 시 산모수첩 수치 입력 유도 시트.
- 히어로 [진료 준비 메모] 탭 → §6 질문 메모 시트 포커스(해당 검진에 질문 연결).
- 우상단 [+] / 타임라인 미등록 노드 탭 → PrenatalVisitFormSheet(.medium/.large 디텐트). 노드 탭 시 visitType·예정 주차 프리필.
- 타임라인 등록 노드 탭 → 검진 상세(일정+수치+초음파 메모 한 객체). 상세에서 수치 입력 → 산모수첩 미러 자동 갱신.
- 바우처 "잔액 직접 입력" → 숫자 인풋(수동 기록, 카드사 미연동). "사용처 보기" → 디스클로저 펼침(일반 안내, 외부 링크/결제 0).
- 산모수첩 "전체 보기" → MaternalRecordDetailSheet(항목별 Apple Charts sparkline + 누적 표).
- 체크리스트 행 토글 → 즉시 반영(toggleChecklistItem) + 완료율 바 애니메이션. "전체" → PregnancyChecklistView push.
- 질문 메모: "질문 추가" 인라인 입력 → 저장 / 검진 완료 시 "물어봤어요" 토글.
- 음식안전 행 탭 → FoodSafetySheet 검색.
- 모든 의학 수치/안내에 면책 동반. 임신 데이터는 Analytics payload 금지(탭 이벤트는 화면명 수준만).

**전이**
- 진입: 임신 노트 4탭의 ③검진 탭 선택 시 표시(both=PortalCard→fullScreenCover 내부 탭 / pregnancyOnly=앱 루트 탭). 신규 상태머신 없음 — 기존 AppContext(.both/.pregnancyOnly)만.
- 검진 추가/완료/수치 입력 → 시트 dismiss 후 해당 섹션 인플레이스 갱신(전체 리로드 아님).
- 히어로 D-day는 진입 시점 재계산(앱 포그라운드 복귀 시 갱신).
- "전체 체크리스트" → PregnancyChecklistView는 push(부모 NavigationStack 사용, 자체 NavigationStack 금지 — 중첩 크래시 회피 규칙).
- 산모수첩/바우처/진료준비/음식안전 상세는 sheet(.presentationDetents [.medium,.large]) — 탭 컨텍스트 보존.
- transitionState=pending이면 탭 콘텐츠보다 PregnancyRecoveryModal 우선.
- 닫기 1번(공간칩 [← 육아로] 또는 fullScreenCover dismiss) → 육아 홈 복귀(both 모드).

**한국 디테일**
- 주차 표기: "NN주 N일" + D-day 병기. 한국 표준 산전검진 자동 매핑 창: 11~13주 NT(목투명대), 15~20주 쿼드/정밀초음파, 24~28주 임신성 당뇨 GTT(50g→100g), 1차/2차 기형아 검사 — 현재 주차에 맞춰 타임라인 노드 강조.
- 국민행복카드: 임신·출산 진료비 바우처. 단태아/다태아 차등 한도, 사용 기한(분만예정일 이후 일정 기간) 안내 라벨. 앱은 카드사 미연동 → 수동 기록 + "실제 잔액은 카드사/정부24 확인" 면책. 커머스/결제 링크 절대 0.
- 산모수첩: 한국 종이 산모수첩 항목을 디지털 미러(혈압·체중·자궁저높이·태아추정체중·혈당). 검진 객체 입력 → 자동 미러링.
- 음식/약물 안전: 한국 임산부 맥락(회·커피 카페인·한약·일반약) 빠른 조회.
- 체크리스트 카테고리: 1삼분기(1~13주)/2삼분기(14~27주)/3삼분기(28~40주)/출산준비 — prenatal-checklist.json 한국 일정 반영(첫 산전진찰·엽산·NT·정밀초음파·GTT·태동기록·출산가방).
- 톤: 보라/라일락 액센트(육아 핑크 #FF9FB5와 시각적 분리). 광고 0·커머스 0. ko_KR 로케일 DatePicker. 의료 감수 문구 전 섹션 동반.

**재사용 자산**
- PrenatalVisit 모델 + daysUntilScheduled/isDueSoon/isOverdue D-day 로직 (그대로 재사용; 색상·라벨 규칙 동일).
- PrenatalVisitListView / PrenatalVisitFormSheet (히어로·타임라인이 이 폼을 표준 검진 유형 프리필 + 수치 필드로 확장 호출; visitTypes routine/ultrasound/bloodTest/gtt/other 매핑).
- PregnancyChecklistView + PregnancyChecklistItemRow + ChecklistDisclaimerBanner (§5 요약→풀화면 push, 면책 배너 라일락 변형).
- prenatal-checklist.json (번들 12항목·trimester1/2/3/postpartum_prep·targetWeek) — 타임라인/체크리스트 시드.
- pregnancy-weeks.json (주차·과일크기·milestone·tip·disclaimerKey) — 현재 주차 컨텍스트/표준창 매핑 보조.
- PregnancyViewModel (prenatalVisits·checklistItems·activePregnancy·togglePrenatalVisit·savePrenatalVisit·toggleChecklistItem·loadBundleChecklistIfNeeded·dataUserId 공유 패턴).
- PregnancyFirestoreProviding narrow protocol + MockPregnancyFirestore (수치/바우처 신규 필드 추가 시 동일 5단계 패턴 따름).
- PregnancyRecoveryModal (pending orphan 가드), PregnancyDDayWidget(주차/D-day 계산 일관성), DS2 토큰(Color.accent·Spacing·Radius·Shadow·tintPurple), Apple Charts(수치 추이), LoadingStateful/OptimisticReplaceable VM helper.

**엣지**
- D-day 경계: 오늘(0)="오늘", 음수=isOverdue "D+N 지연"(빨강), isCompleted="완료"(초록) — PrenatalVisitRow 규칙과 충돌 없게 단일 소스. 자정·타임존 KST 기준 startOfDay 비교(빌드 테스트 timezone 교훈: 월중간 정오 기준).
- 표준 매핑 충돌: 사용자가 같은 표준 검진을 중복 등록 → 타임라인 노드는 최신/예정 1건만 강조, 나머지 목록에서.
- 주차 미상(LMP만 있고 초음파 보정 전) 또는 주차 범위 밖(전체 0~42주 외) → 타임라인 "지금 여기" 마커 숨김, 안내문 폴백.
- 바우처: 사용액 > 총지원액 입력 시 진행 바 100% clamp + 경고 라벨. 음수/비현실 입력 검증. 다태아 토글 시 한도 라벨만 변경(저장값 보존).
- 산모수첩 수치 단위 혼동(kg/g, mmHg) 가드 + 빈 측정일 → "측정일 미입력" 폴백. .unknown 활동 센티넬처럼 미지 항목은 중립 처리(의료수치 누수 방지).
- 검진 완료 토글 낙관적 업데이트 실패 → rollback + 인라인 errorMessage(스낵바 아님), 타임라인 동기화도 원복.
- 오프라인 쓰기(검진 추가·완료·수치) → OfflineQueue 큐잉, 중복 큐잉 방지.
- 공유(파트너 read-only): sharedWith 파트너는 검진/수치 열람만, 편집·바우처 입력 비활성.
- transitionState=pending(출산 진행 중) → 검진 탭 콘텐츠보다 PregnancyRecoveryModal 우선, 신규 입력 차단.
- 빈 화면 절대 금지: 데이터 0이어도 표준 일정·바우처 안내·가이드 칩으로 항상 가치 노출.
- 면책 누락 금지: 모든 수치/안내/체크리스트 섹션에 의료 면책 동반(safety.md 백분위 의학판단 텍스트 금지 준수 — 정상/비정상 판정 문구 미표기).

---

## ④더보기 — PregnancyMoreView (임신 노트 4번째 탭의 "도구함·라이브러리·설정 허브")

**한 줄**: 매일 쓰는 것(여정·기록·검진)을 뺀 "가끔·1회성" 모든 것 — 출산 도구, 감수 콘텐츠 서가, 정서·추억, 부부 함께보기, 커뮤니티, 공간 설정 — 을 보라/라일락 톤의 접어 묶기 섹션으로 정리해, 단일 스크롤이 비대해지지 않게 "필요할 때 펼쳐 꺼내 쓰는" 라이브러리형 허브.

**레이아웃**
위→아래 섹션 순서(스크롤 1개, 임신 노트 4탭의 4번째 NavigationStack 루트):

[0] 상단 공간칩 바 (both에서만, pregnancyOnly는 숨김 — IA Exit 명세)
- 좌: [← 육아로] 라일락 캡슐 칩(chevron.left + "육아로"). 탭=fullScreenCover dismiss → 떠났던 육아 홈 복귀.
- 우: "🤰 임신 24주" 정체성 라벨(figure.and.child.holdinghands + NN주). 탭 불가, 위치 인지용.
- 4탭 공통 컴포넌트라 ①②③과 동일. ④에서도 상단 고정.

[1] 화면 타이틀 영역
- inline navigationTitle "더보기". 큰 히어로 없음(④는 도구 진열대지 콘텐츠 무대가 아님). 배경=시스템 그룹 배경, 섹션 카드=보라 8% 틴트 라운드.

[2] ▸ 도구함 (접힘 default) — DisclosureGroup, leadingIcon=wrench.and.screwdriver
헤더: "도구함" + 우측 chevron + 접힘 시 "예정일 계산·출산 준비물 외 5" 보조 라벨.
펼침 시 세로 리스트 로우(각 NavigationLink push):
- 예정일 계산기 (calendar.badge.clock) — LMP/초음파/IVF 3방식
- 출산 준비물 체크리스트 (checklist) — 아기·산모 용품
- 출산가방 체크리스트 (bag) — 병원용/산후조리원용 분리
- 출산계획서 (doc.text) — 한국 분만 맥락
- 이름 짓기 (textformat.abc) — 부부 공동, "함께보기" 초대 시 공동편집 배지
- 다태아 모드 (figure.2) — 쌍둥이 토글/태아별 칸 (활성 시 "켜짐" trailing 캡슐)
- 위젯 안내 (apps.iphone) — 홈/잠금화면 D-day 위젯 추가법(읽기 가이드)

[3] ▸ 콘텐츠 서가 (접힘 default) — leadingIcon=books.vertical
- 발달 일러스트 모아보기 (figure.child) — 4~40주 태아 일러스트 갤러리(주차 그룹)
- 감수 아티클 라이브러리 (text.book.closed) — "의료 감수" 신뢰 배지, 카테고리 그리드+검색+저장글
- 태교 음악/동화 (music.note) — 플레이어(취침 타이머·백그라운드), 손실 시 자동추천 억제
- 운동/요가 가이드 (figure.yoga) — 주차별 권장/금기, "운동 전 의료진 상담" 면책 상시
- 영양 가이드 / 영양제 (leaf) — 트라이메스터별 엽산·철분 코치 (③검진 음식안전과 상호 링크)
각 로우 trailing에 "감수" 마이크로 배지(해당 콘텐츠만).

[4] ▸ 정서·추억 (펼침 default — 정서 가치가 높아 default-on) — leadingIcon=heart.text.square
- 임신 일기 (book.closed) — 작성 진입(주차 자동 태깅), 최근 1건 미리보기 썸네일
- 만삭 타임랩스 앨범 (photo.stack) — 28~34주 황금기 진입 시 상단에 부드러운 안내 띠
- 초음파 타임라인 (waveform.path.ecg.rectangle) — 주차순 정렬, ③검진 첨부와 동일 자산 풀
- 아기에게 쓰는 편지·태담 (envelope) — 출산 후 아이에게 전달되는 편지함
※ "작성=④, 노출=①여정 핀" 원칙: 여기서 만든 것은 ①여정 해당 주차 카드에 핀으로도 뜸.

[5] ▸ 함께보기 (접힘 default) — leadingIcon=person.2
- 부부·가족 초대 (person.crop.circle.badge.plus) — 카톡 친화 초대코드 생성/공유, 현재 멤버 리스트
- 응원·태담 스탬프 (hand.thumbsup) — 파트너가 보낸 스탬프 모아보기(①카드에 반응으로도 표시)
- 역할 배지(소유자/파트너) 인라인 표기. 비가역 CTA는 파트너에게 미노출.

[6] ▸ 커뮤니티 (접힘 default) — leadingIcon=bubble.left.and.bubble.right
- "○월 출산맘" 동기 그룹 + 전체 게시판 진입 1로우. 손실 조용한 모드 시 이 섹션 전체 숨김.

[7] ▸ 공간 설정 (항상 펼침, 최하단) — leadingIcon=gearshape
- 알림 (bell.badge) → 알림 절제 센터(주차/검진/태동/준비, "현재 N종 켜짐" 요약) [PregnancyShareView 외 신규]
- 임신 정보 수정 (square.and.pencil) → 태명/EDD(append-only)/다태아 등
- 부부 공유 관리 (person.2.badge.gearshape) → PregnancyShareView 재사용
- 이전 임신 보기 (clock.arrow.circlepath) → PregnancyArchiveView 재사용
- 출산했어요 (sparkles, 보라 강조, 소유자만, 36주+에서만 활성) → PregnancyTransitionSheet
- 임신 정보 정리 (절제 라벨, 회색, 최하단 분리) → PregnancyTerminationView (손실 경로)

[8] 푸터: "베이비케어는 광고와 판매를 하지 않습니다" 1줄 + 의학 면책 단문.

**컴포넌트**
- PregnancyMoreSection (재사용 DisclosureGroup 래퍼): leadingIcon + 제목 + 접힘 시 보조라벨 + 펼침 상태 영속(섹션별 @AppStorage). 보라 8% 틴트 카드.
- MoreRowLink: SF Symbol(라일락 틴트) + 제목 + optional trailing(배지/상태칩/chevron). NavigationLink push.
- 상단 SpaceChipBar(4탭 공통): [← 육아로] 캡슐 + "🤰 임신 N주" 라벨.
- TrustBadge("감수"): 감수 콘텐츠 로우 trailing 마이크로 배지.
- StateChip("켜짐"/"N종 켜짐"): 다태아·알림 현재상태 trailing 캡슐.
- GoldenWindowBanner: 만삭 앨범 28~34주 안내 띠.
- QuietModeRedactor: 손실 outcome일 때 섹션 가시성/톤을 갈아끼우는 상위 가드(커뮤니티·응원스탬프·태교 자동재생·출산CTA 숨김).
- 재사용 그대로: PregnancyShareView, PregnancyArchiveView/PregnancyArchiveDetailView, PregnancyTransitionSheet, PregnancyTerminationView, PregnancyRecordingSheets(일기/만삭/초음파 작성 시트).
- 신규 셸: PregnancyMoreView + 각 도구 detail view(예정일계산기 등 E영역 6~7종)는 별도 서브-스펙에서 구현, ④는 진입점/배치만 정의.

**상태**
- 진행(ongoing) 정상: 모든 섹션 노출. 출산CTA는 36주 미만이면 비활성(36주+ 활성), 파트너 계정은 미노출.
- 손실(miscarriage/stillbirth/terminated) "조용한 모드": QuietModeRedactor가 ④를 리스킨 — 보라/축하톤→중립 톤, 커뮤니티·응원스탬프·태교 자동추천·출산CTA·앱평가·게임화 전면 숨김. 도구함(계산기 등 진행성)·"출산했어요"도 숨김. 남는 것=정서·추억(읽기), 이전 임신 보기, 위로 카피, 회복 자원 안내. 데이터 100% 보존(삭제 불가, 일기·초음파 조용히 열람).
- pregnancyOnly: 상단 [← 육아로] 칩 숨김(나갈 곳 없음). 그 외 동일.
- both: 상단 칩 모두 노출.
- 파트너(공유 수락자) 시점: 비가역 CTA(출산했어요·임신 정보 정리) 미노출, 상단 "파트너" 역할 배지.
- 알림 권한 거부: 알림 로우 진입 시 "iOS 설정에서 허용" 배너(딥링크), 기능손실 0 안내.
- 빈/미확정: 다태아 미설정=상태칩 없음. 초대 멤버 0=함께보기 "아직 함께 보는 사람이 없어요" placeholder.
- 섹션 접힘/펼침 상태는 재진입 시 보존.
- 40주 초과: 도구함 출산가방/계획서 상단 "막달 준비" 강조(불안 카피 금지).

**상호작용**
- 섹션 헤더 탭: DisclosureGroup 펼침/접힘 토글(spring), 상태 영속.
- MoreRowLink 탭: 해당 도구/콘텐츠/설정 detail로 push(각 탭 독립 NavigationStack — cover 위 단일 스택 깊이 제한, PR#9 toolbar crash 회피).
- "← 육아로" 탭: fullScreenCover dismiss, 스크롤·선택탭 상태 자동 보존.
- "출산했어요": 36주+ & 소유자에서만 enabled → PregnancyTransitionSheet(축하·아기 정보 폼) → WriteBatch atomic 승계 → cover dismiss → 육아 착지.
- "임신 정보 정리": 회색 절제 로우 → PregnancyTerminationView 확인 Alert("기록 진행") → 즉시 조용한 모드(주수 freeze·알림 하드취소·UI 리스킨).
- "부부 공유 관리": PregnancyShareView(초대코드/멤버 추가·제거).
- 만삭 앨범 진입: 황금기 구간이면 안내 띠 노출, 직전 주 고스트 오버레이로 같은 구도 촬영 유도.
- 알림 센터 토글: 즉시 반영(다음 예약부터), "현재 N종 켜짐" 실시간 갱신, 야간 수신시각 지정 시 1회 경고.
- 감수 배지 탭(아티클): 감수자·감수일 표기 상세로.
- 모든 로우는 VoiceOver 라벨 + Dynamic Type(ViewThatFits로 trailing 배지 줄바꿈), 최소 44pt 터치.

**전이**
- ④더보기 ↔ ①여정/②기록/③검진: 하단 TabView 전환(상태 보존). 정서·추억에서 작성 저장 → ①여정 해당 주차 카드에 핀 노출(역류).
- ④ → 도구/콘텐츠 detail: push(slide). 뒤로=칩/스와이프.
- ④ "출산했어요" → PregnancyTransitionSheet(모달 sheet) → 성공 시 fullScreenCover 전체 dismiss → 육아 모드 + "임신 여정 다시보기" 링크. 크래시 시 다음 진입 PregnancyRecoveryModal로 재개.
- ④ "임신 정보 정리" → PregnancyTerminationView(push) → 확정 → ④ 포함 임신 노트 전체가 조용한 모드로 리스킨(보라→중립), both면 조용히 육아 복귀.
- 알림 권한 거부 후 시스템에서 켜고 포그라운드 복귀: 1회 "알림 켜셨네요" 부드러운 안내(④ 알림 로우 상단).
- 손실↔출산 진입 위치/톤 완전 분리: 출산=공간설정 보라 강조 능동, 손실=최하단 회색 수동.

**한국 디테일**
- 상단 칩·일기·앨범·초음파 모두 "NN주N일 + D-day" 한국 표준 병기.
- 도구함: 출산가방=한국 병원/산후조리원 입원 기준 표준 항목(병원용/조리원용 분리), 출산계획서=한국 분만 맥락(무통·회음부절개 등 옵션), 이름 짓기=부부 공동(태담 문화).
- 콘텐츠 서가: 감수 아티클에 국민행복카드·산모수첩·출산휴가/육아휴직 등 한국 행정·복지 카테고리 포함, 영양제=한국 관행(초기 엽산·중후기 철분/칼슘), 태교=클래식·동화(아빠 태담 연결), 발달 일러스트=중립적 태아 묘사(성별 단정 금지).
- 만삭 앨범 28~34주 "황금기" 안내(스튜디오 예약·상품 추천 같은 커머스 0).
- 함께보기: 카톡 친화 초대코드, "○월 출산맘" 예정월 그룹(커뮤니티). 광고0이 맘카페/경쟁앱 대비 차별점.
- 공간 설정 알림: "주 1회 + 임박 1건" 절제 default, 야간(21:00~08:00) 무음, 검진 알림에 "산모수첩·국민행복카드 챙기세요" 결합, 태동 리마인더는 28주+ & 킥세션 이력 있을 때만 노출(기본 OFF).
- 모든 의료 콘텐츠에 면책 상시, 진단/판정 카피 금지(백분위 의학판단 금지 룰 준수).
- 임신 데이터(증상·수치·일기)는 Analytics/Crashlytics·AI 인사이트 절대 미포함(safety.md).

**재사용 자산**
- PregnancyShareView (/Users/roque/BabyCare/BabyCare/Views/Settings/PregnancyShareView.swift) → 공간설정 "부부 공유 관리" 그대로 재사용(초대코드 UI는 v3 카톡 친화로 확장).
- PregnancyArchiveView + PregnancyArchiveDetailView (.../Views/Settings/PregnancyArchiveView.swift) → "이전 임신 보기" 재사용(삭제 불가 invariant 유지).
- PregnancyTransitionSheet (.../Views/Pregnancy/PregnancyTransitionSheet.swift) → "출산했어요" 진입(36주+·소유자).
- PregnancyTerminationView (.../Views/Settings/PregnancyTerminationView.swift) → "임신 정보 정리"(손실, 확인 Alert·위로 카피 그대로).
- PregnancyRecoveryModal (.../Views/Pregnancy/PregnancyRecoveryModal.swift) → 출산 전환 크래시 시 재개(④ 진입 시 트리거).
- PregnancyRecordingSheets (.../Views/Pregnancy/PregnancyRecordingSheets.swift) → 정서·추억 작성 시트.
- PregnancyDDayWidget + PregnancyWidgetDataStore → 도구함 "위젯 안내" 대상.
- pregnancy-weeks.json (37주) → 콘텐츠 서가 발달 일러스트/주차 매핑 시드.
- 신규: PregnancyMoreView 셸 + 알림 절제 센터 + E영역 도구 detail 6~7종(별도 서브-스펙). PregnancyPortalCard는 DashboardPregnancyHomeCard 격상.

**엣지**
DUPLICATE_SEE_ABOVE

---

## WeekDetailView (주차 상세) — "임신 노트" ①여정 탭의 1탭 드릴다운 목적지. 특정 임신 주차(4~40주)의 발달 콘텐츠를 한 화면에 정독하는 읽기 중심 상세. ①여정 sticky 헤더의 NN주N일 칩 또는 "오늘" 섹션 데일리팁/아기크기비교 카드를 탭하면 push로 진입. 보라/라일락 액센트, 광고0·커머스0.

**한 줄**: 이번 주 우리 아기가 어떻게 자라는지(태아 발달·엄마 변화·아빠 팁·한국 과일 비유), 이전·다음 주로 넘기며 정독하고 감수받은 아티클로 더 깊이 들어가는 주차별 발달 정독 화면.

**레이아웃**
push 목적지(부모 NavigationStack 사용, 자체 NavigationStack 금지 — swift-conventions PR #9 룰). 세로 ScrollView 단일 컬럼, 가로 16pt 패딩.

위→아래 섹션:
1) [상단 바] inline 타이틀 "NN주N일" + 우측 "오늘로" 버튼(현재 주차가 아닐 때만 노출). 좌상단 back은 시스템 기본(부모 스택).
2) [면책 배너] sticky 아님, 최상단 1회. disclaimerKey별 카피 분기(general/kick/labor). 주황 info.circle.fill + "일반 참고 자료이며 의학적 진단을 대체하지 않습니다."
3) [히어로 — 아기 크기 비교 + 발달 일러스트] 큰 카드. 발달 일러스트(주차별 SF Symbol 또는 에셋) 중앙 + "이번 주 아기는 OO만 해요"(한국 과일/채소 비유, JSON fruitSize: 라임/아보카도/바나나/옥수수/가지/수박) + NN주N일·40주 진행바·D-day 요약. 비유 옆 길이/체중 보조 캡션(있으면, 의학 면책 톤).
4) [주차 페이저 컨트롤] 히어로 하단 또는 화면 좌우 가장자리 — "‹ 19주 미리보기"·"21주 미리보기 ›" 양옆 chevron + 좌우 스와이프. 경계 처리: 4주에서 좌측 비활성, 40주에서 우측 비활성.
5) [① 태아 발달 블록] 카드. leaf/heart 아이콘 헤더 "태아 발달" + JSON milestone 본문 + (확장 콘텐츠가 있으면) 장기/감각 발달 세부 bullet.
6) [② 엄마 변화 블록] 카드. 신체 변화·증상·이번 주 권장(JSON tip 흡수) + figure 아이콘. "②기록 탭에서 증상·체중 남기기" 인라인 링크(②로 점프).
7) [③ 아빠/배우자 팁 블록] 카드(보라 톤 구분). 배우자가 이번 주 할 수 있는 일·태담 가이드. "함께보기로 응원 보내기"(④ 함께보기 딥링크) 인라인 링크.
8) [관련 감수 아티클] 가로 스크롤 또는 세로 리스트 — 이 주차에 매핑된 감수 아티클 카드 2~4개(제목·읽는시간·"의료 감수" 배지). 탭 시 아티클 상세 push.
9) [한국 검진 연결 카드] (조건부) 이 주차가 검진 윈도우면 노출 — 11~13주 NT/1차기형아, 15~20주 정밀초음파, 24~28주 임당. "이번 주 산전검진" + "③검진에서 일정·바우처 확인" 딥링크.
10) [하단] disclaimerKey가 kick(28주~)이면 "태동 기록 시작" / labor(37주~)이면 "진통 간격 기록"·"출산했어요" 보조 CTA(②/전환 시트 연결). 마지막 22~24pt bottom padding.

**컴포넌트**
- DisclaimerBanner: disclaimerKey 분기(general=일반/kick=태동·ACOG 2시간10회/labor=진통·5-1-1) 카피, 주황 톤. DashboardPregnancyView.disclaimerBanner 패턴 재사용.
- SizeComparisonHero: fruitSize(한국 과일 비유) + leaf.fill 보라/세이지 + 발달 일러스트 + 40주 ProgressView(tint primaryAccent) + NN주N일·D-day. DashboardPregnancyView.weekProgressCard·dDayCard 요소 결합 재구성.
- WeekPager: 좌우 chevron 버튼 + TabView(.page) 또는 가로 스와이프 제스처, 인접 주 미리보기 라벨. 경계 비활성 disable.
- DevelopmentBlock × 3: 동일 카드 셸(.regularMaterial, cornerRadius 16) 재사용 — 태아 발달(milestone)/엄마 변화(tip)/아빠 팁. 아이콘만 차등(heart.fill / figure.stand.dress / figure.and.child.holdinghands).
- ArticleRow/ArticleCard: 감수 배지 + 제목 + 읽는시간. (신규 — 콘텐츠 서가 ④와 공유 컴포넌트 후보)
- PrenatalLinkCard: 검진 윈도우 매핑 카드. DashboardPregnancyView.nextVisitCard 스타일 차용(stethoscope, indigo).
- InlineJumpLink: "②기록에서 남기기"/"③검진 보기"/"함께보기" 등 탭 간 딥링크 텍스트 버튼.
- "오늘로" toolbar 버튼.

색상 토큰: 임신 보라/라일락 액센트(AppColors.primaryAccent를 임신 컨텍스트에서 보라로), fruit=sageColor, 검진=indigoColor, 면책=orange. SF Symbols 100%. 외부 차트 금지(여기선 차트 불필요).

**상태**
- 정상(4~40주): JSON 항목 직접 매칭. 콘텐츠 풀 렌더.
- 보간 매칭: 정확한 주차 항목이 없을 때 last(where: { $0.week <= 현재주 }) 패턴(DashboardPregnancyView 선례)으로 가장 가까운 하위 주차 항목 표시 — JSON이 37엔트리(4~40)라 모든 주 커버되나 미래/과거 임의 주 점프 시에도 안전.
- 4주 미만 폴백: "아직 초기예요 — 4주부터 주차별 정보를 보여드려요" 안내 카드 + 페이저 좌측 비활성. 일러스트/비유 생략, tip만 일반 톤.
- 40주+ 폴백: 40주 콘텐츠 고정 표시 + "예정일을 지났어요 — 담당 의료진 안내를 따르세요" 라벨. 페이저 우측 비활성. labor disclaimer 유지.
- 다태아: pregnancy.fetusCount>1이면 "단태아 기준 정보, 다태임신은 의료진과 상의" multiFetusDisclaimer 추가(재사용).
- 아티클 0개: 관련 아티클 섹션 자체 숨김(빈 카드 금지).
- 검진 비윈도우 주차: PrenatalLinkCard 숨김.
- 일러스트 에셋 누락: SF Symbol 폴백(예: figure.and.child.holdinghands).
- 손실 모드(outcome=miscarriage/stillbirth/terminated): 주수 freeze — 이 화면은 "조용한 모드"에서 진행 UI(페이저 미래방향·태동/진통 CTA·검진카드) 전면 숨김, 과거 주차 콘텐츠는 열람만 가능, 보라/축하 톤 → 중립 톤. (IA 손실 분기 룰 준수)
- 로딩: JSON은 번들 동기 로드라 스피너 불필요. 아티클 원격 시 스켈레톤.
- 접근성: Dynamic Type/AccessibilityXXXL에서 페이저 라벨 ViewThatFits(빌드61 a11y 선례), 일러스트 decorative(VoiceOver 스킵), 비유 텍스트는 읽힘.

**상호작용**
- 좌우 스와이프 / chevron 탭: 인접 주차로 전환(애니메이션 슬라이드). 경계에서 무반응+비활성 시각.
- "오늘로" 탭: 현재 임신 주차로 즉시 복귀(과거/미래 정독 후 1탭 귀환).
- DevelopmentBlock 내 인라인 링크 탭: ②기록(증상/체중 시트) / ③검진 / ④함께보기로 딥링크 점프(부모 탭 전환). 임신 데이터는 Analytics payload 금지(safety) — 화면 진입 screen_view만, 주차/babyId 미포함.
- 아티클 카드 탭: 감수 아티클 상세 push.
- PrenatalLinkCard 탭: ③검진 해당 검진 객체로 딥링크.
- 하단 CTA: kick→②태동 시트(KickSession), labor→진통타이머/PregnancyTransitionSheet("출산했어요").
- back: 부모 스택 pop, ①여정 스크롤 위치 보존.
- 햅틱: 주차 전환 시 가벼운 selection 햅틱(과하지 않게).

**전이**
- 진입(in): ①여정 NN주N일 헤더 칩 / 데일리팁·크기비교 카드 / ④서가 발달 일러스트 항목 탭 → push(슬라이드). 위젯·푸시 딥링크는 fullScreenCover(임신노트)→①여정→해당 주차 WeekDetailView 도달.
- 주차 간(intra): 스와이프/chevron → 같은 화면 콘텐츠 cross-slide 교체(새 push 아님, 단일 스택 깊이 유지로 PR#9 toolbar crash 회피).
- ②③④ 점프: 부모 탭바 전환(WeekDetailView pop 후 해당 탭). dismiss는 단일 가역 — 다시 ①여정 진입 시 마지막 본 주차 복원.
- 출산 CTA(out): PregnancyTransitionSheet sheet presentation → WriteBatch 전환 → fullScreenCover dismiss → 육아 착지.
- 손실 전환 발생 시: 즉시 리스킨(보라→중립), 미래 페이징 차단.

**한국 디테일**
- NN주N일 표기 + D-day(예: 24주3일·D-112). PregnancyDateMath/PregnancyViewModel.currentWeekAndDay·dDay 재사용.
- 한국 과일/채소 크기 비유: pregnancy-weeks.json fruitSize 그대로(양귀비씨→라임→복숭아→바나나→옥수수→가지→근대→수박). 서구 비유 금지.
- 한국 산전검진 주차 매핑(PrenatalLinkCard): 11~13주 NT/1차 기형아, 15~20주 정밀초음파(20주 milestone에 이미 명시), 24~28주 임당검사(28주 ACOG 태동 권장과 동거). 국민행복카드 바우처·산모수첩 미러는 ③검진으로 연결만(이 화면은 안내 링크).
- 태교: 24주 milestone "엄마 목소리 들음"+tip "태담·음악"을 아빠 팁/엄마 변화 블록에 자연 반영.
- 만삭: 37주 "만삭(term)" milestone + labor disclaimer.
- 태동: 28주 disclaimerKey=kick → 2시간 10회 ACOG 가이드 카피 + 태동 기록 CTA.
- 진통: 37주+ disclaimerKey=labor → 5-1-1(5분 간격·1분 지속·1시간 지속) 진통 기록 가이드.
- 면책 문구 필수(의학 데이터 룰), 의료 감수 확보됨 — 아티클 "의료 감수" 배지.

**재사용 자산**
- pregnancy-weeks.json (37엔트리 4~40주, week/fruitSize/milestone/tip/disclaimerKey) — 콘텐츠 1차 소스. milestone=태아발달, tip=엄마변화/주차권장, fruitSize=크기비유, disclaimerKey=하단 CTA·면책 분기.
- DashboardPregnancyView: weekProgressCard(40주 ProgressView+fruit+milestone+tip 레이아웃) → SizeComparisonHero+발달블록으로 분해 재사용. dDayCard(D-day 56pt rounded), disclaimerBanner(주황), multiFetusDisclaimer(보라), nextVisitCard(stethoscope/indigo) → PrenatalLinkCard 스타일, birthCTABanner+showTransitionSheet → 하단 출산 CTA.
- PregnancyViewModel(currentWeekAndDay/dDay/activePregnancy/fetusCount/checklistItems/prenatalVisits) — 헤더·경계 판단.
- PregnancyRecordingSheets / KickSession — 하단·인라인 기록 점프 대상(②).
- PregnancyTransitionSheet — labor 구간 "출산했어요".
- PregnancyDDayWidget/PregnancyWidgetDataStore — 딥링크 진입원.
- AppColors(primaryAccent=임신 보라, sageColor, indigoColor, warmOrangeColor), 카드 셸 .regularMaterial+cornerRadius 16~20 토큰.
- IA.md 인벤토리 #6 WeekDetailView "재사용"으로 명시됨 — DashboardPregnancyView 승격분(PregnancyJourneyView)의 드릴다운 자식.
신규 필요: ArticleRow/ArticleCard(감수 아티클), WeekPager(주차 스와이프), 주차별 발달 일러스트 에셋(없으면 SF Symbol 폴백). 한국 검진×주차 매핑 큐레이션 데이터는 ③검진과 공유(IA "PO 결정 필요 — 별도 페이즈").

**엣지**
- 4주 미만/40주+ JSON 경계: last(where:<=) 보간 + 전용 폴백 카드, 페이저 방향 비활성.
- JSON 디코드 실패: weekInfos=[] → 콘텐츠 블록 숨김 + "정보를 불러오지 못했어요" + D-day/주차 헤더만 유지(앱 크래시 금지).
- 다태아: multiFetusDisclaimer 노출, 단태아 기준 명시.
- 손실 후 진입: 진행 UI 전면 숨김·중립 리스킨·과거만 열람(no_data_deletion, 손실 데이터 Analytics/ML 금지).
- 예정일 미설정: dDay nil → "예정일 미설정" 안내, 주차 헤더는 LMP 기반 추정 또는 생략.
- 임신 데이터 Analytics/Crashlytics 금지: screen_view에 주차·태명·babyId 등 민감 파라미터 미포함.
- 중첩 NavigationStack 금지(PR#9): 자체 NavigationStack 두지 말 것 — 부모 ①여정 스택 사용, 주차 전환은 push 아닌 in-place 교체.
- 아티클/일러스트 원격 자산 누락: 섹션 숨김 또는 SF Symbol 폴백, 빈 카드 금지.
- AccessibilityXXXL: 페이저 라벨·비유 텍스트 truncate 방지 ViewThatFits(빌드61 a11y 회귀 선례).
- 검진 윈도우 경계(예: 정확히 13주0일 vs 14주0일): 포함/제외 규칙을 ③검진 매핑과 단일 소스로 일치(drift 방지).

---

## PregnancyPortalCard (임신노트 진입문) + 공간 전환 셸 — both 케이스의 육아 홈 최상단 단일 진입 카드, 탭 시 fullScreenCover로 임신 노트(보라 공간)를 띄우고 [←육아로] 칩으로 닫아 육아 홈(핑크 공간)으로 정확히 복귀하는 "평행공간 2개 + 웜홀 1개" 메커닉. pregnancyOnly는 카드 없이 임신 노트가 곧 루트(닫기·칩 숨김).

**한 줄**: 육아 홈 맨 위 "🤰둘째 24주·D-112 ›" 카드 한 장을 누르면 보라색 임신 노트가 통째로 덮어 열리고, 왼쪽 위 [←육아로] 칩으로 닫으면 보던 육아 화면 그대로 돌아온다 — 두 공간은 서로 색·칩·스크롤 위치까지 각자 기억한다.

**레이아웃**
[A] both 케이스 — 육아 홈(DashboardView) 위→아래 섹션:
  1. (상단 글로벌) 오프라인/동기화 배너 — 기존 ContentView 최상단 유지, 공간 무관.
  2. ★PregnancyPortalCard — 육아 홈 ScrollView의 "최상단 섹션"(BadgeHomeStrip보다 위, 첫 카드). 좌우 16pt 인셋, 카드 단독 1행.
     내부 좌→우 HStack(spacing 14): [태아 아이콘 배지 48x48 라운드12, 보라 틴트 배경] · [VStack(좌측정렬): 1행=태명+주차칩+D-day 배지 / 2행=다음 검진·체중델타 메타] · [Spacer] · [chevron.right "›" 보라 tertiary].
  3. 그 아래 기존 육아 콘텐츠(요약/숏컷/인사이트…) 변경 없음.
[B] 임신 노트 fullScreenCover (PregnancyNoteRootView) 위→아래:
  1. 상단 공간칩 바(both 전용, sticky): 좌 [← 육아로] pill(보라 외곽선) + 우측 "🤰 임신 24주" 라벨칩. pregnancyOnly에서는 이 줄 전체 숨김.
  2. 4탭 TabView(보라 액센트): ①여정 ②기록 ③검진 ④더보기.
[C] pregnancyOnly 케이스: 카드/커버/칩 없음 — 임신 노트가 NavigationStack 루트로 직접 렌더, 좌상단 닫기 0.

**컴포넌트**
PregnancyPortalCard(신규, DashboardPregnancyHomeCard 격상):
 - 태아 아이콘 배지: ZStack(라운드12 보라 틴트 0.15 배경 + SF Symbol figure.and.child.holdinghands, 보라). ※현 자산은 figure.maternity + primaryAccent(핑크)를 쓰므로 v3에서 심볼·색 둘 다 교체.
 - 태명 라벨: "둘째"/태명 우선, 없으면 "임신 중"(.subheadline semibold).
 - 주차칩: "임신 24주"(currentWeekAndDay 기반, 일 생략 가능). 다태아면 "쌍둥이 24주".
 - D-day 배지(Capsule, 흰 글자): D-112/오늘!/D+n. n<0(예정일 초과)만 경고 오렌지, 그 외 보라.
 - 메타행: stethoscope "검진 D-2"(가장 임박 미완 visit) + scalemass "+6.2kg"(prePregnancyWeight 대비, lb→kg 환산). 데이터 없으면 해당 항목 생략(빈 공간 0).
 - chevron "›"(진입 affordance).
 - (옵션) 라이브 펄스/태동 점: 오늘 태동 기록 있으면 작은 보라 dot.
공간칩 바: BackToBabyChip([← 육아로], 탭=dismiss) + SpaceIdentityChip("🤰 임신 N주", 비탭/현위치 표시).
재사용 셸: PregnancyNoteRootView(4탭) / PregnancyJourneyView(DashboardPregnancyView 승격).
알림 출처 prefix 컴포넌트: "[둘째 임신]"/"[로아(첫째)]" 라벨(푸시·로컬 알림 제목 앞).
v2→v3 코치마크: PortalUpgradeCoachmark(1회, "임신 카드가 임신 노트 입구로 커졌어요").

**상태**
진입점 가시성(AppContext × 카드/커버/칩 매트릭스 — XCUITest 전수 고정):
 - empty: 카드✕ 커버✕ 칩✕ (온보딩 "임신 중이에요" 진입만).
 - babyOnly: 카드✕ 커버✕ 칩✕ (임신 진입점 0 — 둘째 임신 시 등록은 '아기 추가' 형제 위치).
 - pregnancyOnly: 카드✕(루트가 곧 노트) 커버✕ 칩✕(닫을 곳 없음).
 - both: 카드● 커버●(닫힘/열림 토글) 칩●.
PortalCard 데이터 상태: 로딩(activePregnancy nil + 로드중)=스켈레톤 1행 / 정상=풀 카드 / 메타 부분결손=해당 칩만 생략 / EDD 미설정=주차칩 "임신 중"·D-day 숨김.
공간 상태(각자 보존, 동시 1개만 표시): 육아 공간=선택탭+스크롤위치 / 임신 공간=마지막 본 4탭 인덱스+여정 주차 스크롤. 커버 재열림 시 마지막 본 주차 그대로.
주수 freeze: 손실 후(outcome≠ongoing) PortalCard는 D-day/주차 진행 정지 또는 노출 종료(조용한 모드 전이).
강제종료 복구: transitionState=pending이면 PortalCard 자리에 "출산 정리 이어하기" 또는 PregnancyRecoveryModal 우선.

**상호작용**
PortalCard 탭: 햅틱(light) → .fullScreenCover(임신 노트) 위로 슬라이드(시스템 cover 전이). 카드 자체는 NavigationLink 아님 — 커버 트리거(현 자산의 NavigationLink push를 v3에서 fullScreenCover presentation으로 교체).
[← 육아로] 칩 탭: 커버 dismiss → 떠났던 육아 홈/탭/스크롤 그대로 복귀(상태 자동 보존, 별도 저장 로직 불필요).
스와이프-다운 dismiss: 기본 차단 또는 칩과 동일 처리(공간 전환은 명시 제스처 1개로 한정 — 오조작 방지). 결정 필요시 차단 권장.
공간칩(우측 "🤰 임신 N주"): 비인터랙티브(현위치 표지). 길게눌러도 무동작.
딥링크(위젯 D-day/푸시 검진): 인증·both 확인 후 곧장 fullScreenCover 열고 목표 탭/카드로 점프(예: 검진 푸시→③검진 다음 객체). dismiss 동작 동일.
알림 탭: 출처 prefix로 공간 직행 — "[둘째 임신]…"=커버 열림, "[로아(첫째)]…"=육아 홈 해당 탭.
QuickLog 후 복귀: 임신 노트 내 태동/체중 저장→①여정 역류, 칩으로 나가도 다시 들어오면 갱신 반영.
코치마크: both 첫 진입 1회 PortalCard 위 말풍선, 탭 1회로 소진(UserDefaults).

**전이**
앱 진입→공간: AppContext.resolve(babies,pregnancy) switch(default 금지) — both만 PortalCard+커버 게이트 부착. 신규 전역 상태머신(activeSpace) 도입 금지(빌드56 진입점 orphan/휘발 회귀 차단). 커버 표시는 단일 @State showPregnancyNote 바인딩.
육아→임신: PortalCard 탭/딥링크 → showPregnancyNote=true → fullScreenCover. 색 정체성 핑크#FF9FB5→보라/라일락 전환은 커버 경계에서 즉시(애니메이션 없이 공간이 통째로 바뀜).
임신→육아: 칩 dismiss → showPregnancyNote=false → 육아 TabView 그대로.
출산 전환(①막달 CTA→PregnancyTransitionSheet→WriteBatch): outcome=born 후 AppContext 자연 재해석(both→both[임신1건 종료] 또는 →babyOnly) → 커버 자동 dismiss → 육아 착지 + 출산축하 + "임신 여정 다시보기" 링크. 크래시 시 PregnancyRecoveryModal 재개.
손실 전환(④설정→PregnancyTerminationView): 조용한 모드 — PortalCard에서 D-day/축하톤 제거, 보라→중립 톤 리스킨, both는 조용히 육아 복귀(둘째 상실이 첫째 화면 침범 금지). requestReview·업셀 억제.
pregnancyOnly→born: 임신 노트 루트가 육아 5탭 루트로 자연 전환(커버 개념 없음).

**한국 디테일**
- 표기: "임신 24주"(NN주, 일 표기는 카드에선 생략·여정 헤더에서 NN주N일) + "D-112"(예정일까지) / "오늘!" / 초과 시 "D+n"(오렌지).
- 다태아: "쌍둥이/세쌍둥이 NN주"(fetusCount 반영).
- 검진 메타: 한국 산전검진 일정 기반 "검진 D-2"(11~13주 NT/1차 기형아·15~20주 정밀초음파·24~28주 임당이 ③검진 자동매핑되어 그중 임박 1건 표시).
- 체중: kg 단위 한국 기본, "+6.2kg"(prePregnancyWeight 대비).
- 알림 출처 라벨: "[둘째 임신] 24주 검진 D-2" vs "[로아(첫째)] 수유 알림" — 둘째·첫째 구분이 한국 다자녀 가정 혼동 차단.
- 태교/태담: 카드 태아 아이콘은 태명 친화(태명 우선 노출).
- 광고·커머스 0: 카드/커버 어디에도 배너·구매 CTA 금지. 바우처(국민행복카드)는 ③검진 정보카드로만(진입문엔 없음).
- 의료 면책: 진입문은 수치 미표시(검진 D-day·체중델타만), 임상 판단 텍스트 0.

**재사용 자산**
기존 그대로:
 - /Users/roque/BabyCare/BabyCare/Views/Pregnancy/PregnancyTransitionSheet.swift (출산 승계)
 - /Users/roque/BabyCare/BabyCare/Views/Pregnancy/PregnancyRecoveryModal.swift (pending orphan 복구 — ContentView L116 .sheet 이미 연결)
 - /Users/roque/BabyCare/BabyCare/Views/Settings/PregnancyTerminationView.swift (손실 분기)
 - /Users/roque/BabyCare/BabyCareWidget/PregnancyDDayWidget.swift + /Users/roque/BabyCare/BabyCareWidget/Provider/PregnancyWidgetDataStore.swift (딥링크 진입)
 - /Users/roque/BabyCare/BabyCare/Views/Pregnancy/PregnancyRegistrationView.swift (empty 온보딩 등록)
 - KickSession.swift / pregnancy-weeks.json(37주) / PregnancyDDayWidget(D-day 계산)
격상/승격:
 - PortalCard ← /Users/roque/BabyCare/BabyCare/Views/Dashboard/DashboardPregnancyHomeCard.swift (현재 additive 카드. v3에서 NavigationLink→fullScreenCover 트리거로, figure.maternity→figure.and.child.holdinghands, AppColors.primaryAccent(핑크)→보라 토큰으로 교체)
 - PregnancyJourneyView(①여정) ← /Users/roque/BabyCare/BabyCare/Views/Dashboard/DashboardPregnancyView.swift
가팅 재사용: /Users/roque/BabyCare/BabyCare/Utils/AppContext.swift(4-state resolve) — 현 ContentView.swift L68-81 switch에 both 분기만 커버 게이트 추가, 신규 상태머신 없음.
디자인 토큰: /Users/roque/BabyCare/BabyCare/DesignSystemV2/DS2.swift — 현재 pregnancy 전용 색 없음(pumping=#B56FD1, tintPurple=pastelPurple만 존재). 신규 DS2.Color.pregnancy(보라/라일락) 토큰 추가 필요. 육아=AppColors.primaryAccent #FF9FB5 유지.

**엣지**
1. ★색 정체성 충돌(현 버그): DashboardPregnancyHomeCard가 임신에 primaryAccent(핑크)·warmOrange를 씀 → v3 "보라/라일락" 정체성과 정면 위반. PortalCard 격상 시 보라 토큰 신설+전면 교체 필수(안 하면 두 공간 색 구분 0).
2. fullScreenCover 위 4탭 각자 NavigationStack → PR #9 toolbar crash 핫스팟 재발 위험. 커버 위 단일 스택 깊이 제한+toolbar 전수 QA.
3. 카드↔커버 트리거를 NavigationLink(현 자산)로 두면 육아 TabView NavigationStack 안에서 push됨 → 공간 분리 깨짐. 반드시 presentation(fullScreenCover)으로.
4. both→born 전환 중 커버 열린 채 outcome 변경 시 커버가 "사라진 임신"을 렌더 → 전환은 WriteBatch 후 커버 dismiss를 강제(transitionState=pending 가드).
5. pregnancyOnly에서 실수로 칩/닫기 노출 시 "나갈 곳 없는데 닫기" orphan(빌드56 유형). 매트릭스 XCUITest로 고정.
6. 다중 임신(드묾) 또는 활성 임신 2건: PortalCard는 1장 가정 — 활성 1건 invariant(중복 생성 방지) 확인.
7. EDD 미설정/lmp만 있음: 주차칩만, D-day 숨김(빈 배지 금지).
8. 손실 후 PortalCard 잔존: outcome≠ongoing이면 진행 UI 즉시 숨김(주수 freeze) — 첫째 육아 화면에 둘째 상실 흔적 침범 금지.
9. 위젯 딥링크가 both 아닌 상태(예: 손실로 babyOnly 전이)로 도착: 커버 안 열고 무시 또는 안내 — guard(인증+both+ongoing).
10. 알림 prefix 누락 시 둘째/첫째 혼동 → prefix 강제(테스트 고정).
11. 임신 데이터 Analytics/Crashlytics 금지(safety.md): PortalCard 노출/탭 계측 시 임신 식별자·주차·태명 payload 금지(screen_view 일반 이벤트만).
12. 스와이프-다운 dismiss와 칩 dismiss 이중 경로 → 상태 보존 불일치 가능. dismiss 단일화(차단 권장).
13. v2 additive 카드에 익숙한 산모: "카드가 입구로 격상" 코치마크 1회 없으면 사라진 것으로 오인.

---

## 출산 전환 (Birth Transition) — "임신 노트" 막달 단계에서 임신→육아 모드로 넘어가는 1회성 전환 플로우. 진입 표면 3종: ①여정 탭 막달 구간의 "출산했어요" 인라인 CTA(D-7 이후 또는 36주+ 노출, dismiss 가능) ②출산 완료 입력 시트(PregnancyTransitionSheet) ③전환 미완료 복구 모달(PregnancyRecoveryModal). 착지: 육아 모드 자동 전환 + 출산 축하 + "임신 여정 다시보기" 링크.

**한 줄**: 막달(D-7~/36주+)에만 조용히 등장하는 "출산했어요" CTA → 아기 정보 한 폼 입력 → 멱등 전환 → 육아 모드 착지 + 축하 + 여정 다시보기.

**레이아웃**
[A] 여정 탭 막달 CTA (인라인 카드, 상시배너 아님)
- 위치: 여정(①탭) 주차 타임라인 "척추" 상단, 오늘 카드 바로 아래에 라일락 톤 카드로 1장만 삽입. 노출 조건 미충족 시 슬롯 자체가 없음(빈 공간 없음).
- 섹션 위→아래:
  1. 헤더 라인: figure.maternity 아이콘(보라) + "혹시 아기를 만나셨나요?" 타이틀(headline) + D-day 캡션(D-3 / 오늘! / D+2 형태)
  2. 본문 1줄: "출산하셨다면 육아 기록으로 전환해 드릴게요. 임신 여정은 안전하게 보관됩니다."(subheadline, secondary)
  3. 액션 행(가로 3-버튼, ViewThatFits로 세로 폴백):
     · 주 CTA "출산했어요"(filled, 보라 캡슐, 가장 큼)
     · 보조 "예정일 조정"(tinted, 라일락) — eddHistory append 경로(여정 내 EDD 편집 시트)
     · 약 dismiss "아직이에요"(plain, secondary 텍스트) — 카드 접기
- 카드 우상단에 작은 xmark(.tertiary) — "아직이에요"와 동일 동작(스누즈).

[B] 출산 완료 입력 (PregnancyTransitionSheet, 재사용 자산 — 현재 sheet detent → 본 IA에서는 임신 노트 컨텍스트 위 .sheet로 모달 적층)
- NavigationStack, 타이틀 "출산 완료 등록"(inline), 좌상단 "취소"(form 단계에서만).
- Form 섹션 위→아래:
  1. 안내 배너 섹션: heart.fill(보라) + "아기 정보를 입력해 주세요. 임신 기록은 아카이브로 보관됩니다." (라일락 10% 배경 라운드)
  2. "아기 이름" — TextField, 태명(babyNickname) prefill
  3. "성별" — segmented Picker, ultrasoundGender prefill(남아→male/여아→female, 미상→male 기본·강조 없음)
  4. "실제 출생일" — DatePicker(.date, ...Date() 상한, ko_KR locale)
  5. "출생 정보 (선택)" — 체중(kg) / 키(cm) decimalPad TextField 2행, 빈 값 허용
  6. (다태아 한정) "아기 수" — fetusCount≥2일 때만 노출되는 Stepper(기본=fetusCount, 1~5). 단태아면 섹션 없음.
  7. 제출 섹션: "출산했어요" full-width 버튼(이름 비면 disabled·회색, 유효 시 보라). 다태아면 "아기 N명 등록하기"로 라벨 변형.
- presentationDetents [.medium, .large], dragIndicator visible, cornerRadius 28.

[C] 출산 축하 + 착지 (전환 성공 후)
- 시트 내 success 단계(2초): checkmark.circle.fill(72pt, 보라) + "아기 등록이 완료되었어요!"(title2.bold) + 아기 이름(다태아면 "OO 외 N명").
- 시트 dismiss 후 육아 홈 위에 출산 축하 오버레이(소박한 confetti/하트, ROA 핑크 #FF9FB5 + 라일락 그라데이션 1회) + 하단 스낵바/카드 "임신 여정 다시보기"(아카이브 딥링크).

[D] 복구 모달 (PregnancyRecoveryModal, 재사용 자산)
- 중앙 정렬: exclamationmark.triangle.fill(56pt, orange) + "이전에 시작하신 전환이 멈춰 있어요."(title3.bold) + "이어서 완료하시겠어요?"(body, secondary)
- 2버튼 세로: "이어서 완료"(보라 filled) → PregnancyTransitionSheet 재호출 / "취소"(plain, secondary) → transitionState 필드만 제거(문서 보존). interactiveDismissDisabled(스와이프 닫기 차단, 명시적 선택 강제).

**컴포넌트**
재사용(기존): PregnancyTransitionSheet(폼·confirm alert·success/failure 3-phase·prefill init) / PregnancyRecoveryModal(pending orphan 재개) / DashboardPregnancyHomeCard(D-day 뱃지·다음 검진·체중델타 패턴 — CTA 카드 비주얼 참조) / PregnancyDDayWidget(D-day 산식 일치) / pregnancy-weeks.json(36주+ 막달 판정 보조).
신규(이번 화면 추가):
- "BirthTransitionCTACard"(여정 탭 인라인 카드, dismiss 가능·3-버튼·노출게이트) — 신규.
- TransitionSheet 폼 확장: "출생 정보(체중 kg/키 cm)" 선택 섹션 + 다태아 "아기 수" Stepper(현재 자산은 이름·성별·출생일만 보유 → 확장 필요).
- "BirthCelebrationOverlay"(착지 축하 애니메이션 1회) + "임신 여정 다시보기" 스낵바/링크 — 신규.
공통 토큰: AppColors.primaryAccent(보라/라일락 임신 액센트), SF Symbols(figure.maternity·heart.fill·checkmark.circle.fill·stethoscope·scalemass·xmark), Apple 기본 Form/Picker/Stepper/DatePicker, ROA 라운드 16/28.

**상태**
CTA 카드: [hidden](게이트 미충족) / [shown](D-7~ 또는 36주+) / [snoozed](사용자 "아직이에요"·xmark → 해당 세션·일정기간 접힘, 슬롯 제거).
TransitionSheet 단계머신: form → (confirm alert) → success(2초 표시 후 자동 dismiss) / failure(메시지 + "다시 시도" → form 복귀). 폼 내부: 이름 비면 제출 disabled.
복구 모달 노출 조건: transitionState == pending AND 최종 갱신 30초 경과(중간 실패한 단일 orphan). pending 1개 → 이 모달, 2개+ → 설정 인라인 배너(별도). 처리: 이어서 완료 / 취소(rollback, 문서 보존).
전환 멱등 상태: 전환 시작 시 markTransitionPending(단일 write) → WriteBatch(Baby 생성 + 임신 archivedAt/transitionState=completed) 원자 커밋 → 성공 시 activePregnancy=nil + 임신 위젯 clear. 중간 끊김 시 [D] 복구.
착지 컨텍스트: 전환 후 AppContext 자동 재해석 — both(육아+임신)였다면 임신만 사라지고 육아 유지 / pregnancyOnly였다면 babyOnly로 전환되어 임신 노트 루트가 육아 홈으로 교체.

**상호작용**
- "출산했어요"(CTA/폼): 폼 → 확인 alert "출산 완료로 전환하시겠어요?"("되돌리려면 설정>이전 임신에서 복구") → "전환 진행"(destructive)으로만 실행. 오발 방지 2단계 확인.
- "예정일 조정": 전환 안 함. EDD 편집 시트로 분기(eddHistory append, 덮어쓰기 금지) — "아직 출산 전인데 예정일이 지났다"는 막달 흔한 케이스 흡수.
- "아직이에요"/xmark: 전환 보류, 카드 스누즈. 데이터 무변경. 다음 노출 조건 충족 시 재등장(상시 노이즈 방지).
- 성별/이름 prefill: ultrasoundGender·babyNickname 자동 채움, 사용자 수정 가능. 미상 성별은 기본값을 강조 없이 제시.
- 다태아: fetusCount≥2면 "아기 수" Stepper + 라벨 "아기 N명 등록하기". 1명 입력 폼으로 N명 일괄 생성(이름은 베이스+자동 번호 또는 개별 입력 — 본 화면에선 단순화: 동일 정보로 N명, 출생 후 각 아기 이름 설정 안내).
- 성공: success 화면 2초 자동 → dismiss → 육아 홈 착지 + 축하 1회 + "임신 여정 다시보기" 링크 노출.
- 실패: failure 화면 + "다시 시도"(form 복귀, 데이터 유지). 자동 재시도 금지.
- 복구 모달: "이어서 완료"는 사용자 명시 탭 필수(자동 retry 금지). "취소"는 transitionState만 제거(ongoing 복원, 문서 절대 삭제 안 함).

**전이**
- 여정 탭 CTA "출산했어요" → PregnancyTransitionSheet(.sheet, medium/large detent) 적층.
- 시트 form → confirm alert → (진행) markTransitionPending → transitionPregnancyToBaby(WriteBatch) → success(2초) → dismiss.
- dismiss 후 임신 노트 컨텍스트: pregnancyOnly였으면 임신 노트 루트가 사라지고 육아 홈이 앱 루트로(닫기 1번=육아 복귀 IA와 정합) / both였으면 fullScreenCover 임신 노트 자동 닫힘 + 육아 홈 착지(PortalCard에서 임신 칩 사라짐).
- 착지 직후 BirthCelebrationOverlay 1회 재생 → 사라진 뒤 "임신 여정 다시보기" 링크 잔존(아카이브 PregnancyArchiveView 딥링크, 더보기 탭 서가/추억에도 영구 보관).
- 앱 재진입 시 transitionState=pending orphan 감지 → PregnancyRecoveryModal → "이어서 완료" → PregnancyTransitionSheet 재호출(동일 전환 경로) / "취소" → ongoing 복원.

**한국 디테일**
- 막달 판정: D-7 이후 또는 36주+(pregnancy-weeks.json 만삭 구간 정합). NN주N일·D-day(D-7/오늘!/D+2) 한국식 표기. 예정일 초과(D+) 흔함 → 카드에 D+N + "예정일 조정" 동거로 자연 흡수.
- 출생 정보: 체중 kg / 키 cm(한국 산부인과 표기), decimalPad. 다태아(쌍둥이·삼둥이) fetusCount 1~5 — 한국 난임시술 증가로 다태아 비중 고려.
- 성별: ultrasoundGender(남아/여아) 한글 라벨 → Baby.Gender 매핑. 출생 전 성별 미고지 병원 케이스 위해 미상 허용.
- 전환 후 임신 데이터는 산모수첩처럼 아카이브 영구 보관("다시보기"). 임신 종료(유산/사산/중지)는 이 축하 플로우와 절대 혼동 금지 — 설정>임신 관리>임신 종료 심층 경로로 분리(의료·정서 민감).
- 카피 톤: 축하는 과하지 않게(난임·고위험 임신 사용자 정서 배려), 의료 단정 표현 배제. 광고0·커머스0 유지(축하 화면에 상품/쿠폰 금지).

**재사용 자산**
PregnancyTransitionSheet(/Users/roque/BabyCare/BabyCare/Views/Pregnancy/PregnancyTransitionSheet.swift) — 폼·2단계 confirm alert·success(2초)/failure 3-phase·prefill init(babyNickname/ultrasoundGender) 그대로 재사용, 본 화면은 "출생 정보(체중/키)"+다태아 "아기 수" 섹션만 확장.
PregnancyRecoveryModal(.../PregnancyRecoveryModal.swift) — pending orphan 재개, "이어서 완료"는 동일 시트 재호출, "취소"는 transitionState 필드만 제거(문서 보존)·interactiveDismissDisabled. 그대로 재사용.
PregnancyViewModel.transitionToBaby/terminatePregnancy(.../ViewModels/PregnancyViewModel.swift:465·491) — markTransitionPending→WriteBatch 멱등 경로(중복 아기 방지) 재사용.
DashboardPregnancyHomeCard(.../Dashboard/DashboardPregnancyHomeCard.swift) — D-day 뱃지 산식·라일락 카드 비주얼·다음 검진/체중델타 레이아웃을 막달 CTA 카드 디자인 레퍼런스로 차용.
PregnancyDDayWidget(/Users/roque/BabyCare/BabyCareWidget/PregnancyDDayWidget.swift) — D-day 계산 일관성 참조.
pregnancy-weeks.json(.../BabyCare/Resources/pregnancy-weeks.json) — 36주+ 막달 게이트 판정 보조.
Pregnancy 모델(.../Models/Pregnancy.swift) — fetusCount/ultrasoundGender/babyNickname/transitionState/eddHistory 필드가 CTA·폼 prefill·다태아·EDD 조정의 데이터 근거.

**엣지**
- 예정일 경과(D+): CTA 계속 노출하되 "예정일 조정"으로 EDD append 경로 보장(덮어쓰기 금지). 과거 EDD가 음수 D여도 카드 깨지지 않게 D+N 표기.
- 이름 미입력: 제출 disabled. 강제 진행 시 babyNickname 폴백("우리 아기").
- ultrasoundGender 미상: 기본 male 매핑이나 시각적 강조 없이, 사용자 수정 유도.
- 다태아 fetusCount≥2: "아기 수" Stepper 노출, N명 일괄 생성. 1명으로 줄여 등록하는 케이스(한 아기만 출산)도 허용.
- 전환 중 앱 종료/네트워크 끊김: transitionState=pending orphan → 30초 경과 후 PregnancyRecoveryModal. 자동 재시도 절대 금지(사용자 명시 탭).
- 멱등성: markTransitionPending 후 WriteBatch 재실행이 중복 Baby 생성 안 하도록 transitionState 가드(이미 completed면 no-op). "이어서 완료"가 두 번째 아기를 만들지 않게 보장.
- 취소(rollback): transitionState 필드만 FieldValue.delete()로 제거, 임신 문서·KickSession·검진·체중 데이터 절대 삭제 금지(데이터 삭제 금지 룰).
- both vs pregnancyOnly 착지 분기: 전환 후 AppContext 재해석로 임신 UI만 제거, 기존 육아 데이터/타 아기 영향 없음. "임신 여정 다시보기"는 양쪽 모두 보존.
- 임신 종료(유산/사산/중지)와 출산 축하 경로 혼선 방지: 출산 CTA는 figure.maternity·축하 톤, 종료는 설정 심층·중립/위로 톤으로 완전 분리. CTA에서 종료 진입 불가.
- 접근성: 3-버튼 CTA는 ViewThatFits 세로 폴백(AccessibilityXXXL truncate 방지, 기존 H-8 선례). 축하 애니메이션은 Reduce Motion 시 정적 폴백.
- 임신 데이터 Analytics/Crashlytics payload 금지 — 전환 이벤트 로깅 시 babyName/gender/주차 등 민감정보 미포함.

---

## 손실 경로 (유산/사산/임신중지) — "임신 노트" 종료 + 조용한 모드(Quiet Mode) 진입/유지 플로우. ④더보기 > 공간 설정 깊은 곳의 "임신 정보 정리" 라벨에서 시작 → PregnancyTerminationView(유형 선택·확인) → 조용한 모드(주수 freeze·알림 하드취소·진행 UI 전면 숨김·차분 중립톤 리스킨·위로 메시지·선택적 추모 기록). both 사용자는 종료 후 조용히 ④에서 [←육아로]로 복귀(첫째 화면 무침범). 광고 0·커머스 0·앱평가/업셀 억제. 의료감수 확보.

**한 줄**: 상실을 겪은 사용자가 강요·축하톤·D-day 없이 임신 공간을 조용히 닫고, 모든 데이터는 100% 보존한 채 차분한 회고/추모 공간으로 전환하는 절제된 경로.

**레이아웃**
전체는 3개의 연속 화면 + 1개의 결과 상태(조용한 모드)로 구성된다. 색은 시작 시점부터 보라/라일락 액센트가 사라지고 SF 기본 .secondary(중립 그레이) 톤으로 점진 리스킨된다. D-day·축하·진행률·이모지 장식은 어디에도 없다.

[화면 A] ④더보기 > 공간 설정 — 진입 지점(절제된 라벨)
위→아래 섹션:
1) (설정 상단 일반 항목들: 알림·공유·HealthKit 등 — 본 명세 범위 밖, 기존 유지)
2) 화면 최하단, 시각적으로 분리된 마지막 섹션 "임신 정보 정리"
   - Form Section 헤더 없이 단독 row, 라벨 텍스트 "임신 정보 정리" (D-day/축하/"종료"/"삭제" 단어 회피, 절제 라벨)
   - 우측 chevron, 아이콘은 SF Symbol "folder" 계열 .secondary 색 (위험·경고 아이콘 금지)
   - row 아래 caption: "임신을 더 이어가기 어려운 상황을 조용히 정리합니다." (작게, .secondary)
   - 이 섹션은 스크롤 최하단 + 다른 설정과 한 칸 띄워 배치 → 우발적 탭 방지

[화면 B] PregnancyTerminationView(form phase) — 유형 선택 + 위로 (재사용·리스킨)
위→아래 섹션:
1) 위로 카드 (listRowBackground rounded, .secondary.opacity(0.08))
   - SF "heart"(테두리, 채움 X) .secondary + 한 줄 위로 문구
   - 카피: "힘든 시간을 보내고 계신다면 진심으로 위로의 말씀을 드립니다. 기록은 언제든 이전 기록에서 확인하실 수 있습니다."
2) 유형 선택 Section("어떻게 정리할까요" — '종료 유형'보다 부드럽게)
   - Picker .inline, 항목: 유산 / 사산 / 임신 중지 (출산은 이 화면에 절대 미노출 — 별도 PregnancyTransitionSheet 소관)
   - 유산<20주 / 사산≥20주의 임상 경계는 내부 처리. 사용자에게 "20주 미만/이상" 같은 임상 드롭다운 강요 금지 — 단순 3택만 노출
   - 임신 주차에 따라 기본 선택을 자동 추정(예: freeze된 주수<20→유산 default)하되 변경 자유
3) 확인 버튼 Section
   - full-width "정리하기" 버튼, 배경 .secondary.opacity(0.7) (보라/destructive red 아님), 흰 텍스트
   - 탭 → 확인 alert (화면 B' 참조)
navigationTitle "임신 정보 정리" / inline. 하단 면책·통계 0.

[화면 B' 오버레이] 확인 Alert
- 제목 "임신 정보를 정리할까요?" / 메시지 "기록은 모두 그대로 보관돼요. 되돌리려면 더보기 > 이전 기록에서 다시 열 수 있어요."
- 버튼: "정리하기"(role .destructive지만 시스템 빨강 그대로, 카피는 중립) / "취소"(.cancel)
- 자동 dismiss·자동 진행 절대 금지(명시적 탭 1회 강제)

[화면 B'' 성공 상태] form→success 전환(약 2초 후 자동 dismiss)
- 중앙 정렬: SF "checkmark.circle.fill" .secondary(녹색 success 색 금지) + "기록이 안전하게 보관되었습니다." + "이전 기록에서 언제든 확인하실 수 있어요." 부제. Spacer 상하 균형. 폭죽/축하 애니메이션 절대 금지.
- 실패 시 failure 상태: "xmark.circle" + 에러 메시지 + "다시 시도"(데이터 미손실 보장)

[결과: 조용한 모드(Quiet Mode)] — 임신 노트 4탭 구조의 차분한 리스킨
- both: 종료 직후 화면 B''에서 dismiss → ④더보기로 돌아오고, 상단 공간칩이 [←육아로]만 남아 사용자가 조용히 1탭으로 육아 복귀. 임신 노트는 더 이상 강제로 열리지 않음(PortalCard가 육아홈 최상단에서 사라지거나 "기록 보기" 중립 라벨로 축소).
- pregnancyOnly: 앱 루트가 조용한 모드 임신 노트로 유지. 4탭 중 ①여정 ②기록 ③검진은 비활성/숨김 처리되고, ④더보기 중심의 회고·보관 공간으로 재편.
조용한 모드의 ④더보기(또는 단일 회고 화면) 위→아래:
1) 헤더: 보라 칩 제거, 중립 회색 헤더. 텍스트 "기록 보관함"(주차/D-day 미표기)
2) 위로 메시지 카드(1회성, 닫기 가능): 짧은 위로 + "필요하실 때 천천히 둘러보세요." (강제 행동 유도 0)
3) "지난 기록" — 그동안 쌓인 여정/태동/검진/체중/사진 기록을 읽기 전용 요약으로 보존(섭취·생산 등 의료수치 그대로, 손실 없음)
4) (선택) "추모 기록" 진입 row — 강제 X, 원할 때만. 태명·한마디·사진 1장 정도의 가벼운 자리. 미작성이 기본·정상
5) 최하단 "이전 기록"(PregnancyArchiveView)로 이번 기록이 outcome 라벨과 함께 영구 편입

**컴포넌트**
- 진입 row(화면 A): Form 단독 row + folder 아이콘 + chevron + caption. 위험 시그널(red/경고 아이콘) 없음.
- 위로 카드: rounded listRow, heart(테두리) + .secondary, 단문 1줄.
- 유형 Picker: .inline 3택(유산/사산/임신 중지). displayName은 기존 PregnancyOutcome(.miscarriage="유산"/.stillbirth="사산"/.terminated="임신 중지") 재사용.
- "정리하기" full-width 버튼: .secondary.opacity(0.7) 배경, 흰 텍스트(보라·red 아님).
- 확인 Alert: 2버튼, 중립 카피.
- 성공/실패 상태 뷰: 중앙 정렬 아이콘+제목+부제, 축하 연출 0.
- 조용한 모드 헤더: 중립 회색, 주차/D-day 미표기.
- 위로 메시지 카드(닫기 가능): 1회성, 행동 유도 0.
- 지난 기록 읽기전용 요약 리스트.
- (선택) 추모 기록 row + 가벼운 작성 시트(태명/한마디/사진1, 전부 optional).
- 이전 기록 편입 row(PregnancyArchiveView 연결).
- 공간칩(both): [←육아로]만 잔존, "🤰임신N주" 칩 제거.
- SF Symbols만, Apple 시스템 색(.secondary/.tertiary) 중심, ROA 보라 토큰은 이 경로에서 의도적 미사용.

**상태**
- 진입 전: 임신 진행 중(보라 활성). 화면 A의 "임신 정보 정리"는 항상 최하단에 조용히 존재.
- form: 유형 미선택→주차 기반 default 선택됨. 버튼 항상 활성(필수 입력 0, 강요 0).
- confirming: alert 표시. 백그라운드 진행 차단.
- saving: 짧은 처리 인디케이터(과한 스피너·프로그레스바 금지).
- success: 2초 노출 후 자동 dismiss. 데이터 저장 완료.
- failure: 에러 메시지 + 다시 시도. 데이터 무손실(부분 저장 없음).
- quiet(조용한 모드): 주수 freeze(종료 시점 주차로 고정, 이후 카운트업 정지)·모든 임신 알림 하드 취소·진행 UI(QuickLog/검진/진통/스탬프/커뮤니티) 전면 숨김·차분 중립톤 리스킨·데이터 100% 보존.
- both-quiet: 조용한 모드여도 육아 화면은 완전 정상(둘째 상실이 첫째 UI 침범 금지). 임신 PortalCard는 사라지거나 "기록 보기" 중립 라벨로 축소.
- 앱평가/업셀 억제 플래그 on: 이 사용자 세그먼트에 requestReview·프리미엄·구매 유도 트리거 일절 발화 안 함.
- 빈 상태: 추모 기록 미작성=정상(독려 문구·뱃지·빈 일러스트 압박 금지).

**상호작용**
- 화면 A "임신 정보 정리" 탭 → 화면 B push.
- 유형 Picker 선택 → 즉시 반영(저장 아님, 로컬 선택만).
- "정리하기" → 확인 Alert. "취소"=아무 변화 없음. "정리하기"=saving→success/failure.
- success 자동 dismiss → both는 ④더보기, pregnancyOnly는 조용한 모드 루트.
- 공간칩 [←육아로] 탭(both) → fullScreenCover 닫고 육아홈 복귀.
- 위로 메시지 카드 닫기(X) → 다시 표시 안 함(1회성).
- 추모 기록 row 탭(선택) → 가벼운 작성 시트. 미작성·중도 이탈 모두 무압박 dismiss.
- 지난 기록 항목 탭 → 읽기 전용 상세(편집·삭제 동선 없음, 데이터 보존 우선).
- 진행 동선(QuickLog/태동/진통 5-1-1/스탬프/커뮤니티) 진입점은 조용한 모드에서 비노출 → 사용자가 실수로 "진통 측정" 등 부적절 화면에 닿지 않음.
- pending orphan(전환 중단) 발생 시 PregnancyRecoveryModal 재사용 — 단, 손실 경로에서는 "축하" 문구 없이 중립 처리.

**전이**
- A→B: 표준 push(NavigationStack, 부모 설정 스택 사용 — 자체 NavigationStack 금지).
- B→B'(alert): 시스템 alert presentation.
- B(form)→B''(success/failure): 같은 뷰 내 phase switch(부드러운 fade, 슬라이드 과장 금지).
- B''(success)→dismiss: 2초 후 자동. both=fullScreenCover 유지한 채 ④더보기로, 또는 사용자가 [←육아로]로 즉시 복귀 가능.
- 진행 모드→조용한 모드: 색 전환은 즉각 리스킨(보라→중립). 깜빡임·번쩍임 없는 정적 전환.
- pregnancyOnly 조용한 모드: 앱 루트가 차분한 보관 공간으로 대체(임신 노트 4탭의 진행 탭은 페이드아웃/숨김).
- 추모 시트: sheet up/down 표준. 강제 dismiss 잠금 없음(언제든 빠져나갈 수 있음).

**한국 디테일**
- 임상 경계: 유산<20주 / 사산≥20주 분기는 내부에서만 처리, 사용자에게 임상 드롭다운(주수 입력·"20주 기준") 강요 금지. 3택(유산/사산/임신 중지)만 노출.
- 주차 표기(NN주N일·D-day)는 조용한 모드에서 전면 제거 — freeze된 시점도 사용자에게 카운트로 보여주지 않음(헤더에 "기록 보관함"만).
- 한국 정서 반영: 직접적 "사망/낙태" 용어 회피, "정리"·"보관"·"이전 기록" 등 절제·존중 표현. 위로 카피는 의료감수된 톤 유지.
- 산모수첩/국민행복카드/바우처/검진 일정 등 한국 산전 진행 요소는 조용한 모드에서 노출 안 함(상실 후 검진 독려는 2차 가해).
- 태교·만삭사진·2시간 10회 태동·5-1-1 진통 등 진행 도구 전부 숨김.
- 추모 기록의 태명(babyNickname)은 한국 사용자가 임신 초기부터 부르던 호칭이므로 보존·존중하여 회고 공간에서 다정히 표기.

**재사용 자산**
- PregnancyTerminationView(/Users/roque/BabyCare/BabyCare/Views/Settings/PregnancyTerminationView.swift): form/success/failure phase·위로 카드·terminationOutcomes 3택·확인 alert 그대로 재사용, 카피만 절제 톤으로 리스킨("종료"→"정리", success 색 .secondary 유지).
- PregnancyOutcome(/Users/roque/BabyCare/BabyCare/Models/PregnancyOutcome.swift): .miscarriage/.stillbirth/.terminated rawValue 영구 계약 그대로 사용. displayName(유산/사산/임신 중지) 재사용.
- PregnancyArchiveView/PregnancyArchiveDetailView(/Users/roque/BabyCare/BabyCare/Views/Settings/PregnancyArchiveView.swift): 손실 outcome은 이미 leaf.fill + .secondary 색·삭제 불가. 종료 기록이 여기로 영구 편입. "이전 임신"→"이전 기록" 라벨 정렬.
- PregnancyRecoveryModal: pending orphan 중단 복구 재사용(손실 경로는 축하 문구 제거 변형).
- DashboardPregnancyHomeCard/PortalCard: both에서 조용한 모드 시 카드 축소/제거(보라 액센트 회수).
- PregnancyViewModel.terminatePregnancy / WriteBatch + transitionState / markTransitionPending: 데이터 100% 보존·atomic 전환 그대로(데이터 삭제 절대 금지 룰 준수).
- AppContext 4-state(empty/babyOnly/pregnancyOnly/both): 신규 상태머신 없이 기존만으로 both→조용히 육아 복귀 처리.
- pregnancy-weeks.json: 진행 콘텐츠는 조용한 모드에서 미사용(읽기전용 과거 요약만).

**엣지**
- both에서 둘째 상실: 첫째 육아 화면·알림·위젯·홈카드에 절대 침범 금지. 조용한 모드는 임신 공간 내부에만 한정. [←육아로] 복귀 시 육아는 평소대로.
- 알림 하드취소 타이밍: 종료 확정(success) 즉시 예약된 모든 임신 로컬/푸시 알림 취소. 취소 실패해도 success 진행(데이터 우선) + 백그라운드 재시도.
- pending orphan: 전환 중 앱 종료 시 PregnancyRecoveryModal로 복구하되 손실 맥락이면 중립 카피.
- 위젯: PregnancyDDayWidget는 freeze/숨김 처리(잠금화면에 D-day 잔존 금지) — 상실 후 잠금화면 D-day 노출은 심각한 정서 사고.
- HealthKit 동기화: 임신 관련 동기화 중지, 기존 기록은 보존.
- 가족 공유(sharedWith): 파트너에게도 조용한 모드 일관 적용 — 한 명만 보라 진행 UI 보는 불일치 금지.
- 우발적 진입 방지: 화면 A 라벨은 최하단·확인 alert 1회 강제. 자동/스와이프 dismiss로 의도치 않은 확정 금지(interactiveDismissDisabled 패턴 차용).
- 데이터 무손실: 실패 시 부분 저장 금지(WriteBatch atomic). 추모 미작성·중도 이탈은 정상 경로.
- 복구 가능성: "이전 기록"에서 다시 열람 가능. 단, 되돌려 진행 모드 재개는 의도적으로 어렵게(우발 방지) — 명시적 동선만.
- 앱평가/업셀: 이 세그먼트에서 requestReview·프리미엄·커머스 트리거 전면 억제(축하·만족 가정 트리거가 상실 직후 발화하는 사고 차단).
- 접근성: 위로 카피·중립 색은 Reduce Motion/Transparency/고대비에서도 톤 유지, Dynamic Type XXXL에서 카드 truncate 방지(ViewThatFits 패턴).

---

## 임신 등록 온보딩 + 홈스크린 위젯 (임신 노트 진입 인프라). 두 구성요소: (1) PregnancyRegistrationView — 신규 empty 사용자의 3-way 선택("임신준비 / 임신중 / 육아중") 중 '임신중' 분기 + 기존(육아중·both) 사용자가 설정/추가 화면에서 '임신 등록'을 누른 진입. LMP·EDD 입력으로 예정일/주수 자동계산. (2) BabyCareWidget의 PregnancyDDayWidget — 잠금/홈 화면에서 D-day·주차를 보여주고 탭(딥링크)으로 임신 노트를 연다.

**한 줄**: 예정일 하나로 "임신 N주 N일·D-day"가 살아 움직이기 시작하는 출발점 — 화면 안(등록 폼)과 화면 밖(홈 위젯) 양쪽에서 임신 노트로 들어가는 두 개의 문.

**레이아웃**
[A. 임신 등록 폼 — PregnancyRegistrationView / NavigationStack + Form, 보라·라일락 액센트]
위→아래 섹션 순서:
1) 면책 배너 섹션 (listRowInsets 0·배경 clear): info.circle.fill + "이 정보는 일반적인 참고 자료이며 의학적 진단을 대체하지 않습니다." 라일락 톤 박스(opacity 0.12 채움 + 0.4 stroke, cornerRadius 10). 다태아(태아 수>1) 선택 시 두 번째 보라색 배너 "단태아 기준 정보입니다. 다태임신은 담당 의료진과 상의하세요." 가 조건부로 바로 아래 삽입.
2) "임신 날짜" 섹션 — 두 개의 DatePicker(.date, locale ko_KR):
   · "마지막 월경일 (LMP)" — 휠/캘린더, 허용범위 오늘−310일 ~ 오늘
   · "예정일 (EDD)" — 허용범위 오늘 ~ 오늘+310일
   둘은 280일(40주) 규칙으로 상호 역산 연동(아래 interactions).
3) "임신 정보" 섹션 — 태아 수 Picker(단태아 1 / 쌍태아 2 / 세쌍둥이 3) + 태명 TextField("태명 (선택)").
4) "초음파 성별" 섹션 — 세그먼트 Picker(미확인 / 남아 / 여아). 미확인이 기본·중립.
5) 에러 섹션(조건부) — pregnancyVM.errorMessage 있으면 빨강 caption.
상단 NavigationBar: 제목 "임신 등록"(inline), 좌측 "취소", 우측 "저장"(저장 중 disabled).
계산 결과 미리보기 카드(권장 추가): "임신 날짜" 아래에 자동계산된 "임신 N주 N일 · D-NN"을 라일락 요약 칩으로 실시간 노출(현재 코드엔 없음 — 등록 즉시 피드백 향상용 신규 컴포넌트).

[B. 3-way 진입 선택 — 신규 empty 컨텍스트]
empty 상태에서 ContentView가 보여주는 큰 선택 화면: 세로 3카드 또는 세그먼트 — ① 임신 준비(준비/난임 트래킹, 본 명세 범위 밖) ② 임신 중 → 본 등록 폼 fullScreenCover/시트 제시 ③ 육아 중 → 기존 AddBabyView. '임신 중' 카드는 figure.maternity + 라일락 액센트로 구분.

[C. 홈스크린/잠금화면 위젯 — PregnancyDDayWidget]
지원 패밀리 3종:
· systemSmall: 좌상단 라벨(아이콘+"임신"), 중앙 큰 D-day(monospacedDigit title bold), 그 아래 "N주 N일", 최하단 태명. 비활성 시 "임신 정보 없음".
· systemMedium: 좌측 D-day 블록 + Divider + 우측 진행도(Gauge linearCapacity·percent·"출산까지 N주" 잔여 텍스트).
· accessoryCircular (잠금화면): heart 게이지 + 중앙 현재 주차 숫자.
배경: WidgetGradient(다크/라이트 adaptive), 전체 탭 영역 widgetURL = babycare://pregnancy.

**컴포넌트**
[등록 폼]
· NavigationStack + Form (그룹 섹션 리스트)
· PregnancyDisclaimerBanner (private) — text + color 파라미터, 일반(라일락/orange 톤) + 다태아(보라) 2회 사용
· DatePicker × 2 (LMP/EDD), locale ko_KR, in: 범위 클램프
· Picker(태아 수, 기본 세그/메뉴) + TextField(태명) + Picker(.segmented, UltrasoundGender)
· Toolbar Button 2개(취소/저장)
· (권장 신규) 계산 미리보기 칩 — "임신 N주 N일 · D-NN" 라일락 캡슐
[위젯]
· PregnancyDDayEntry (TimelineEntry) — weekText/dDayText/progress 계산 프로퍼티
· PregnancyDDayProvider (TimelineProvider) — placeholder/snapshot/timeline(다음 자정 .after 갱신)
· Gauge(.linearCapacity / .accessoryCircularCapacity)
· WidgetColors / WidgetGradient adaptive enum, ContainerRelativeShape 배경
· widgetURL(babycare://pregnancy) 딥링크
[디자인 토큰]
· AppColors.primaryAccent(임신=보라/라일락 계열로 매핑), warmOrangeColor(overdue D+), indigoColor
· SF Symbols: figure.maternity, heart.fill, stethoscope, scalemass, info.circle.fill, chevron.right
· Apple Charts/Gauge만 사용(외부 차트 금지)

**상태**
[등록 폼]
· 초기 기본값: LMP=오늘−84일(12주 가정), EDD=오늘+196일, 태아 수=1, 태명="", 성별=미확인, lmpIsSource=true.
· lmpIsSource 토글 — 마지막 편집한 필드가 source(병원 EDD 우선 정책 반영: EDD를 마지막에 손대면 lmpIsSource=false로 EDD가 진실값).
· isLoading(저장 중) — 저장 버튼 disabled.
· errorMessage 존재 — 빨강 caption 섹션 노출 + 저장 후 dismiss 보류.
· 다태아 선택(fetusCount>1) — 보라 다태아 면책 배너 추가 노출.
· 범위 초과 입력은 DatePicker in: 범위로 구조적 차단(상태로 안 들어옴).
[위젯]
· isActive=true (PregnancyWidgetDataStore.isActive) — D-day/주차/진행도 표시.
· isActive=false (임신 비활성·FeatureFlag off·출산 전환 완료) — "임신 정보 없음" + 회색 게이지(circular는 minus 아이콘).
· D-day 분기 3상태: D-NN(미래·보라) / D-Day=오늘(보라 강조) / D+NN(초과·warmOrange).
· progress = min(currentWeek/40, 1.0) — 40주 클램프.
[3-way 진입]
· empty(아기·임신 모두 없음) 에서만 노출. both/babyOnly/pregnancyOnly 진입 시 비노출(기존 AppContext 4-state가 게이팅).

**상호작용**
[등록 폼]
· LMP 변경 → lmpIsSource=true, EDD = LMP+280일 자동 재계산(onChange).
· EDD 변경 → lmpIsSource=false, LMP = EDD−280일 자동 역산(onChange). (병원에서 받은 EDD를 입력하면 그 EDD가 우선·LMP는 파생.)
· 태아 수 변경 → 다태아 면책 배너 토글.
· 태명 입력 → 공백 trim, 빈 문자열이면 nil 저장.
· 성별 세그먼트 → 미확인/남아/여아 단일 선택.
· "저장" → 로그인 userId 가드 → pregnancyVM.createPregnancy(lmp, due, fetusCount, nickname, userId) → 성공(errorMessage==nil)이면 dismiss, 실패면 폼 유지 + 에러 노출.
· "취소" → 변경 폐기 dismiss.
· (권장) 입력하는 동안 미리보기 칩이 "임신 N주 N일 · D-NN"을 실시간 갱신 — LMP↔EDD 어느 쪽을 만져도 동일 결과 확인 가능.
[위젯]
· 위젯 전체 탭 → babycare://pregnancy 딥링크 → both는 임신 노트 fullScreenCover, pregnancyOnly는 루트인 임신 노트로 진입(앱 미실행 시 콜드 스타트 후 라우팅).
· 타임라인 자동 갱신(다음 자정) — 앱을 안 열어도 주차/D-day가 하루 단위로 갱신(원본 LMP/EDD에서 동적 계산).

**전이**
· empty → '임신 중' 선택 → 등록 폼(fullScreenCover 또는 push) → 저장 성공 → AppContext가 pregnancyOnly(아기 없음) 또는 both(아기 있음)로 재해석 → 임신 노트 진입 가능 상태.
· both/babyOnly 사용자가 설정 > 임신 등록 → 동일 등록 폼 → 저장 → both로 승격 → 육아 홈 최상단에 PortalCard 1개 + DashboardPregnancyHomeCard 노출(additive, 육아 UI 대체 안 함).
· 등록 직후 PregnancyWidgetSyncService가 lmpDate/dueDate 원본을 PregnancyWidgetDataStore에 기록 → 위젯 isActive=true 전환(다음 타임라인부터).
· 출산/임신 종료 전환(PregnancyTransitionSheet / PregnancyTerminationView, WriteBatch + transitionState) 완료 시 → PregnancyWidgetDataStore.clear → 위젯 isActive=false.
· 위젯 탭 → 임신 노트 4탭(여정/기록/검진/더보기) 진입. both는 상단 공간칩 [← 육아로] + "🤰임신N주" 노출, 닫기 1번으로 육아 복귀.
· FeatureFlag(pregnancy_mode_enabled) off로 전환 시 PregnancyWidgetDataStore.clearIfFlagDisabled로 위젯 비활성.

**한국 디테일**
· 주차 표기 "임신 N주 N일"(NN주N일), D-day "D-NN / D-Day / D+NN"(한국 임신앱 관습).
· 예정일 산출 규칙: LMP + 280일(40주) = EDD, 역산 동일(Naegele 변형, 코드 상수 dayInterval=280). 병원에서 초음파로 보정한 EDD가 있으면 EDD를 마지막 편집해 우선 적용(병원 EDD 우선 정책).
· DatePicker locale ko_KR — 한글 날짜·요일 표기.
· 진행도 분모 40주(만삭 40주 기준).
· 태명 = 한국 임신문화 핵심(아기 별명) — 위젯·홈카드·여정 타임라인에 노출.
· 다태아(쌍태아/세쌍둥이) 의료 면책 — 단태아 기준 정보 경고.
· 한국 산전검진 일정(11~13주 NT·15~20주 정밀초음파·24~28주 임당)·국민행복카드·산모수첩은 등록 후 검진 탭(③)에서 다뤄지며, 본 등록 화면은 그 일정 계산의 기준점(주차)을 확정하는 역할.
· 광고 0·커머스 0 — 등록 폼·위젯 모두 순수 기능만.
· 의료 수치(LMP/EDD/주차)는 민감 건강정보 → Firebase Analytics/Crashlytics payload 포함 절대 금지(저장만, 트래킹 금지).

**재사용 자산**
그대로 재사용(있음):
· PregnancyRegistrationView — 등록 폼 본체(LMP↔EDD 역산·280일·범위 클램프·다태아 배너·UltrasoundGender 세그먼트). 코드 존재, 임신 노트 IA에 맞춰 진입 경로(empty 3-way의 '임신중' + 설정 진입)만 재배선.
· PregnancyDDayWidget + PregnancyDDayEntry + PregnancyDDayProvider — small/medium/accessoryCircular 위젯 전부 구현됨. 딥링크 babycare://pregnancy 이미 임신 노트로 라우팅하면 됨.
· PregnancyWidgetDataStore / PregnancyWidgetSyncService — lmpDate/dueDate 원본 저장 + 위젯 동적 계산 + FeatureFlag off 시 clear.
· PregnancyDateMath — weekAndDay/dDay pure helper(앱·위젯 공용).
· DashboardPregnancyHomeCard — both 육아 홈 임신 요약 카드(주차·D-day badge·산전방문·체중델타). PortalCard 진입과 병존/통합 검토.
· PregnancyViewModel.createPregnancy / currentWeekAndDay / dDay — 등록 저장 + 계산.
· AppContext 4-state(empty/babyOnly/pregnancyOnly/both) — 3-way 게이팅·진입 재해석에 그대로 사용(신규 상태머신 없음).
· pregnancy-weeks.json(4~40주) — 등록 후 여정 탭 콘텐츠.
· AppColors.primaryAccent/warmOrangeColor/indigoColor, WidgetColors/WidgetGradient, SF Symbols.
신규 필요(권장): 등록 폼 내 실시간 계산 미리보기 칩, empty 3-way 진입 화면의 '임신중' 카드 라일락 styling, 육아 홈 PortalCard(임신 노트 입구) — DashboardPregnancyHomeCard와 역할 분리/통합 결정 필요.
주의: 액센트는 코드상 AppColors.primaryAccent(현재 핑크 #FF9FB5 매핑)를 임신 컨텍스트에서 보라/라일락으로 분리 토큰화해야 "독립 공간" 시각 정체성 충족(현재는 공통 primaryAccent 사용 → 임신용 보라 토큰 신설 권장).

**엣지**
· LMP를 오늘로 설정 → 0주 0일·D-280. 미래 LMP는 범위(오늘 상한)로 차단. PregnancyDateMath는 미래 LMP면 nil 반환(방어).
· EDD를 오늘로 → D-Day. 오늘 이전 EDD는 범위 차단되나, 위젯 동적 계산에서 경과 시 D+NN(overdue·warmOrange)로 자연 표시.
· 40주 초과(D+) — 진행도 게이지 1.0 클램프, "출산까지 0주", D+NN.
· LMP↔EDD 280일 역산의 왕복 오차: EDD 편집 후 LMP가 −280일로 역산되면 사용자가 처음 넣은 LMP와 달라질 수 있음 → 병원 EDD 우선이 의도이므로 lmpIsSource=false가 정답(혼동 방지 위해 미리보기 칩으로 결과 명시 권장).
· 저장 실패(네트워크/권한) — dismiss 안 하고 errorMessage 노출, 입력값 보존(재시도 가능).
· userId 없음(미로그인) — 저장 가드로 무동작(조용히 실패) → 로그인 유도 카피 권장.
· 위젯 콜드 스타트(앱 미실행) — PregnancyWidgetDataStore에 원본 있으면 앱 없이도 동적 계산 표시, 없으면 inactive.
· FeatureFlag off 또는 출산/종료 전환 후 위젯 stale — clearIfFlagDisabled/clear로 isActive=false, "임신 정보 없음".
· 다태아에서 단태아로 되돌리면 다태아 배너 사라짐(상태 일관).
· both에서 위젯 탭 → 임신 노트 fullScreenCover 위에 또 위젯 탭(중복 딥링크) → 이미 떠 있으면 재진입 무시/그대로 유지(중복 present 방지 가드 필요).
· 출산 전환 pending orphan(transitionState=pending) 상태에서 등록 재시도 — PregnancyRecoveryModal이 우선 처리(중복 활성 임신 방지).
· accessoryCircular 잠금화면 — 주차 2자리(예: 40) 폰트 minimumScale 처리, 비활성 시 minus 아이콘.

---

