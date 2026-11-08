# 여행 일정표

일정에 관한 판단은 `Itinerary` 한 곳에서 한다. 규칙 = `docs/superpowers/specs/2026-11-06-itinerary-design.md` · 말 = `GLOSSARY.md` · 까닭 = `docs/adr/0001-itinerary-is-derived-and-never-invents-time.md`.

- 예약의 시각은 `TripWhen` 으로 읽는다. `.time` 이 nil 이면 **시각 미정**이고 줄에 「미정」으로 나온다.
- 화면은 `Itinerary` 가 준 글자를 그대로 그린다. 시각 비교·순서·글자 조립은 `ItineraryWalker` 에 넣는다.
- 저장은 사람이 넣은 사실만 한다. 시각은 시각 고르기 창에서 「확인」을 눌러야 들어간다(`TripOptionalTimeRow`).
- 일정·예약·넣는 창을 고친 판은 올리기 전에 `-only-testing:BabyCareUITests/TripWholeTripFlowTests` 를 돌린다(CI 는 안 태운다). 끝난 기준 = 빈 여행에 전부 넣은 일정표가 사람이 움직이는 순서로 읽히고, 그림 /tmp/babycare_screenshots/whole 을 눈으로 봤다.

🩸 2026-11-06 빌드 113: 칸을 전부 재고 올렸는데 완성된 일정표를 안 봐서 「체크인 → 렌터카 → 출발」로 나갔다.
