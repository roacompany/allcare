import Foundation
import ImageIO
import MapKit
import Vision
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Babycare AI로 추가 — 읽는 쪽(설계 §9). 전부 폰 안 · 돈·서버 없음 · 이미지는 밖으로 나가지 않는다.

/// 이미지 → 글자(Vision · 한국어·일본어·영어).
struct VisionCaptureTextReader: CaptureTextReading {
    func texts(from images: [Data]) async throws -> [String] {
        var out: [String] = []
        for data in images {
            out.append(try Self.recognize(data))
        }
        return out
    }

    static func recognize(_ data: Data) throws -> String {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw CaptureError.unreadableImage }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["ko-KR", "ja-JP", "en-US"]
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        let pieces: [(CGRect, String)] = (request.results ?? []).compactMap { observation in
            guard let top = observation.topCandidates(1).first else { return nil }
            return (observation.boundingBox, top.string)
        }
        return CaptureTextLayout.lines(pieces)
    }
}

/// 숙소 이름 → 주소(애플 지도 · 키·돈 없음). 여행 도시 근처를 먼저 찾는다.
struct AppleMapsPlaceAddress: PlaceAddressLooking {
    func address(for name: String, near area: TripRouteArea) async -> String? {
        await Self.lookup(name: name, area: area)
    }

    @MainActor
    private static func lookup(name: String, area: TripRouteArea) async -> String? {
        let cityRequest = MKLocalSearch.Request()
        cityRequest.naturalLanguageQuery = AppleMapsRouteTimeService.cityQuery(area.city)
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = name
        do {
            if let center = try await MKLocalSearch(request: cityRequest).start().mapItems.first?.placemark.coordinate {
                request.region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 1.5, longitudeDelta: 1.5))
            }
            guard let item = try await MKLocalSearch(request: request).start().mapItems.first else { return nil }
            return PlaceAddressFormat.address(item.placemark)
        } catch {
            logSilent("숙소 주소 찾기 실패", error: error, logger: AppLogger.travel)
            return nil
        }
    }
}

/// 지도 장소 → 주소 한 줄(숙소 찾기 · Babycare AI로 추가가 같이 쓴다).
enum PlaceAddressFormat {
    static func address(_ p: MKPlacemark) -> String? {
        let parts = [p.administrativeArea, p.locality, p.subLocality, p.thoroughfare, p.subThoroughfare].compactMap { $0 }
        let joined = parts.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        return joined.isEmpty ? p.title : joined
    }
}

enum BookingCaptureServices {
    /// iOS 26 + 애플 인텔리전스가 켜져 있으면 기기 안 언어 모델, 아니면 규칙(항공편만).
    static func standardExtractor() -> CaptureExtracting {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), AppleIntelligenceCaptureExtractor.isAvailable {
            return AppleIntelligenceCaptureExtractor()
        }
        #endif
        return RuleCaptureExtractor()
    }
}

#if canImport(FoundationModels)

// MARK: - 애플 인텔리전스(기기 안 언어 모델) — 항공편 · 숙소 · 렌터카

@available(iOS 26.0, *)
@Generable(description: "Bookings found on a travel booking confirmation screen")
struct CaptureModelBookings {
    @Guide(description: "Flights on the screen. Empty if none.")
    var flights: [CaptureModelFlight]
    @Guide(description: "Hotel or lodging stays on the screen. Empty if none.")
    var hotels: [CaptureModelHotel]
    @Guide(description: "Rental cars on the screen. Empty if none.")
    var rentals: [CaptureModelRental]
}

@available(iOS 26.0, *)
@Generable
struct CaptureModelFlight {
    @Guide(description: "Flight number such as KE725")
    var flightNumber: String?
    @Guide(description: "Departure date exactly as written on the screen")
    var date: String?
    @Guide(description: "Departure time, 24-hour HH:mm")
    var departTime: String?
    @Guide(description: "Arrival time, 24-hour HH:mm")
    var arriveTime: String?
    @Guide(description: "Departure airport IATA code if shown, otherwise the airport name as written")
    var fromAirport: String?
    @Guide(description: "Arrival airport IATA code if shown, otherwise the airport name as written")
    var toAirport: String?
}

@available(iOS 26.0, *)
@Generable
struct CaptureModelHotel {
    @Guide(description: "Hotel name as written")
    var name: String?
    @Guide(description: "Hotel address as written")
    var address: String?
    @Guide(description: "Check-in date exactly as written")
    var checkInDate: String?
    @Guide(description: "Check-in time, 24-hour HH:mm")
    var checkInTime: String?
    @Guide(description: "Check-out date exactly as written")
    var checkOutDate: String?
    @Guide(description: "Check-out time, 24-hour HH:mm")
    var checkOutTime: String?
    @Guide(description: "Last date of free cancellation exactly as written")
    var freeCancelDate: String?
    @Guide(description: "Time of the free cancellation deadline, 24-hour HH:mm")
    var freeCancelTime: String?
}

@available(iOS 26.0, *)
@Generable
struct CaptureModelRental {
    @Guide(description: "Rental car company name")
    var company: String?
    @Guide(description: "Pick-up place as written")
    var pickupPlace: String?
    @Guide(description: "Pick-up date exactly as written")
    var pickupDate: String?
    @Guide(description: "Pick-up time, 24-hour HH:mm")
    var pickupTime: String?
    @Guide(description: "Return place as written")
    var returnPlace: String?
    @Guide(description: "Return date exactly as written")
    var returnDate: String?
    @Guide(description: "Return time, 24-hour HH:mm")
    var returnTime: String?
    @Guide(description: "Last date of free cancellation exactly as written")
    var freeCancelDate: String?
    @Guide(description: "Time of the free cancellation deadline, 24-hour HH:mm")
    var freeCancelTime: String?
}

@available(iOS 26.0, *)
struct AppleIntelligenceCaptureExtractor: CaptureExtracting {
    var reader: CaptureReader { .appleIntelligence }

    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    static let instructions = """
    You read text recognized from a screenshot of a travel booking confirmation (flight ticket, hotel stay, or rental car).
    Copy only values that are written in the text. Leave a field empty when it is not written. Never guess.
    Keep dates exactly as written. Write times as 24-hour HH:mm.
    """

    /// 기기 모델 입력 상한(약 4천 토큰) 안 — 한 장의 글을 앞에서부터 자른다.
    static let maxCharacters = 2400

    func extract(from text: String) async throws -> CaptureExtraction {
        guard Self.isAvailable else { throw CaptureError.modelUnavailable }
        let session = LanguageModelSession(instructions: Self.instructions)
        let prompt = "Text from one booking screenshot:\n\n" + String(text.prefix(Self.maxCharacters))
        let response = try await session.respond(to: prompt, generating: CaptureModelBookings.self)
        return Self.extraction(response.content)
    }

    static func extraction(_ m: CaptureModelBookings) -> CaptureExtraction {
        CaptureExtraction(
            flights: m.flights.map {
                CaptureExtraction.Flight(flightNumber: $0.flightNumber, date: $0.date, departTime: $0.departTime,
                                         arriveTime: $0.arriveTime, fromAirport: $0.fromAirport, toAirport: $0.toAirport)
            },
            hotels: m.hotels.map {
                CaptureExtraction.Hotel(name: $0.name, address: $0.address, checkInDate: $0.checkInDate, checkInTime: $0.checkInTime,
                                        checkOutDate: $0.checkOutDate, checkOutTime: $0.checkOutTime,
                                        freeCancelDate: $0.freeCancelDate, freeCancelTime: $0.freeCancelTime)
            },
            rentals: m.rentals.map {
                CaptureExtraction.Rental(company: $0.company, pickupPlace: $0.pickupPlace, pickupDate: $0.pickupDate,
                                         pickupTime: $0.pickupTime, returnPlace: $0.returnPlace, returnDate: $0.returnDate,
                                         returnTime: $0.returnTime, freeCancelDate: $0.freeCancelDate, freeCancelTime: $0.freeCancelTime)
            })
    }
}

#endif
