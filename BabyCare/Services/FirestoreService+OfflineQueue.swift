import FirebaseFirestore
import Foundation

/// OfflineQueue 가 의존하는 generic document R/W narrow protocol (ISP).
///
/// PendingOperation 단위로 path-based setData / delete 를 위임. dict 직렬화 책임은
/// FirestoreService 가 보유 — `[String: Any]` 비-Sendable 타입 누수 차단.
protocol OfflineQueueFirestoreProviding: Sendable {
    func executePendingOperation(_ op: PendingOperation) async throws
}

extension FirestoreService: OfflineQueueFirestoreProviding {}

extension FirestoreService {
    // MARK: - Offline Queue Execution

    /// 큐잉된 작업 1건 실행. create/update 는 setData, delete 는 delete.
    /// jsonData 가 nil 이거나 typed 복원 실패 시 silent skip (큐에서 자연 제거).
    func executePendingOperation(_ op: PendingOperation) async throws {
        let ref = db.document(op.collectionPath + "/" + op.documentId)
        switch op.type {
        case .create, .update:
            // 큐잉 payload 를 컬렉션별 typed 모델로 복원 후 setData(from:) — 온라인 save 와 동일 인코더라
            // Date 가 Firestore Timestamp 로 저장된다. (JSON dict 직송 시 Date 가 Double 로 깨져
            // range 쿼리에 안 걸려 기록이 영구 누락되는 #2 버그 방지.)
            guard let document = Self.decodeQueuedDocument(op) else { return }
            try ref.setData(from: document)
        case .delete:
            try await ref.delete()
        }
    }

    /// 큐잉 payload 를 collectionPath 마지막 컬렉션명 기준 typed 모델로 복원.
    /// nil payload/garbage/미지원 컬렉션 → nil (큐에서 자연 드롭). 신규 도메인 적재 시 여기 case 추가 필수.
    static func decodeQueuedDocument(_ op: PendingOperation) -> (any Encodable & Sendable)? {
        guard let data = op.jsonData else { return nil }
        let decoder = JSONDecoder()
        switch op.collectionPath.components(separatedBy: "/").last {
        case FirestoreCollections.activities: return try? decoder.decode(Activity.self, from: data)
        case FirestoreCollections.diary: return try? decoder.decode(DiaryEntry.self, from: data)
        case FirestoreCollections.growth: return try? decoder.decode(GrowthRecord.self, from: data)
        case FirestoreCollections.vaccinations: return try? decoder.decode(Vaccination.self, from: data)
        case FirestoreCollections.milestones: return try? decoder.decode(Milestone.self, from: data)
        case FirestoreCollections.hospitalVisits: return try? decoder.decode(HospitalVisit.self, from: data)
        case FirestoreCollections.allergies: return try? decoder.decode(AllergyRecord.self, from: data)
        default: return nil
        }
    }
}
