import XCTest
@testable import BabyCare

final class CaregiverAttributionTests: XCTestCase {
    func test_relationship_rawValues_areStableContract() {
        XCTAssertEqual(CaregiverRelationship.mother.rawValue, "mother")
        XCTAssertEqual(CaregiverRelationship.father.rawValue, "father")
        XCTAssertEqual(CaregiverRelationship.grandmother.rawValue, "grandmother")
        XCTAssertEqual(CaregiverRelationship.grandfather.rawValue, "grandfather")
        XCTAssertEqual(CaregiverRelationship.other.rawValue, "other")
    }

    func test_relationship_displayName_korean() {
        XCTAssertEqual(CaregiverRelationship.mother.displayName, "엄마")
        XCTAssertEqual(CaregiverRelationship.father.displayName, "아빠")
    }

    func test_relationship_unknownDecode_fallback() {
        // 미래 버전이 추가한 rawValue → unknown 으로 관용 디코드
        XCTAssertEqual(CaregiverRelationship.known(rawValue: "aunt"), CaregiverRelationship.unknown)
        XCTAssertEqual(CaregiverRelationship.known(rawValue: "mother"), CaregiverRelationship.mother)
    }

    func test_selectableCases_excludeUnknown() {
        XCTAssertFalse(CaregiverRelationship.selectable.contains(.unknown))
        XCTAssertEqual(CaregiverRelationship.selectable.count, 5)
    }
}

extension CaregiverAttributionTests {
    func test_activity_createdBy_codableRoundTrip() throws {
        var a = Activity(babyId: "b1", type: .feedingBottle)
        a.createdBy = "uid_dad"
        let data = try JSONEncoder().encode(a)
        let decoded = try JSONDecoder().decode(Activity.self, from: data)
        XCTAssertEqual(decoded.createdBy, "uid_dad")
    }

    func test_activity_createdBy_defaultsNil_backwardCompat() throws {
        // createdBy 없는 과거 문서도 디코드되어야 (optional)
        let json = #"{"id":"x","babyId":"b1","type":"sleep","startTime":0,"createdAt":0}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Activity.self, from: json)
        XCTAssertNil(decoded.createdBy)
    }

    func test_sharedAccess_relationship_roundTrip() throws {
        var s = SharedBabyAccess(ownerUserId: "o", babyId: "b", babyName: "아기")
        s.relationship = CaregiverRelationship.father.rawValue
        let decoded = try JSONDecoder().decode(SharedBabyAccess.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(decoded.relationship, "father")
    }

    func test_baby_ownerRelationship_roundTrip() throws {
        var b = Baby(id: "b", name: "아기", birthDate: Date(timeIntervalSince1970: 0), gender: .male, createdAt: Date(timeIntervalSince1970: 0), updatedAt: Date(timeIntervalSince1970: 0))
        b.ownerRelationship = CaregiverRelationship.mother.rawValue
        let decoded = try JSONDecoder().decode(Baby.self, from: JSONEncoder().encode(b))
        XCTAssertEqual(decoded.ownerRelationship, "mother")
    }
}
