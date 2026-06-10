# BabyCare — iOS 27 디자인 가이드 일치 감사 (2026-06-10)

> 방법: 실제 iOS 27(WWDC 2026-06-08 발표) 변경점을 웹 리서치(Apple 1차 출처 + 적대 검증, 31 findings) → BabyCare 디자인 표면과 1:1 대조. iOS 27 SDK는 **Xcode 27 beta**에만 있어 시뮬레이터 시각 QA는 별도(아래 §5).

## 1. 결론 (Verdict)

**BabyCare는 iOS 27에 대체로 잘 맞는 상태다.** iOS 27은 **Liquid Glass의 "정제"(iteration #2)이지 재설계가 아니다** — 시스템 컨트롤/머티리얼은 SDK 재빌드 시 자동으로 개선된 룩을 상속한다. 앱은 ①Liquid Glass opt-out을 안 했고(`UIDesignRequiresCompatibility` 미설정) ②UIScene manifest가 있고 ③대부분 시스템 머티리얼·시스템 폰트(Dynamic Type)·Dynamic Color·SF Symbols·표준 TabView/NavigationStack을 쓴다. **깨지는 마이그레이션 없음, App Store SDK 강제 기한도 아직 없음.** 실제 할 일은 (A) Xcode 27 시각 QA + (B) 소수 폴리시(LoginView 접근성/대비, 레이어드 아이콘).

## 2. 확정된 iOS 27 변경점 (Apple 1차 출처)

- **Liquid Glass 정제**: "more uniform refraction + improved contrast" — 시스템 표면 자동 개선. (apple.com/os/ios)
- **사용자 투명도 슬라이더 (ultraclear ↔ fully tinted)**: 투명도가 **사용자 변수**가 됨. 접근성(Reduce Transparency)과 **별개**. (apple.com/os/ios + MacRumors)
- **기본 대비 개선**: iOS 26 대비 회귀 교정.
- **앱 아이콘 레이어드/선명**: Icon Composer `.icon`(Default/Dark/Mono, 굴절/반사). 권장, 차단 아님. (developer.apple.com/icon-composer)
- **opt-in SwiftUI API**: toolbar visibilityPriority/overflowMenu/topBarPinnedTrailing/minimizeBehavior, alert·confirmationDialog item/error 바인딩, reorder/swipe 컨테이너, @State 매크로(lazy init), AsyncImage HTTP 캐시.
- **마이그레이션(고신뢰·2차 출처)**: ①iOS 27 SDK에서 `UIDesignRequiresCompatibility` opt-out **제거** ②UIScene 라이프사이클 **필수**(TN3187, 미준수 시 "won't launch").
- **변화 없음**: 타이포그래피(SF Pro 유지), 독립 다크모드 재설계 없음.

## 3. BabyCare 표면 대조 — 이미 합치 ✅

| 항목 | 상태 | 근거 |
|---|---|---|
| Liquid Glass opt-out | ✅ 안 함 | `UIDesignRequiresCompatibility` grep 0 → SDK 제거돼도 깨질 것 없음 |
| UIScene 라이프사이클 | ✅ 준비됨 | `UIApplicationSceneManifest` 존재(project.yml:76, Info.plist:48) + `@UIApplicationDelegateAdaptor`는 Firebase/푸시 init용 |
| 시스템 머티리얼 | ✅ 32파일 자동정제 | `.ultraThin/.regular/...Material` — 재빌드 시 개선 상속 |
| 커스텀 blur | ✅ 거의 없음 | `.blur(radius:` 1파일뿐 |
| 폰트/타입 | ✅ | DS2 = system Font + Dynamic Type (iOS 27 타이포 변화 없음) |
| 색/다크모드 | ✅ | Asset Catalog Dynamic Color + 시스템 semantic 배경 → 자동 대응 |
| 표준 chrome | ✅ 자동 restyle | TabView/NavigationStack/.toolbar/sheet — 재빌드 시 Liquid Glass |
| `.actionSheet`(deprecated) | ✅ 0 | 이미 confirmationDialog 사용 |

## 4. 손볼 항목 (우선순위)

| # | 우선 | 항목 | iOS 27 이유 | 액션 | 위치 |
|---|---|---|---|---|---|
| 1 | **HIGH** | Xcode 27 시각 QA | 시스템 표면이 자동 변하므로 실증 필요 | Xcode 27 빌드 후 화면별 스크린샷 (§5) | 전 화면, 특히 LoginView/Dashboard/Floating* |
| 2 | **HIGH** | 머티리얼 위 콘텐츠 대비 | 슬라이더로 투명도가 사용자 변수 | 흰/저투명 텍스트를 ultraclear·tinted **양 극단**에서 가독 검증; semantic/dynamic color로 | LoginView(흰 텍스트 on gradient+`.ultraThinMaterial`), 32 머티리얼 파일 |
| 3 | **MED** | LoginView 접근성 | 커스텀 글래스는 슬라이더/접근성 자동대응 안 함 | `accessibilityReduceTransparency`·`colorSchemeContrast` 읽어 **불투명 폴백** 제공; orb 애니메이션은 `reduceMotion` 게이트 | `Views/Auth/LoginView.swift`(gradient bg + 장식 orb) — **현재 a11y 대응 0파일** |
| 4 | **MED** | 앱 아이콘 레이어드화 | iOS 27 선명/다중모드 아이콘 | Icon Composer로 `.icon` 재작성(Default/Dark/Mono). macOS 26.5 ✅ 가능 | `Assets.xcassets/AppIcon.appiconset/AppIcon.png`(평면, Dark/Tinted 변형 0) |
| 5 | **MED** | 플로팅 오버레이 vs 떠있는 탭바 | iOS 26+ 탭바가 floating·scroll 최소화 | 떠있는 탭바와 겹침/세이프에어리어 확인 | `FloatingTimerBanner`/`FloatingMiniPlayer`(ContentView 하단 overlay) |
| 6 | LOW | opt-in toolbar API | 혼잡 toolbar 붕괴 대비 | 필요 화면만 visibilityPriority/pin 적용 | (선택) |
| 7 | LOW | `@State` lazy init | side-effecting init 타이밍 변동 | side-effect init 객체 보유 @State 재확인 | (저위험) |

## 5. 시뮬레이터 시각 QA (leg B — Xcode 27 beta 필요)

⚠️ **현재 머신 = Xcode 26.5 (iOS 26.2/26.4/26.5 sim만). iOS 27 SDK/sim 없음.** macOS는 26.5라 설치 자격은 ✅.

**선행(PO 액션)**: Xcode 27 beta(27A5194q, Apple Silicon 전용) 설치 → iOS 27 시뮬레이터 런타임 추가.

**QA 절차(설치 후)**: ⚠️ **출시 빌드를 27 SDK로 바꾸지 말 것** — 별도 빌드로 시각 확인만.
1. `make build`을 Xcode 27 toolchain으로(또는 Xcode 27에서 스킴 빌드) → iOS 27 sim 부팅
2. 화면별 스크린샷: 온보딩/로그인(글래스), 대시보드(HealthStyleFavoriteCard·Favorites), 탭바·내비, 기록 시트, 캘린더, 설정, Floating 배너
3. 각 화면을 **설정 > 디스플레이 > Liquid Glass 슬라이더 ultraclear / fully tinted** + **Reduce Transparency on/off** + **다크모드**에서 대비/깨짐 확인
4. 발견 → §4 항목으로 회귀 수정

## 6. 기한 / 권고

- **App Store iOS 27 SDK 강제 기한: 없음(미발표).** 현재 규칙은 iOS 26 SDK(Xcode 26+, 2026-04-28 발효) — 앱은 이미 충족(Xcode 26.5). ~2027-04 iOS 27 강제는 **추정**일 뿐. → **서두를 필요 없음.**
- **권고 순서**: 2026 내내 iOS 26 SDK로 계속 출시 → Xcode 27로 **재빌드+시각 QA**(이 문서 §5) + §4 폴리시 → 그 다음 미래 SDK bump. `developer.apple.com/news/upcoming-requirements` 모니터.

## 7. 앱 아이콘 Icon Composer 전환 가이드 (MED — 아트워크는 PO)

현재: `Assets.xcassets/AppIcon.appiconset/AppIcon.png` = **평면 단일 PNG, Dark/Tinted 변형 0**. iOS 27은 레이어드 `.icon`(Default/Dark/Mono + 굴절/반사)을 권장(**차단 아님** — 평면도 출시는 됨). macOS 26.5라 Icon Composer 사용 가능 ✅.

> **Claude가 할 수 있는 것** = 프로젝트 배선 + 검증 절차. **PO가 할 것** = 레이어 아트워크 디자인(배경/심볼 분리).

1. **레이어 준비**(PO): 현 아이콘을 ①배경(그라데이션/단색) ②전경 심볼(하트) 등으로 분리. 벡터(SVG/PDF) 또는 고해상 PNG 레이어 권장.
2. **Icon Composer**(Xcode 번들, macOS 26.4+): 새 `.icon` 생성 → 레이어 임포트 → **Default/Dark/Mono** 외형 지정 → 레이어별 specular/refraction/translucency/shadow 튜닝 → `BabyCare.icon` 내보내기.
3. **프로젝트 배선**: `BabyCare.icon`을 타깃에 추가 + 앱 아이콘으로 지정. XcodeGen(`project.yml`)은 `.icon`을 리소스로 추가하고 앱아이콘 이름을 설정(`ASSETCATALOG_COMPILER_APPICON_NAME` 또는 `.icon` 자동 인식). ⚠️ `.icon`+XcodeGen 통합은 신규 → **Xcode 26.4+/27 빌드 인식 확인 필수**(기존 `AppIcon.appiconset`는 폴백으로 당분간 유지 가능).
4. **검증**: 빌드 → 홈 화면/Spotlight/App Library/알림 + **다크/틴트** 외형 + 작은 크기 선명도 확인.

> 우선순위 MED·비차단. 아트워크 준비되면 배선/검증은 Claude가 진행.

## 8. 진행 상태 (2026-06-10)

- ✅ §4-#3 **LoginView 접근성/대비 수정** 완료(`b53b87a`) — Reduce Transparency/Increase Contrast 시 불투명 폴백 + 장식 orb 숨김. (시각 검증은 §5 Xcode 27 QA에 포함)
- ⬜ §1·§5 **Xcode 27 시각 QA** — Xcode 27 beta 설치 후(PO 액션). macOS 26.5 설치 자격 ✅.
- ⬜ §7 **레이어드 아이콘** — PO 아트워크 대기.
- ⬜ §4-#2 머티리얼 위 대비 양극단 검증 — Xcode 27 QA와 함께.

## 출처
apple.com/os/ios · developer.apple.com/swiftui/whats-new · developer.apple.com/icon-composer · Apple TN3187(UIScene) · developer.apple.com/documentation/technologyoverviews/liquid-glass · (보조) classmethod iOS27 migration guide, MacRumors 2026-06-08.
