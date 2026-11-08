import Foundation

/// Babycare AI로 추가 한 번의 결과(확인 시트가 그린다).
struct CaptureOutcome: Equatable, Sendable {
    var items: [CapturedBooking]
    var reader: CaptureReader
    var imageCount: Int
    /// 이미지에서 글자를 하나도 못 읽었다(이미지가 깨졌거나 읽기 실패).
    var failed: Bool
}

/// Babycare AI로 추가(설계 §9) — 이미지 → 글자 → 예약 → 비는 칸 채우기. 저장은 고른 것만, 기존 예약 저장 길로.
/// ⛔ 뷰는 서비스를 직접 부르지 않는다 — 여기만 거친다(arch R1).
extension TripDetailViewModel {
    func readCaptures(_ images: [Data]) async -> CaptureOutcome {
        let texts: [String]
        do {
            texts = try await captureText.texts(from: images)
        } catch {
            logSilent("예약 이미지 글자 읽기 실패", error: error, logger: AppLogger.travel)
            return CaptureOutcome(items: [], reader: captureExtractor.reader, imageCount: images.count, failed: true)
        }
        var merged = CaptureExtraction()
        var usedModel = false
        for text in texts where !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            do {
                merged.append(try await captureExtractor.extract(from: text))
                if captureExtractor.reader == .appleIntelligence { usedModel = true }
            } catch {
                // 기기 모델이 못 읽으면 규칙으로 — 항공편만이라도.
                logSilent("기기 모델로 예약을 못 뽑음 — 규칙으로", error: error, logger: AppLogger.travel)
                merged.append(CaptureExtraction(flights: RuleCaptureExtractor.flights(in: text)))
            }
        }
        let built = CaptureBookingBuilder.build(merged, trip: trip, calendar: calendar)
        let items = await enrichCaptured(built)
        return CaptureOutcome(items: items, reader: usedModel ? .appleIntelligence : .rulesFlightsOnly,
                              imageCount: images.count, failed: false)
    }

    /// 고른 것만 저장한다 — 저장을 막는 까닭이 남은 예약은 건너뛴다. 저장한 수.
    @discardableResult
    func addCaptured(_ items: [CapturedBooking]) async -> Int {
        var added = 0
        for item in items where item.selected {
            let booking = TripBookingForm.normalized(item.booking)
            guard TripBookingForm.problem(booking, calendar: calendar) == nil else { continue }
            await upsertBooking(booking)
            added += 1
        }
        return added
    }

    /// 비는 칸 채우기 — 항공편은 인천공항 시간표(편명 + 날짜), 숙소 주소는 지도에서 한 번.
    private func enrichCaptured(_ items: [CapturedBooking]) async -> [CapturedBooking] {
        var out = items
        let area = TripRouteArea(city: trip.city, countryCode: trip.countryCode)
        for i in out.indices {
            let b = out[i].booking
            switch b.kind {
            case .flight:
                guard let day = out[i].day, let number = b.flightNumber,
                      b.depart?.time == nil || b.arrive?.time == nil || b.fromAirport == nil || b.toAirport == nil else { continue }
                if case .found(let row) = await lookupFlight(number: number, day: day) {
                    out[i] = CaptureBookingBuilder.fill(out[i], with: row, calendar: calendar)
                }
            case .hotel:
                guard b.address == nil, let name = b.name else { continue }
                if let address = await placeAddress.address(for: name, near: area) {
                    out[i].booking.address = address
                }
            case .rentalCar, .unknown:
                break
            }
        }
        return out
    }
}
