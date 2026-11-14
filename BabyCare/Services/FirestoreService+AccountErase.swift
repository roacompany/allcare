import FirebaseFirestore
import Foundation

extension FirestoreService: AccountDataErasing {
    /// 그 사람의 서버 기록 전부를 지운다 — **로그인한 채로** 불러야 한다(규칙이 본인만 허용).
    ///
    /// 범위(한 곳 · `FirestoreCollections`): 아기 전부 + 그 아래(`babyChildren`) · 임신 전부 + 그 아래(`pregnancyChildren`) ·
    /// 사용자 바로 아래(`userChildren`) · 마지막에 사용자 문서. 몇 번 불러도 같다 — 중간에 실패하면 다시 불러 마저 지운다.
    ///
    /// ⚠️ 앱이 닿지 못하는 것: 문서는 이미 지워졌는데 하위 컬렉션만 남은 고아(예: 2.8.13 까지 아기를 지울 때 남은 trips) —
    /// 앱 SDK 는 없는 부모 문서를 목록에 올리지 못한다. 서버(관리자)에서 지워야 한다.
    func eraseAllUserData(userId: String) async throws {
        let userRef = db.collection(FirestoreCollections.users).document(userId)
        try await eraseParentsAndChildren(userRef.collection(FirestoreCollections.babies),
                                          children: FirestoreCollections.babyChildren)
        try await eraseParentsAndChildren(userRef.collection(FirestoreCollections.pregnancies),
                                          children: FirestoreCollections.pregnancyChildren)
        for child in FirestoreCollections.userChildren {
            try await deleteAllDocuments(in: userRef.collection(child))
        }
        try await userRef.delete()
    }

    /// 부모 문서들(아기·임신)의 하위 컬렉션을 먼저 지우고 부모를 지운다(부모만 지우면 그 아래가 남는다).
    private func eraseParentsAndChildren(_ parents: CollectionReference, children: [String]) async throws {
        let snapshot = try await parents.getDocuments(source: .server)
        for parent in snapshot.documents {
            for child in children {
                try await deleteAllDocuments(in: parent.reference.collection(child))
            }
        }
        try await deleteAllDocuments(in: parents)
    }
}
