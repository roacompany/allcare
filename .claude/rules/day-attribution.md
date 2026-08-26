---
globs: "**/*.swift"
---

# 하루 귀속 — 자정을 넘긴 기록 (2026-08-26, v2.8.11)

구간이 있는 기록(`startTime`~`endTime`)은 **자정을 넘으면 두 날에 걸쳐 있다.**
수면 · 모유(직수) · 병수유 · 목욕이 해당한다(`ActivityType.supportsEndTime`).
기저귀 · 체온 · 이유식 · 투약 · 유축은 시점 기록이라 무관.

## 규칙 두 줄 — 어기면 화면마다 답이 갈라진다

| 무엇을 세나 | 어떻게 |
|---|---|
| **시간**(합계·평균·그래프) | 자정에서 잘라 **두 날이 나눠 갖는다** → `ActivityDayAttribution.totalClippedDuration(_:on:)` |
| **횟수 · 양**(회, ml) | 나눌 수 없다 → **시작한 날 하루에만** → `ActivityDayAttribution.startedOn(_:day:)` |
| **기간 단위**(주간·월간 총합) | 기간 경계로 클립 → `clippedDuration(from:to:...)` |
| **기간 안 횟수·분포** | `ActivityDayAttribution.startedWithin(_:from:to:)` |

⛔ **`compactMap(\.duration).reduce(0, +)` 를 「그날/그 기간 총 시간」에 쓰지 말 것.**
⛔ **하루 목록을 걸러내지 않고 `.count` / `.compactMap(\.amount)` 하지 말 것.**

## 왜 그냥 세면 두 번 세어지나

`FirestoreService.fetchActivities(userId:babyId:date:)` 는 **「그날 시작한 것」 + 「그날 끝난 것」
두 쿼리를 합쳐** 온다(`mergeDayResults`). 달력에 점을 걸친 날짜 양쪽에 찍으려는 **의도된** 설계다.

→ 자정 넘김 기록은 **어제 목록에도, 오늘 목록에도** 들어 있다.
→ 세는 쪽이 그걸 모르면 **어제도 9시간, 오늘도 9시간**이 된다.

🩸 **하루만 보면 그럴듯해서 안 걸린다.** 검증은 **이틀을 더해 실제보다 큰지**로 할 것.

## 기간 조회는 반대로 틀린다

`fetchActivities(userId:babyId:from:to:)` 는 **`startTime` 만** 묻는다
→ 기간 **첫날 새벽에 걸친 잠이 아예 안 온다.**

고치려면 조회를 **하루 앞당긴다**(`from: start.startOfDay.adding(days: -1)`).
그런데 그러면 앞당긴 하루가 **유령 막대**로 그래프에 샌다.

→ 반드시 **둘로 나눠 넘긴다**:
- **「기간 안에서 시작한 것」** = 횟수 · 분포 · 막대 키 (`startedWithin`)
- **「기간에 걸친 것」** = 시간 합계 (`totalClippedDuration` / `clippedDuration(from:to:)`)

`PatternAnalysisService.analyze` 가 이 분리를 **안에서** 한다 — 호출부는 넓은 목록만 넘기면 된다.
`Preprocessor.aggregate` 도 이미 같은 모양이다(세는 건 기간으로 걸러내고, 수면만 클립).

## 조용한 자리 셋 — 여기가 제일 잘 빠진다

1. **여러 목록을 합쳐 계산하는 곳.** `todayActivities + recentWeekActivities` 처럼 합치면
   자정 넘김 기록이 **양쪽에 다 있어 두 번** 들어간다(유축 재고에서 80ml 가 0ml 로 보였다).
   → 합쳐 받는 함수는 **id 중복 제거를 자기 안에서** 한다(`PumpedMilkInventory.fromActivities`).
   호출부에 맡기면 다음 호출부가 빠뜨린다.
2. **위젯.** 화면 값을 그대로 실어 나른다(`WidgetDataStore.update`) — 화면이 틀리면 위젯도 틀린다.
3. **기간 비교.** 이번 기간만 클립하고 지난 기간은 통째로 더하면 「지난주 대비」가 **사과 대 오렌지**가 된다.
   두 기간을 **같은 자로** 잴 것.

## 자정 직후 「마지막 …」

오늘 기록이 아직 없는 새벽엔 최근 7일에서 가져온다(`deriveLatestActivities`).
🔑 **한 종류에만 fallback 을 넣으면 나머지만 빈칸이 된다** — 수유에만 있어서, 1시간 전에 간 기저귀가
「오늘 기록 없음」으로 나왔다. fallback 은 **한 자리에 모아 전 종류가 같이** 쓴다.

## 분류가 있는 집계

낮잠/밤잠처럼 분류가 붙는 집계는, **구간을 잘라도 분류는 기록의 시작 시각이 정한다**
(잠의 성격은 자정을 넘는다고 바뀌지 않는다). `SleepAnalysisService.computeNapNightRatios` 참고.
막대 키는 `spannedDays` 로 만들어야 **넘어간 날의 몫이 사라지지 않는다.**

## 게이트

같은 밤잠 하나를 **여러 화면에 물어 셋이 같은 값을 내는지 대조**하는 테스트가 있다
(`testDailySleepHours_everySurfaceAgreesOnMidnightCrossingSleep`).
새 화면이 자기 식으로 더하기 시작하면 여기서 빨강이 된다.
**새 집계 화면을 만들면 이 대조에 한 줄 추가할 것.**

⚠️ 새 라벨·새 판정을 도입할 때 **옛 동작을 못박은 기존 단언을 전수 grep** 할 것 —
이번에도 `computeNapNightRatios` 테스트가 「밤잠 8시간이 시작일에 통째로」를 못박고 있었다.
