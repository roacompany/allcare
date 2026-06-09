# Forward-compat tolerant decode for `Activity.ActivityType` — Design

**Date:** 2026-06-09
**Status:** Approved (direction) — PO confirmed forward-compat insurance with clear eyes (it does not help already-shipped old clients; it protects every build from build 89 onward against the *next* activity-type addition).
**Target release:** v2.8.7 (build 88 / v2.8.6 is in App Store review; this is the next train).
**Scope:** small standalone PR. Data-layer correctness + render/guard hardening. No user-visible feature.

---

## 1. Problem

`Activity.ActivityType` is a `String`-backed `Codable` enum. `FirestoreService.decodeDocuments` (`FirestoreService.swift:11-20`) decodes each document with `compactMap { try doc.data(as: T.self) }` — **any** decode failure returns `nil`, so the whole `Activity` is silently dropped (only a `warning` log).

When a family member on a **newer** app build creates a record whose `type` rawValue this build doesn't know yet, this build's synthesized `ActivityType` decode *throws* → the activity **silently vanishes** from this build's timeline/aggregates. This is happening today: the `feeding_pumping` type (added build 88) disappears on any family member still on an older build.

**Plain framing for the PO:** "엄마는 최신 앱, 할머니는 옛날 앱"일 때 엄마가 기록한 새 종류(유축)가 할머니 폰에서 조용히 사라진다. 이미 깔린 옛날 앱은 못 고치므로 이 작업은 **다음에 또 새 기록 종류를 추가할 때**를 위한 보험이다 (build 89+).

## 2. Design (Approach A — sentinel `.unknown` + early write/edit guards)

When this build reads an unrecognized `type` rawValue, decode it to a new sentinel case `Activity.ActivityType.unknown` instead of throwing. Render it as a neutral, **read-only** timeline row labeled **"앱 업데이트가 필요한 기록"**. Exclude it from every aggregate, picker, edit, timer, and — critically — **every write path** (so the real rawValue in Firestore is never overwritten).

**Why not "preserve the original rawValue" (Approach B):** zero-data-loss-on-resave is marginally nicer but needs either a full custom `Codable` on the 25-field `Activity` struct or wrapping `ActivityType` (ripples to hundreds of `.type ==` sites). Approach A makes re-save **structurally impossible** via early guards + a throwing `encode`, which closes the same hole at a fraction of the blast radius.

### 2.1 Decode core (`Models/Activity.swift`)
- Add `case unknown = "unknown"` to `ActivityType`.
- Add a custom `init(from decoder:)`: `self = ActivityType(rawValue: raw) ?? .unknown`. (Firestore's `data(as:)` uses a Codable `Decoder`, so this nested custom init **is** invoked — confirmed.) Synthesized `CaseIterable`/`RawRepresentable`/`Identifiable`/`encode` remain intact.
- Add `case unknown` to `ActivityCategory` (neutral bucket). `ActivityType.unknown.category == .unknown`.
- **Backstop:** custom `encode(to:)` that throws `EncodingError.invalidValue` when `self == .unknown`. `.unknown` is never a legitimate value to persist; making encode fail-loud covers any present/future write path (the offline queue's `try?` encode simply skips it). Paired with the early guards below so it never actually throws in normal flow.

### 2.2 Write isolation — the load-bearing part
A single guard in `saveActivity` is **insufficient** (red-team confirmed):
- A `return`-style guard there fakes success → `optimisticReplace` keeps the in-memory edit (phantom edit, diverges from Firestore until refetch).
- A `throw`-style guard lands in `performSaveActivity`'s `catch` → which calls `enqueueOfflineActivity` → the **offline-queue bypass**: `ActivityViewModel+Save.swift:166` JSON-encodes directly and `FirestoreService+OfflineQueue.swift:25` later does `setData(dict)` with no validation.

**Fix — short-circuit `.unknown` *before* any optimistic insert / save / enqueue, at each entry point:**
- `ActivityViewModel.updateActivity`, `performSaveActivity`, `savePrebuiltActivity`, `quickSave` — early `guard activity.type != .unknown else { AppLogger.firestore.warning(...); return }`. Never enqueue offline on rejection.
- Defense-in-depth (cheap, explicit, logged): guard in `FirestoreService+Activity.saveActivity` (before `setData`) and in `enqueueOfflineActivity` (before `JSONEncoder`).

### 2.3 Edit isolation
`ActivityEditSheet`'s "저장" button is always present; with no type-section it would be an empty form that silently no-ops on save. Block at the **entry points** (promote from "polish" to required):
- `editingActivity = activity` sites: `DashboardView+Summary.swift:51/55`, `CalendarView+Detail.swift:139/155` — `guard activity.type != .unknown else { /* toast + AppLogger */ return }`.
- The header (`displayName`/`icon`) renders fine; type-conditional sections naturally absent.

### 2.4 Aggregation isolation (positive whitelist)
Positive filters (`category == .feeding`, `type == .x`, `.whereField("type", in: [...])`) auto-exclude `.unknown` — ~20 sites, no change. **Three inverse/no-filter leaks must become positive whitelists** `[.feeding, .sleep, .diaper, .health]`:
1. `ActivityViewModel+Reminders.swift:37` — widget recent strip `category != .pumping` → `.unknown` would escape into the home-screen widget.
2. `CalendarViewModel.swift:143` — event-dots `where category != .pumping` → `.activity(.unknown)` dot inserted silently (no compile error; `CalendarEventType.activity` takes any category).
3. `PatternAnalysis+Summary.swift:7` (`analyzeSummary`) — counts **all** activities → inflates the "종합 요약 / 총 기록 N건" card and adds an uncolored `.unknown` donut slice.

**Implementation-review addendum (2 more "iterate-all" sites found, fixed):** `.unknown` retains sibling fields (`amount`/`temperature`/`note`/`medicationName`) because the custom Codable overrides only `type`. So any site that iterates *all* activities without a positive type/category filter leaks them. The full set of such sites is now: `analyzeSummary` (above), **`HospitalChecklistService.symptomItems`** (a `.unknown` with `temperature≥38`/symptom-keyword `note`/`medicationName` would inject a false fever/symptom/medication entry into the pediatrician checklist + hospital PDF — highest-stakes), and **`ExportService.makeCSVString`** (a `.unknown` `amount` leaks into the CSV "양(ml)" intake column). All three filter `{ $0.type.category != .unknown }`. Positive-filter aggregations (Stats/PDF body/InsightProviders/PatternAnalysis/clinical AI engine) are auto-safe — a full re-scan confirmed these are the only three. New iterate-all sites must filter `.unknown` (see `.claude/rules/swift-conventions.md`).

### 2.5 Picker / timer / reconstruction isolation
- `QuickRecordSettings.allAvailableTypes` uses `.allCases` → filter: `.allCases.filter { $0 != .unknown }`. (`FeedingSubPicker` is a hardcoded literal — auto-safe.)
- `ActivityViewModel.startTimer` — guard `.unknown` (already `needsTimer == false`, but guard the entry so the floating banner never shows a junk timer).
- **`init?(rawValue:)` resurrection:** the sentinel `"unknown"` makes `ActivityType(rawValue: "unknown")` succeed. 3 sites rebuild the enum from a raw String, bypassing the custom decoder: `QuickRecordSettings.enabledTypes:21`, `ActivityTimerManager.swift:86`, `NotificationSettings.swift:67`. Add a small helper `ActivityType.known(rawValue:) -> ActivityType?` that returns `nil` for the sentinel, and use it at these sites (restores the pre-change "drop unknown raw" behavior). Largely theoretical (the sentinel should never be persisted given §2.2), but cheap and closes the class.

### 2.6 Render arms (compiler-forced — build fails until added; all SAFE)
Adding `case unknown` to the two enums forces explicit arms in every exhaustive switch — the compiler enumerates them for us. Neutral values:
- `ActivityType`: `displayName="앱 업데이트가 필요한 기록"`, `icon="questionmark.circle"`, `color="systemGray4"` (or neutral token), `category=.unknown`, `needsTimer/needsAmount/needsQuickInput=false`. Plus `applyTypeFields` (`ActivityViewModel+Save.swift`) passthrough.
- `ActivityCategory.displayName="앱 업데이트가 필요한 기록"`, and ~12 category switches → neutral gray / `EmptyView()` / no-op: `ActivityRow:111`, `Reminders:43` (`#A0A0A0`), `RecordingComponents:47`, `RecordingView:271`, `HighlightTickerView:180/189`, `DashboardView+Shortcuts:57/66`, `WeeklyHighlightGrid:171/180/189`, `HighlightDetailSheet:205/214`.
- Switches with `default:`/`@unknown default:` (won't fail the build, silently absorb `.unknown`) — make `.unknown` **explicit** per the codebase's "no silent default for ActivityType" convention (`safety.md`): `BadgeEvaluator+Mapping:17` (→nil), `ProductViewModel+CRUD:135` (→nil), `FloatingTimerBanner:64` (→neutral), `QuickInputSheet:34` (**→ `false`**, defense against "saveable"), `QuickInputSheet:117/284`, `FeedingRecordView:27`, `DiaperRecordView:144`.

### 2.7 Widget target
No change needed. `BabyCareWidget` consumes a flat `WidgetActivity` (typeRaw/displayName/icon/colorHex String) populated by the main app via positively-filtered data — it never decodes `ActivityType`. (Confirmed across all 8 widget files.) The §2.4(1) fix keeps `.unknown` out of the widget strip.

## 3. Invariants (must hold; locked by tests)
1. Decoding an Activity whose `type` is an unrecognized rawValue → `type == .unknown`, document **survives** (not dropped).
2. Decoding `type == "feeding_pumping"` still → `.feedingPumping` (no over-eager fallback).
3. A `.unknown` activity with `amount`/`duration` set is **never** summed into any total (feeding mL, pumping mL, sleep hours, diaper count, totalRecords) or shown in any chart/dot/widget/PDF.
4. `.unknown` is **never** persisted: `saveActivity`/`enqueueOfflineActivity`/`encode` all refuse it; `setData` call-count for a `.unknown` save == 0. **Delete still works** (`ref.delete()` is a separate API, not gated).
5. `.unknown` never appears in any user-facing picker, is not editable, and never starts a timer.

## 4. Test plan (TDD, `BabyCareTests`)
- `init(from:)`: JSON with `type:"future_type_xyz"` → `.unknown`; `type:"feeding_pumping"` → `.feedingPumping`.
- `encode(to:)` of `.unknown` throws.
- `.unknown.category == .unknown`; whitelist aggregations (StatsViewModel / CalendarViewModel / PatternAnalysisService / `analyzeSummary`) unchanged when a `.unknown(amount:999, duration:99999)` record is added alongside real records.
- `QuickRecordSettings.allAvailableTypes` excludes `.unknown`; `ActivityType.known(rawValue:"unknown") == nil`.
- `MockFirestore`: `saveActivity(.unknown)` → 0 `setData`; `enqueueOfflineActivity(.unknown)` → pending count unchanged; `deleteActivity(.unknown)` proceeds.

## 5. Non-goals
- Helping already-shipped old clients (impossible; this is the entire premise).
- Preserving the original unknown rawValue across a (now-blocked) re-save (Approach B).
- Any user-facing feature (feeding-mL chart, stash inventory) — separate backlog.

## 6. Notes / risks
- `analyzeSummary` whitelist also corrects a **pre-existing `.pumping` leak** — verify the in-app PatternReport "종합 요약" count/donut against expectation (should now exclude pumping & unknown). This is a (small, correct) behavior change to an existing screen; call it out in the PR.
- Per `build-gotchas.md`: v2.8.6/build 88 train is in review → this ships as **v2.8.7** (bump `MARKETING_VERSION`; verify build number via ASC ground truth, not blind `make bump`).
