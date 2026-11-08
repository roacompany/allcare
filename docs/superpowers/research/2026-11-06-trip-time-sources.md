# 여행 일정표 — 시각을 모를 때의 표준과 상대 공항 시각의 출처

- 조사일: 2026-11-06
- 쓰임: 앱이 시각을 모를 때 14:00·00:00 을 지어 넣는 결함을 고칠 때의 설계 근거
- 근거 표시
  - **[문서]** 공식 문서·명세에 적힌 내용
  - **[코드]** 이 저장소 또는 공개 화면의 코드에서 읽은 내용
  - **[추론]** 위 둘에서 이끌어 낸 판단
  - **[확인 못 함]** 근거를 찾지 못했거나 재 보지 못한 것
- 실제 API 호출은 하지 않았다. 앱의 키를 쓰지 않았으므로 「문서에 칸이 있다」까지만 확인했고, 「응답에 값이 실제로 온다」는 확인하지 않았다.

## 결론

1. **날짜만 아는 일정** — iCalendar(RFC 5545)는 `DTSTART;VALUE=DATE:…` 로 시각 없이 날짜만 적는다. 떠 있는 시각(floating)은 「시각을 모름」이 아니라 「시간대와 상관없이 같은 시각」이라 이 용도가 아니다. 「시각 모름」 전용 값은 표준에 없다.
2. **예약 자료의 칸** — schema.org 는 칸을 강제하지 않지만, 여섯 칸의 값 형식에 날짜만(Date)은 들어 있지 않다. Gmail 문서는 출발·도착·체크인·체크아웃·픽업·반납을 모두 필수 DateTime 으로 둔다. 체크인 시각·도착 시각을 비우는 길은 Gmail 마크업에 없다.
3. **상대 공항 시각** — 인천 출발편의 상대 공항 도착 시각, 상대 공항에서 오는 편의 출발 시각을 **직접 주는 칸은 공식 문서에 없다.** 계산 재료는 앱이 이미 부르는 운항현황 API 의 `elapsetime`(항공사가 보낸 소요시간)이 있다. 다만 당일치뿐이고 빠질 수 있고 오차가 있으며, 상대 공항 시간대는 이번에 본 공공 API 어디에도 없다. 값을 재 보지 못한 곳이 둘 남았다: 한국공항공사 `flight-schedule/int` 의 시각 칸, 항공정보포털 화면의 `arrTime`(3.5).

---

## 1. 날짜는 아는데 시각은 모르는 일정

### 1.1 값의 네 가지 모양 — [문서]

| 표현 | RFC 의 예 | 뜻 | 절 |
|---|---|---|---|
| 날짜(DATE) | `DTSTART;VALUE=DATE:20070628` | 날짜만 있고 시각이 없다 | [§3.3.4](https://www.rfc-editor.org/rfc/rfc5545.html#section-3.3.4), [§3.8.2.4](https://www.rfc-editor.org/rfc/rfc5545.html#section-3.8.2.4) |
| 떠 있는 시각(FORM #1) | `19980118T230000` | 시간대에 묶이지 않고 어디서든 같은 시·분·초 | [§3.3.5](https://www.rfc-editor.org/rfc/rfc5545.html#section-3.3.5) |
| UTC 시각(FORM #2) | `19980119T070000Z` | 절대 시각 | [§3.3.5](https://www.rfc-editor.org/rfc/rfc5545.html#section-3.3.5) |
| 시간대 붙은 시각(FORM #3) | `TZID=America/New_York:19980119T020000` | 그 지역의 시각 | [§3.3.5](https://www.rfc-editor.org/rfc/rfc5545.html#section-3.3.5), [§3.2.19](https://www.rfc-editor.org/rfc/rfc5545.html#section-3.2.19) |

### 1.2 날짜만 쓸 때의 규칙 — [문서]

- `DTSTART` 의 기본 형식은 DATE-TIME 이고 DATE 로 바꿀 수 있다. 「The value type can be set to a DATE value type.」 — [§3.8.2.4](https://www.rfc-editor.org/rfc/rfc5545.html#section-3.8.2.4)
- 기본 형식을 바꾸면 `VALUE` 를 반드시 적는다. 「then this parameter MUST be specified.」 — [§3.2.20](https://www.rfc-editor.org/rfc/rfc5545.html#section-3.2.20)
- DATE 시작에 `DTEND`·`DURATION` 이 없으면 하루짜리다. 「the event's duration is taken to be one day.」 — [§3.6.1](https://www.rfc-editor.org/rfc/rfc5545.html#section-3.6.1)
- `DTEND` 는 끝을 포함하지 않는다. 「specifies the non-inclusive end of the event.」 — [§3.6.1](https://www.rfc-editor.org/rfc/rfc5545.html#section-3.6.1). RFC 의 예는 6월 28일부터 7월 8일까지의 일정을 `DTEND;VALUE=DATE:20070709` 로 적는다.
- `DTEND` 의 형식은 `DTSTART` 와 같아야 한다. 「MUST be the same as the "DTSTART" property」 — [§3.8.2.2](https://www.rfc-editor.org/rfc/rfc5545.html#section-3.8.2.2). 시작은 시각까지, 끝은 날짜만 적는 조합은 안 된다.
- 시각 있는 시작에 `DTEND` 가 없으면 시작 순간에 끝난 것으로 본다. 「the event ends on the same calendar date and time of day specified by the "DTSTART" property.」 — [§3.6.1](https://www.rfc-editor.org/rfc/rfc5545.html#section-3.6.1)
- DATE 값에는 시간대를 붙이지 않는다. 「MUST NOT be applied to DATE properties」 — [§3.2.19](https://www.rfc-editor.org/rfc/rfc5545.html#section-3.2.19)
- `METHOD` 없는 파일의 VEVENT 에서 `DTSTART` 는 필수다 — [§3.8.2.4](https://www.rfc-editor.org/rfc/rfc5545.html#section-3.8.2.4). 날짜조차 없는 일정은 이 형식으로 적을 수 없다.

### 1.3 떠 있는 시각은 「모름」이 아니다 — [문서]

- 정의는 시간대와 상관없이 같은 시각이다. 「They are used to represent the same hour, minute, and second value regardless of which time zone is currently being observed.」 — [§3.3.5](https://www.rfc-editor.org/rfc/rfc5545.html#section-3.3.5)
- 받는 쪽은 참석자가 있는 곳의 시간대로 읽는다. 「fixed to whatever time zone the "ATTENDEE" is in at any given moment.」 — 같은 절
- 쓰임을 좁혀 둔다. 「Floating time SHOULD only be used where that is the reasonable behavior.」, 「In most cases, a fixed time is desired.」 — 같은 절

**[추론]** 떠 있는 시각도 시각은 시각이다. 14:00 을 지어 넣은 값을 시간대만 뺀다고 해서 「모름」이 되지 않는다.

### 1.4 표준이 말하지 않는 것

- RFC 5545 원문에 "all-day" 라는 낱말은 없다(원문 전체 검색). DATE 일정의 쓰임은 「an anniversary or daily reminder」로 적혀 있다 — [§3.6.1](https://www.rfc-editor.org/rfc/rfc5545.html#section-3.6.1)
- **[추론]** DATE 는 「시각이 없는 값」이지 「시각이 있는데 모르는 값」이 아니다. 이 둘을 가르는 값이 RFC 5545 에는 없으므로, 「시각 모름」으로 읽는 것은 앱 쪽 약속이 된다.
- 후속 표준 JSCalendar(RFC 8984)는 날짜만 쓰는 값이 없다. `start` 는 필수이고 형식은 LocalDateTime 이다 — [§5.1.1](https://www.rfc-editor.org/rfc/rfc8984.html#section-5.1.1). 대신 `showWithoutTime` 깃발을 둔다. 「the time is not important to display to the user」 — [§4.2.4](https://www.rfc-editor.org/rfc/rfc8984.html#section-4.2.4). 표준의 예는 `"showWithoutTime": true` 와 `"start": "1900-04-01T00:00:00"` 을 함께 적는다 — [§6.4](https://www.rfc-editor.org/rfc/rfc8984.html#section-6.4)
- **[추론]** 그러니 00:00 은 깃발이 함께 있을 때만 「시각 없음」이다. 깃발 없는 00:00 은 진짜 자정이다.

### 1.5 항공편처럼 시작과 끝의 시간대가 다른 일정 — [문서]

- RFC 5545 는 항공편을 직접 예로 든다. 「such as airline flights, that start in one time zone and end in another.」 — [§3.6.5](https://www.rfc-editor.org/rfc/rfc5545.html#section-3.6.5)
- RFC 8984 의 항공편 모델은 「출발 시각 + 소요시간 + 도착지 시간대」다. 예는 `"start": "2020-04-01T09:00:00"`, `"timeZone": "Europe/Berlin"`, `"duration": "PT10H30M"` 에 도착 위치의 `"timeZone": "Asia/Tokyo"` 를 붙인다 — [§6.6](https://www.rfc-editor.org/rfc/rfc8984.html#section-6.6). 도착 시각은 이 값들로 계산해 표시할 수 있다고 적는다. 「Calendar clients could use the end time zone to display the arrival time in Tokyo local time」 — 같은 절

### 1.6 문서의 현재 상태 — [문서]

- RFC 5545 는 폐기되지 않았고 9개 RFC 가 갱신했다 — [메타데이터](https://www.rfc-editor.org/rfc/rfc5545.json). 가장 새로운 [RFC 10051](https://www.rfc-editor.org/rfc/rfc10051.html)(2026년 10월)은 할 일(VTODO) 확장이다.
- 위에서 쓴 절의 [정오표](https://www.rfc-editor.org/errata/rfc5545)
  - §3.3.4·§3.3.5·§3.2.20·§3.8.2.2·§3.8.2.4: 없다.
  - §3.6.1: 확인된 건은 [6109](https://www.rfc-editor.org/errata/eid6109) 하나로, 「여러 날 일정」의 `DTEND` 를 「at least two days after」로 고친다. 위 규칙에는 영향이 없다.
  - §3.2.19·§3.6.5: 문법 표기에 관한 건만 있다(보류·접수·기각 상태). 위 인용 문장을 고치는 건은 아니다.
- 위 판단은 정오표까지다. RFC 10051 외 8개 갱신 RFC 는 본문을 읽지 않았다.

---

## 2. 예약 자료의 표준 칸

### 2.1 schema.org 값 형식 — [문서] (판 V30.1)

| 칸 | 쓰는 곳 | 뜻(원문) | 값 형식 |
|---|---|---|---|
| [`departureTime`](https://schema.org/departureTime) | Trip → [Flight](https://schema.org/Flight) | The expected departure time. | DateTime, Time |
| [`arrivalTime`](https://schema.org/arrivalTime) | Trip → Flight | The expected arrival time. | DateTime, Time |
| [`checkinTime`](https://schema.org/checkinTime) | [LodgingReservation](https://schema.org/LodgingReservation) | The earliest someone may check into a lodging establishment. | DateTime, Time |
| [`checkoutTime`](https://schema.org/checkoutTime) | LodgingReservation | The latest someone may check out of a lodging establishment. | DateTime, Time |
| [`pickupTime`](https://schema.org/pickupTime) | [RentalCarReservation](https://schema.org/RentalCarReservation) | When a taxi will pick up a passenger or a rental car can be picked up. | DateTime |
| [`dropoffTime`](https://schema.org/dropoffTime) | RentalCarReservation | When a rental car can be dropped off. | DateTime |

- 항공 예약은 [FlightReservation](https://schema.org/FlightReservation) 의 `reservationFor` 에 Flight 를 넣는 구조다. 시각은 예약이 아니라 Flight 에 있다.
- 값의 글자 모양
  - [DateTime](https://schema.org/DateTime): `[-]CCYY-MM-DDThh:mm:ss[Z|(+|-)hh:mm]` — 시간대 표시는 대괄호 안이다.
  - [Time](https://schema.org/Time): `hh:mm:ss[Z|(+|-)hh:mm]`
- 여섯 칸 모두 [Date](https://schema.org/Date)(날짜만)가 값 형식에 없다. 값 형식을 정리한 [릴리스 노트 Issue #2271](https://schema.org/docs/releases.html#g2271)도 `checkinTime`·`checkoutTime`·`arrivalTime`·`departureTime` 에는 Time 만 더했다.
- **체크인 시각의 뜻을 주의할 것.** 「가장 이른 입실 가능 시각」이지 손님이 도착하는 시각이 아니다. 체크아웃도 「가장 늦은 퇴실 시각」이다.
- 칸을 강제하는 층은 schema.org 가 아니다. schema.org 는 「very flexible datamodel」에 「a pragmatic view of conformance」를 내세우고, 필수 구조는 응용별 검사 도구의 몫으로 적는다. 「the data structures required for some specific functionality」 — [데이터 모델 문서](https://schema.org/docs/datamodel.html)
- 비행 소요시간 칸도 따로 있다: [`estimatedFlightDuration`](https://schema.org/estimatedFlightDuration)(Duration 또는 Text). 3장의 `elapsetime` 에 해당하는 자리다. **[추론]**

### 2.2 Gmail 예약 마크업의 필수·선택 — [문서]

| 무엇 | 필수(Required) | 선택 | 형식 |
|---|---|---|---|
| [항공](https://developers.google.com/workspace/gmail/markup/reference/flight-reservation) | `reservationFor.departureTime`, `reservationFor.arrivalTime`, `reservationNumber`, `reservationStatus`, `underName`, `underName.name`, `reservationFor`, `flightNumber`, 항공사의 `name`·`iataCode`, 출발·도착 공항의 `name`·`iataCode` | `boardingTime`, `webCheckinTime`, `departureGate`, `arrivalGate`, `departureTerminal`, `arrivalTerminal`, `airplaneSeat` 등 | 시각은 DateTime |
| [숙박](https://developers.google.com/workspace/gmail/markup/reference/hotel-reservation) | `checkinDate`, `checkoutDate`, `reservationNumber`, `reservationStatus`, `underName`, `underName.name`, `reservationFor` 와 숙소의 `name`·`telephone`·`address`(세부 칸 전부) | `numAdults`, `numChildren`, `lodgingUnitDescription`, `price` 등 | 시각은 DateTime |
| [렌터카](https://developers.google.com/workspace/gmail/markup/reference/rental-car) | `pickupTime`, `dropoffTime`, `pickupLocation`·`dropoffLocation` 과 세부 칸, `potentialAction`, `reservationFor` 와 차의 `name`·`model`·`brand`·`rentalCompany`, `reservationNumber`, `reservationStatus`, `underName`, `underName.name` | `pickupLocation.telephone`, `dropoffLocation.telephone` 등 | 시각은 DateTime |

- **체크인 시각이 없어도 되나 — 안 된다.** `checkinDate (Required)`, `checkoutDate (Required)` 이고 형식은 DateTime, 설명은 「Checkin time.」, 「Checkout time.」이다 — [숙박 문서](https://developers.google.com/workspace/gmail/markup/reference/hotel-reservation)
- **도착 시각이 없어도 되나 — 안 된다.** `reservationFor.arrivalTime (Required)`, 설명은 「Expected time of arrival.」이다 — [항공 문서](https://developers.google.com/workspace/gmail/markup/reference/flight-reservation)
- Gmail 의 DateTime 은 시각까지 든 형식이다. 「YYYY-MM-DDTHH:mm:ssZ」 — [날짜 형식 문서](https://developers.google.com/workspace/gmail/markup/reference/datetime-formatting). 세 예약 문서와 날짜 형식 문서 어디에도 날짜만 쓰는 대안은 없다.
- 공식 예는 양쪽 시각을 각 공항의 현지 시각과 시차로 적는다. `"departureTime": "2027-03-04T20:15:00-08:00"`, `"arrivalTime": "2027-03-05T06:30:00-05:00"` — [항공 문서](https://developers.google.com/workspace/gmail/markup/reference/flight-reservation)
- **칸 이름이 schema.org 와 다르다.** Gmail 은 숙박에 `checkinDate`·`checkoutDate` 를 쓰고, 이 둘은 schema.org 현재 정의에 없다([정의 파일](https://schema.org/version/latest/schemaorg-current-https.jsonld) 검색). Gmail 은 「A few of the schema structures used by Gmail differ from the schema.org standard vocabulary.」라고 밝힌다 — [제안 문서](https://developers.google.com/workspace/gmail/markup/reference/schema-org-proposals)
- 위 필수 표시는 예약 문서의 것이다. [Flight 형식 참조](https://developers.google.com/workspace/gmail/markup/reference/types/Flight)에는 시각 칸에 Required 가 없다.

**[추론]** 이 필수 표시는 「메일을 보내는 쪽이 Gmail 카드에 나오려면 채워야 하는 값」이다. 앱 내부 저장 모델을 묶는 규칙은 아니다. 앱이 예약 자료를 이 형식으로 내보내는 날이 오면, 시각 모르는 예약은 마크업을 만들 수 없다는 뜻이 된다.

---

## 3. 상대 공항 시각의 무료 공식 출처

### 3.1 앱이 지금 얻는 것 — [코드]

| 파일 | 주소 | 읽는 칸 | 시각의 뜻 |
|---|---|---|---|
| `BabyCare/Services/FlightScheduleService.swift` | `https://apis.data.go.kr/B551177/PaxFltSched` 의 `getPaxFltSchedDepartures`·`getPaxFltSchedArrivals` | `flightid`, `st`, `firstdate`, `lastdate`, 요일 칸, `airline`, `airport`, `airportcode` | 9행 주석: 인천 쪽 시각. 상대 공항 시각은 없다고 적어 둠 |
| `BabyCare/Services/FlightStatusService.swift` | `https://apis.data.go.kr/B551177/StatusOfPassengerFlightsOdp` 의 `getPassengerDeparturesOdp`·`getPassengerArrivalsOdp` | `flightId`, `scheduleDateTime`, `estimatedDateTime`, `remark`, `gatenumber`, `terminalId`, `airport`, `carousel`, `exitnumber` | 13행 주석: 인천 출발 또는 인천 도착 |

운항현황 응답의 `elapsetime`, `airportCode`, `cityCode`, 경유지 칸은 `FlightStatusParser` 가 읽지 않는다. `elapsetime` 은 앱·테스트 폴더 전체에서 0건이다(같은 파일 검색으로 `flightId` 는 찾아짐).

### 3.2 칸 전수 대조 — [문서]

**결론: 두 값 모두 직접 주는 칸이 없다.**

| 묻는 값 | 칸 |
|---|---|
| 인천 출발편의 상대 공항 **도착** 시각 | 없음 |
| 상대 공항에서 오는 편의 상대 공항 **출발** 시각 | 없음 |

아래 표의 칸은 각 포털 상세 페이지의 명세와 참고문서(활용가이드)에서 뽑았다. 공공데이터포털에 등록된 것은 전부 무료이고 이용허락범위 제한이 없다. 화물 전용 API 는 뺐다.

**인천국제공항공사**

| API | 서비스 | 시각 칸 | 범위 | 상대 공항 시각 |
|---|---|---|---|---|
| [여객편 운항현황(다국어)](https://www.data.go.kr/data/15095093/openapi.do) ★앱 사용 | `StatusOfPassengerFlightsOdp` | `scheduleDateTime`, `estimatedDateTime`(HHMM), `elapsetime` | 조회 당일 | 없음. 소요시간만 있음(3.3) |
| [여객기 정기운항편 일정 정보](https://www.data.go.kr/data/15095059/openapi.do) ★앱 사용 | `PaxFltSched` | `st`(정기운항 시작 시간) | 한 시즌 | 없음 |
| [여객편 주간 운항 현황](https://www.data.go.kr/data/15095074/openapi.do) | `StatusOfPassengerFlightsDSOdp` | `scheduleDateTime`, `estimatedDateTime` | D+0~D+6 | 없음 ⚠️문구 3.6 |
| [여객기 운항 현황 상세 조회](https://www.data.go.kr/data/15112968/openapi.do) | `StatusOfPassengerFlightsDeOdp` | `scheduleDateTime`, `estimatedDateTime` | D-3~D+6 | 없음 |
| [여객기 정기운항편 현황 상세 조회](https://www.data.go.kr/data/15114085/openapi.do) | `StatusOfPaxFltSched` | `st` | 한 시즌 | 없음 |
| [여객기 운항편 조회(면세점용)](https://www.data.go.kr/data/15134279/openapi.do) | `statusOfAPaxFlt4DutyFree` | `scheduleDateTime`, `estimatedDateTime` | D-3~D+6 | 없음 |
| [여객기 정기운항편 조회(면세점용)](https://www.data.go.kr/data/15134281/openapi.do) | `statusOfSPaxFlt4DutyFree` | `st`(출발시간/도착시간) | 시즌 | 없음 |
| [여객기 정기운항편 조회(관광플랫폼용)](https://www.data.go.kr/data/15143060/openapi.do) | `statusOfSPaxFlt4TripPlatform` | `st`(출발시간/도착시간) | 시즌 | 없음 |
| [항공기 운항 현황 상세 조회](https://www.data.go.kr/data/15140153/openapi.do) | `statusOfAllFltDeOdp` | `scheduleDatetime`, `estimatedDatetime` | D-3~D+6 | 없음 ⚠️문구 3.6 |
| [제2터미널 여객기 운항 현황 상세 조회](https://www.data.go.kr/data/15166252/openapi.do) | `statusOfPaxFltDeOdpT2` | `scheduleDatetime`, `estimatedDatetime` | D-3~D+6 | 없음 ⚠️문구 3.6 |
| [여객기 Ferry편 운항정보](https://www.data.go.kr/data/15166250/openapi.do) | `statusOfFerryFltOdp` | `scheduleDatetime`, `estimatedDatetime`, `landingDatetime` | D~D+1 | 없음 |
| [항공기 수하물 정보(조업사용)](https://www.data.go.kr/data/15144042/openapi.do) | `statusOfBaggageClaimDesk` | 위와 같은 세 칸과 수하물 시각 | D~D+1 | 없음 |
| [운항마감정보](https://www.data.go.kr/data/15098227/openapi.do) | `FlightClosingInfoSpot` | `msDate`, `msStime`(스케줄 시간) | 통계 | 없음 |

- 같은 칸 `st` 의 뜻이 형제 API 에서 풀린다. 앱이 쓰는 API 는 「정기운항 시작 시간」이라고만 적지만, [관광플랫폼용](https://www.data.go.kr/data/15143060/openapi.do)은 출발 쪽을 「출발시간」, 도착 쪽을 「도착시간」으로 적는다.
- 공식 활용가이드는 `airport` 를 「상대공항」이라 부르고 **공항 이름과 코드만** 준다. 상대 공항의 시각 칸은 없다 — [운항현황 활용가이드 V1.2](https://www.data.go.kr/cmm/cmm/fileDownload.do?atchFileId=FILE_000000003696992&fileDetailSn=1)

**한국공항공사** — 스스로 「인천국제공항을 제외한」 공항을 맡는다고 적는다. 다만 일부 공식 예시에 인천이 나온다(아래).

| API | 서비스 | 시각 칸 | 상대 공항 시각 |
|---|---|---|---|
| [항공기 운항 스케줄 정보_GW](https://www.data.go.kr/data/15158949/openapi.do) `/int` | `flight-schedule` | `internationalTime`(「국제선 운항 시간」) 한 칸 | 없음으로 본다. 한 칸뿐이고 공식 예시 10줄이 전부 `0000` (3.5) |
| 같은 API `/taxfree-int` | `flight-schedule` | `st`(출발시간) 한 칸 | 없음 |
| 같은 API `/dom` | `flight-schedule` | `domesticStartTime`, `domesticArrivalTime` | **있음. 단 국내선만** (3.4) |
| [실시간 항공기 운항정보 조회_GW](https://www.data.go.kr/data/15158625/openapi.do) | `flight-status` | `scheduledatetime`, `estimateddatetime`, `std`, `etd` | 없음. 편마다 시각이 한 쌍(예정·변경)뿐이다 |
| [실시간 항공기 운항정보 검색_GW](https://www.data.go.kr/data/15160195/openapi.do) | `flight-search` | `std`, `etd` | 없음. 범위가 「전국공항(인천국제공항 제외)」 |
| [면세점용 실시간 항공기 운항정보_GW](https://www.data.go.kr/data/15163384/openapi.do) | `dutyfree` | `scheduledatetime`, `estimateddatetime` | 없음. 범위가 「전국공항(인천국제공항 제외)」 |
| [전국공항 실시간 항공기 기종 및 등록번호 정보_GW](https://www.data.go.kr/data/15158519/openapi.do) | `flight-aircraft-status` | `std`, `etd` | 없음. 범위가 「전국공항(인천국제공항 제외)」 |
| [노선별 소요시간 및 거리 정보_GW](https://www.data.go.kr/data/15158851/openapi.do) | `flight-routes` | `TIME`(노선 소요시간, 분) | 없음. 소요시간만 있음(3.3) |

**국토교통부**

| 출처 | 형태 | 시각 칸 | 상대 공항 시각 |
|---|---|---|---|
| [(TAGO) 국내항공운항정보](https://www.data.go.kr/data/15098526/openapi.do) | API `1613000/DmstcFlightNvgInfo` | `depPlandTime`, `arrPlandTime` | **있음. 단 국내선만** (3.4) |
| [항공기 출도착현황](https://www.data.go.kr/data/15092485/fileData.do) | API 아님. [항공정보포털 화면](https://www.airportal.go.kr/airport/aircraftInfo.do)으로 가는 링크 | 계획시간, 예상시간, 실제시간 | 없음. 한 공항 쪽 시각(3.5) |
| [항공사 스케줄 화면](https://www.airportal.go.kr/airline/airplaneSchedule.do) | API 아님 | 화면에 출발시간, 내부 이름 `depTime`·`arrTime` | **확인 못 함**(3.5) |

공공데이터포털 검색으로는 국토교통부의 국제선 운항 스케줄 API 를 찾지 못했다(검색어는 5장).

### 3.3 계산 재료 둘 — [문서]

아래로 얻는 값은 **공식 시각이 아니라 계산값**이다.

#### (가) `elapsetime` — 앱이 이미 부르는 API 의 칸

- 문서 정의
  - 도착 쪽: `elapsetime | 소요시간 | … | 0513 | 도착소요시간(HHMM)`
  - 출발 쪽: `elapsetime | 소요시간 | … | 0937 | 운항소요시간(HHMM)`
  - 출처: [운항현황 활용가이드 V1.2](https://www.data.go.kr/cmm/cmm/fileDownload.do?atchFileId=FILE_000000003696992&fileDetailSn=1). [포털 명세표](https://www.data.go.kr/data/15095093/openapi.do)는 출발 쪽을 「출발 소요시간(HHMM)」으로 적어 문구가 조금 다르다.
- 문서의 경고 두 가지 — 같은 활용가이드
  - 오차: 「항공사에서 보내주는 소요시간으로 실제 시간과 오차가 있을수 있습니다.」
  - 누락: 「항공사에서 보내주지 않는 시간은 제공되지 않습니다.」, 도착 쪽은 「항공사에서 제공하지 않는 경우도 있음」
- 범위는 당일뿐이다. 「조회 당일에 대한 데이터를 제공합니다.」 — [포털](https://www.data.go.kr/data/15095093/openapi.do). 요청 칸에 날짜가 없다. 시간표에 넣는 미래 날짜에는 쓸 수 없고 비행 당일에만 나온다.
- 여러 날을 주는 API(주간 운항, 운항 현황 상세 등)에는 `elapsetime` 이 없다. 이 칸은 대조한 문서 가운데 운항현황(다국어)에만 있다.
- 호출 한도는 개발 계정 일 1000, 운영 계정 신청 시 일 1000000 이다 — [포털](https://www.data.go.kr/data/15095093/openapi.do)
- 공식 예시의 같은 편명 줄에 값이 조금씩 다르다(`0937`, `0953`, `0952`). **[추론]** 노선 고정값이 아니라 줄마다 오는 값으로 보인다.
- **[추론]** 계산 모양: 인천 출발편은 인천 쪽 시각에 더하고, 인천 도착편은 인천 쪽 시각에서 뺀다. RFC 8984 §6.6 의 항공편 모델과 같은 모양이다. 예정·변경 시각 중 어느 쪽에 더하는지는 문서에 없다.

#### (나) `flight-routes` — 노선별 소요시간표

- 칸: `ODP`(출발공항 코드), `ARP`(도착공항 코드), `TOF`, `KM`, `TIME`(노선 소요시간(분)) — [활용가이드](https://www.data.go.kr/cmm/cmm/fileDownload.do?atchFileId=FILE_000000003705902&fileDetailSn=1)
- 공식 예시에 인천이 있다. `ODP=ICN, ARP=ADD, KM=9204.0, TIME=705.0`, `ODP=ICN, ARP=AKJ, KM=1518.0, TIME=128.0`. 예시의 `totalCount` 는 739 다.
- 편별이 아니라 노선별 값이다. 날짜 제한은 없어 미래 일정에 붙일 수 있다는 뜻이 된다. **[추론]**
- 요청 칸은 `serviceKey`, `pageNo`, `numOfRows`, `type` 뿐이라 공항으로 거를 수 없다. 전체를 받아야 한다.
- 데이터 갱신주기는 N/A 이고, 소요시간의 산정 기준은 적혀 있지 않다.
- **문서끼리 어긋난다.** 활용가이드는 `ARP`=도착, `ODP`=출발인데 [포털 명세](https://www.data.go.kr/data/15158851/openapi.do)는 `ARP`=출발공항명, `ODP`=도착공항명이다. 활용가이드 쪽 예시가 ICN 에서 나가는 노선처럼 읽히지만 단정할 수 없다.

#### 두 재료 공통 — 시간대 칸이 없다

계산값을 상대 공항 현지 시각으로 보이려면 그 공항의 시간대가 있어야 한다. 그런데 이번에 본 활용가이드 15건과 포털 명세 전부에 timezone·time zone·표준시·시차·UTC·GMT·KST 는 0건이다(같은 검색으로 `elapsetime` 등 있는 값은 찾아짐). 공항 목록 API 도 이름과 코드뿐이다.

- [공항 코드 정보_GW](https://www.data.go.kr/data/15158948/openapi.do): 공항명(언어별), 공항 코드
- [취항 도시 현황 조회](https://www.data.go.kr/data/15095067/openapi.do): 국가명, 도시명, 코드
- [세계공항_정보](https://www.data.go.kr/data/3051587/fileData.do): 공항명, IATA·ICAO 코드, 지역, 국가, 도시

같은 까닭에 인천 쪽 시각이 한국 시각이라는 것도 문서에 명시되어 있지 않다. 앱의 `FlightStatusParser.seoul` 은 합리적인 전제지만 문서 문구로 확인한 값은 아니다.

### 3.4 국내선은 양쪽 시각이 있다 — [문서]

- [TAGO 국내항공운항정보](https://www.data.go.kr/data/15098526/openapi.do): `depPlandTime`(출발시간 YYYYMMDDHHMI), `arrPlandTime`(도착시간). 범위는 「국내선 항공운항정보」다.
- 한국공항공사 [`flight-schedule/dom`](https://www.data.go.kr/data/15158949/openapi.do): `domesticStartTime`, `domesticArrivalTime`. 공식 예시에 `startcity=인천`, `arrivalcity=대구`, `0515 → 0605` 가 있다. 다만 그 줄의 운항 기간은 2009년이다.

둘 다 인천 출발 국제선에는 쓸 수 없다.

### 3.5 살펴봤지만 답이 되지 않은 것

**한국공항공사 `flight-schedule/int`** — [문서]

- 공식 예시 10줄이 모두 `airport=방콕/수완나품` 또는 `클락필드`, `city=인천`, `cityCode=ICN`, `internationalIoType=IN`, `internationalTime=0000` 이다 — [활용가이드](https://www.data.go.kr/cmm/cmm/fileDownload.do?atchFileId=FILE_000000007619222&fileDetailSn=1)
- 해외 공항을 기준공항으로 둔 인천 구간 줄이 있다는 뜻이다. 그래서 이론상 상대 공항 시각일 가능성이 있다. 그러나 **[확인 못 함]** — 시각 칸이 한 칸뿐이고 어느 공항 시각인지 문서에 없으며, 예시 값이 전부 `0000` 이다.

**항공정보포털 「항공사 스케줄」** — [코드] [확인 못 함]

- 화면 안내는 「항공사별 운항스케줄, 출도착 시간 등에 대한 정보」를 준다고 적는다. 출발 공항 기본값은 인천이고, 표 머리글은 항공사·편명·출발시간·도착지·운항스케줄이다 — [공개 화면 소스](https://www.airportal.go.kr/airline/airplaneSchedule.do)
- 그런데 「도착지」 칸에 넣는 값의 내부 이름이 `arrTime` 이고, 주석 처리된 모바일 예시에는 「도착시간 13:01」이 있다. 도착 **시각**인지 도착 **공항**인지 소스만으로는 가를 수 없다.
- 화면이 쓰는 내부 호출을 직접 보내 값을 보려 했으나 이 환경의 실행 권한 심사에서 막혔고, 우회하지 않았다. 공개 API 문서가 없는 화면 내부 호출이라, 값이 시각이더라도 앱에 쓸 수 있는지는 별도 문제다.

**항공정보포털 「항공기 출도착」** — [코드]

- 국내 공항을 고르면 그 공항 쪽 계획·예상·실제 시각을 보여 준다. 실제 시각의 기준은 「게이트에서 항공기가 실제 움직이기 시작」, 「게이트에서 항공기가 완전히 멈춘 시점」이다 — [공개 화면 소스](https://www.airportal.go.kr/airport/aircraftInfo.do)
- 상대 공항 시각은 없다. 공공데이터포털의 [항공기 출도착현황](https://www.data.go.kr/data/15092485/fileData.do)은 API 가 아니라 이 화면으로 가는 링크다.

**해외 공식 출처** — 핵심 범위 밖이라 한 곳만 확인했다.

- 일본 공공교통 오픈데이터 카탈로그에 [하네다 국제선 터미널 시간표](https://ckan.odpt.org/dataset/a_flightschedule-tiat) 등 항공편 자료가 있다. 그러나 표시가 「チャレンジ2026限定」이고 「公共交通オープンデータチャレンジ限定ライセンス」를 읽으라고 안내한다. 칸 명세는 확인 못 했다. 앱에 쓸 수 있는 조건인지는 이 표시만으로는 어렵다고 본다. **[추론]**
- 유료 서비스는 무료 정책에 따라 조사하지 않았다.

### 3.6 문구가 헷갈리는 칸 세 곳 — [문서]

문구만 읽으면 상대 공항 시각처럼 보이지만, 그렇게 믿으면 안 된다.

| API | 어디 | 적힌 문구 | 왜 의심하나 |
|---|---|---|---|
| [항공기 운항 현황 상세](https://www.data.go.kr/data/15140153/openapi.do) `getFltArrivalsDeOdp` | 도착 쪽 `scheduleDatetime` | 「출발예정일시」 | 도착·출발 양쪽 문구가 같다. 형제 API [Ferry](https://www.data.go.kr/data/15166250/openapi.do)·[수하물](https://www.data.go.kr/data/15144042/openapi.do)의 도착 쪽은 「도착예정일시」 |
| [제2터미널 상세](https://www.data.go.kr/data/15166252/openapi.do) `getPaxFltArrivalsDeOdpT2` | 도착 쪽 `scheduleDatetime` | 「출발예정일시」 | 위와 같음 |
| [주간 운항 현황](https://www.data.go.kr/data/15095074/openapi.do) `getPassengerDeparturesDSOdp` | 출발 쪽 `scheduleDateTime` | 「도착예정시간」 | 오퍼레이션 설명은 인천 「출발」 운항 현황이고 양쪽 문구가 같다 |

**[추론]** 복사 과정의 오기로 보인다. 문서만으로 단정할 수는 없어 4장에 남긴다.

### 3.7 시각을 못 얻는 경우가 공식으로 있다 — [문서]

정기운항편 API 는 시즌 경계에 자료가 비어 있을 수 있다고 적는다. 「관계기간의 승인이 끝나지 않아 시즌 전체 데이터가 제공되지 않을 수 있습니다.」 — [포털](https://www.data.go.kr/data/15095059/openapi.do). 시즌은 하계 3월말~10월말, 동계 10월말~익년 3월말이다.

### 3.8 앱 주석과 공식 문서 대조

| 코드 | 공식 문서 |
|---|---|
| `FlightScheduleService.swift:29` 「편명 필터가 안 먹어」 | 명세에 편명 요청 칸이 아예 없다. 칸은 `serviceKey`, `numOfRows`, `pageNo`, `lang`, `airport`, `type` 이다 — [활용가이드](https://www.data.go.kr/cmm/cmm/fileDownload.do?atchFileId=FILE_000000003697265&fileDetailSn=1). 정기운항 계열 중 [관광플랫폼용](https://www.data.go.kr/data/15143060/openapi.do)·[면세점용](https://www.data.go.kr/data/15134281/openapi.do)에는 `flightId` 요청 칸이 있다(실제 동작은 미확인) |
| `FlightScheduleService.swift:9` 상대 공항 쪽 시각은 시간표에 없다 | 일치 |
| `FlightStatusService.swift:9` 당일치만 준다 | 일치 |

---

## 4. 확인 못 한 것

| 무엇 | 왜 못 했나 | 닫는 법 |
|---|---|---|
| `elapsetime` 이 실제 응답에 오는지, 얼마나 비는지 | 키 호출을 하지 않음 | 운항현황 API 를 당일 몇 편 호출 |
| `elapsetime` 이 게이트 기준인지 비행시간인지, 경유편은 전체인지 | 문서에 없음 | 인천국제공항공사 인프라DX팀 문의 |
| `flight-routes` 전체 내용(인천 노선 범위, 반대 방향 줄, `TIME` 기준, `ARP`·`ODP` 뜻) | 키 필요, 문서 충돌 | 전체 호출 1회, 한국공항공사 데이터융합부(02-2660-4803) 문의 |
| `flight-schedule/int` 의 `internationalTime` 이 어느 공항 시각인지, `0000` 아닌 값이 있는지 | 키 필요, 문서에 없음 | `schArrvCityCode` 등으로 호출 |
| 항공정보포털 스케줄 화면의 `arrTime` 값 | 내부 호출이 권한 심사에서 막힘 | 사람이 화면에서 인천→도착지를 한 번 검색 |
| 3.6 의 문구 세 곳이 오기인지 | 키 필요 | 같은 편을 다른 API 와 비교 |
| 응답 시각의 시간대 | 문서에 없음 | 운영기관 문의 |
| 여객기 Ferry편, 제2터미널 상세, 면세점용 실시간_GW 의 활용가이드 | 포털에 참고문서가 없어 포털 명세만 봄 | — |
| 일본 공공교통 오픈데이터의 칸 명세·이용 조건 | [어휘 문서](https://vocab.odpt.org/) 인증서 오류로 열지 못했고, 개발자 사이트 본문이 안 읽힘 | 필요할 때 직접 열람 |

---

## 5. 조사 범위와 판

- 명세: [RFC 5545](https://www.rfc-editor.org/rfc/rfc5545.html)(2009-09), [RFC 8984](https://www.rfc-editor.org/rfc/rfc8984.html)(2021-07, 폐기·갱신 없음)
- schema.org: V30.1, [공식 정의 파일](https://schema.org/version/latest/schemaorg-current-https.jsonld)과 칸별 페이지 대조
- Gmail 문서: 항공·숙박·렌터카 마지막 갱신 2026-09-10 UTC, 날짜 형식 2026-09-03 UTC
- 공공데이터포털: 상세 페이지의 명세, 기능별 요청·응답 표, 참고문서(docx) 15건을 받아 대조. 운항현황 활용가이드는 V1.2(2023-07-28), 노선별 소요시간 활용가이드는 제정 2026-08-11
- 포털 검색어: 인천국제공항공사, 한국공항공사, 운항, 항공기 운항, 항공 스케줄, 항공 운항 스케줄, 항공정보포털, 여객편, 도착시간 항공, 국토교통부 항공, 항공기 출도착, 항공편, 세계공항, 공항 코드, 항공통계, 항공교통, 운항 정보 국제선
- 저장소에서 읽은 것: 위 두 서비스 파일. 키 파일은 열지 않았다.

## 6. 실측 — 앱이 쓰는 키로 실제 호출(2026-11-06)

위 문서 조사 뒤 실제로 불러 본 값이다. 문서 기준 서술보다 이쪽이 우선이다.

- 운항현황 `getPassengerDeparturesOdp` 한 편의 응답은 35칸, `getPassengerArrivalsOdp` 는 22칸이다. 시각 칸은 `scheduleDateTime`, `estimatedDateTime`, `elapsetime` 셋뿐이고 앞의 둘은 인천 쪽 시각이다.
- `elapsetime` 은 그날 인천 출발 1,185줄 전부 빈 값이었다(간사이행 76줄 포함). 계산 재료로 쓸 수 없다.
- 정기 시간표 `getPaxFltSchedDepartures` 한 줄의 시각 칸은 `st` 하나다.
- `https://apis.data.go.kr/B551178/flight-routes` 는 경로 네 가지 모두 `NO_OPENAPI_SERVICE_ERROR` 였다. 호출 경로나 활용 신청 문제인지는 가리지 못했다.

양쪽 시각을 주는 민간 항공 자료 API 는 있다. 무료로 되는 범위는 요금표 문서 기준이고 아직 호출해 보지 않았다.

- [aviationstack 요금표](https://aviationstack.com/pricing): 무료는 월 100회 · 실시간 운항 포함 · 미래 일정·노선 제외.
- [AirLabs routes](https://airlabs.co/docs/routes): `dep_time`·`arr_time` 을 주지만 무료 표시 칸에 시각이 없다.

