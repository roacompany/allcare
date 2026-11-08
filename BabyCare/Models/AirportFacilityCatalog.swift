import Foundation

/// 공항 시설 안내 — 수유실·기저귀 교환대 위치. 장소 추천이 아니라 시설 안내다(설계서 §7).
struct AirportFacility: Hashable, Sendable {
    struct Room: Hashable, Sendable {
        let line: String
        let sub: String?
    }

    let airportCode: String
    /// 화면에 쓰는 이름(예: 인천공항).
    let airportName: String
    let terminal: String
    let rooms: [Room]
    let diaper: String
    let caution: String?
    let source: TripRuleSource
}

/// 이 판의 데이터 — 확인한 공항·항공사 조합만. 그 밖은 nil(「이 공항은 아직 정보가 없어요」).
enum AirportFacilityCatalog {
    private static let incheonT2 = AirportFacility(
        airportCode: "ICN", airportName: "인천공항", terminal: "제2여객터미널",
        rooms: [
            .init(line: "면세구역 3층, 탑승구 근처", sub: "221·231·243·257·268·278번"),
            .init(line: "출국장 3층 동편·서편", sub: nil),
            .init(line: "입국장 1층 동편·서편", sub: nil)
        ],
        diaper: "수유실마다 기저귀 교환대가 있어요",
        caution: nil,
        source: TripRuleSource(title: "인천국제공항: 임신부·유아·어린이 동반",
                               url: URL(string: "https://www.airport.kr/ap_ko/949/subview.do")!,
                               checkedOn: "2026.11.04", note: nil))

    private static let kansaiT1 = AirportFacility(
        airportCode: "KIX", airportName: "간사이공항", terminal: "제1터미널",
        rooms: [
            .init(line: "입국장 1층", sub: nil),
            .init(line: "출국장 4층", sub: nil),
            .init(line: "면세구역 가운데·북쪽 윙·남쪽 윙", sub: nil)
        ],
        diaper: "화장실마다 기저귀 교환대가 있어요",
        caution: "위치는 2024년 1월 기준이에요. 2025년 3월 리뉴얼 뒤 바뀌었을 수 있어요.",
        source: TripRuleSource(title: "간사이공항 운영사 안내: 수유실 위치",
                               url: URL(string: "https://locally.matcha-jp.com/en/20690")!,
                               checkedOn: "2026.11.04", note: "공항 운영사가 쓴 안내 · 2024년 1월 기준"))

    /// 터미널은 항공사가 정한다 — 대한항공(KE)이 쓰는 터미널만 확인했다.
    static func facility(airport: String, airline: String?) -> AirportFacility? {
        guard airline?.uppercased() == TripRuleCatalog.koreanAir else { return nil }
        switch airport.uppercased() {
        case "ICN": return incheonT2
        case "KIX": return kansaiT1
        default: return nil
        }
    }
}
