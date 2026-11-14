import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation
import XCTest
@testable import BabyCare

/// 아이폰 SDK ↔ 로컬 Firebase 에뮬레이터(Firestore + Auth).
///
/// 실제 Swift 코드(FirestoreService·VM)를 레포 `firestore.rules` 그대로 태운다. 웹 SDK 규칙 시험(firestore-tests)이
/// 못 보는 Swift 쪽 실수 — 서버를 안 기다리는 `await`, Codable 칸 이름·날짜 모양, 지우기 목록 빠짐 — 를 잡는다.
///
/// - 실행: `make emulator-test` (firestore-tests/firebase.ios.json 으로 에뮬레이터를 띄우고 Emulator* 시험만 돌린다)
/// - 에뮬레이터가 없으면(CI · 평소 `make test`) 시험은 건너뛴다 — 운영 서버에는 어떤 경우에도 닿지 않는다
///   (사람마다 이름 붙은 FirebaseApp 을 따로 만들고 전부 에뮬레이터를 가리킨다 · 실제 앱의 기본 앱과 섞이지 않는다).
@MainActor
enum FirebaseEmulator {
    static let projectID = "demo-babycare"
    static let host = "127.0.0.1"
    static let firestorePort = 8180
    static let authPort = 9199

    /// 사람 한 명 = 로그인이 따로인 FirebaseApp 하나.
    struct Person {
        let app: FirebaseApp
        let service: FirestoreService
        var auth: Auth { Auth.auth(app: app) }
        var firestore: Firestore { service.db }
        var uid: String { auth.currentUser?.uid ?? "" }
    }

    private static var people: [String: Person] = [:]

    // MARK: - 준비

    /// 에뮬레이터가 떠 있지 않으면 시험을 건너뛴다.
    static func requireRunning() async throws {
        let firestoreUp = await isReachable(port: firestorePort)
        let authUp = await isReachable(port: authPort)
        guard firestoreUp, authUp else {
            throw XCTSkip("Firebase 에뮬레이터가 없다(Firestore \(firestorePort) · Auth \(authPort)) — `make emulator-test` 로 돌린다")
        }
    }

    /// 시험 사이: 모든 문서·계정을 지우고 모두 로그아웃.
    static func reset() async throws {
        for person in people.values { try? person.auth.signOut() }
        _ = try await send("DELETE", port: firestorePort,
                           path: "/emulator/v1/projects/\(projectID)/databases/(default)/documents")
        _ = try await send("DELETE", port: authPort, path: "/emulator/v1/projects/\(projectID)/accounts")
    }

    /// 새 계정을 만들어 그 사람으로 로그인한다.
    static func signUp(_ name: String) async throws -> Person {
        let person = person(name)
        try? person.auth.signOut()
        let email = "\(name)-\(UUID().uuidString.prefix(8).lowercased())@example.com"
        _ = try await person.auth.createUser(withEmail: email, password: "pw-123456")
        return person
    }

    static func person(_ name: String) -> Person {
        if let known = people[name] { return known }
        let appName = "emulator-\(name)"
        if FirebaseApp.app(name: appName) == nil {
            let options = FirebaseOptions(googleAppID: "1:123456789012:ios:0123456789abcdef", gcmSenderID: "123456789012")
            options.projectID = projectID
            options.apiKey = "AIzaSyEmulatorTestsOnlyNotARealKey00000" // 39자 · 모양만 맞춘 가짜(에뮬레이터는 안 본다)
            options.bundleID = Bundle.main.bundleIdentifier ?? "com.roacompany.allcare"
            FirebaseApp.configure(name: appName, options: options)
        }
        guard let app = FirebaseApp.app(name: appName) else { fatalError("에뮬레이터 앱을 못 만들었다: \(appName)") }
        Auth.auth(app: app).useEmulator(withHost: host, port: authPort)
        let db = Firestore.firestore(app: app)
        db.useEmulator(withHost: host, port: firestorePort)
        let settings = db.settings
        settings.cacheSettings = MemoryCacheSettings() // 시험 사이에 기기 캐시가 남지 않게
        db.settings = settings
        let person = Person(app: app, service: FirestoreService(db: db))
        people[name] = person
        return person
    }

    // MARK: - 규칙 밖(관리자)에서 심고·읽기 — 시험 준비와 「정말 남았나」 확인용

    /// 문서를 통째로 쓴다(규칙 무시).
    static func adminSet(_ docPath: String, _ fields: [String: Any]) async throws {
        let body = ["fields": fields.mapValues(restValue)]
        _ = try await send("PATCH", port: firestorePort, path: documentsPath(docPath), json: body)
    }

    /// 문서 칸을 읽는다(규칙 무시). 없으면 nil.
    static func adminGet(_ docPath: String) async throws -> [String: Any]? {
        guard let json = try await send("GET", port: firestorePort, path: documentsPath(docPath), allowNotFound: true),
              let fields = json["fields"] as? [String: Any] else { return nil }
        return fields.mapValues(plainValue)
    }

    /// 그 문서 아래(하위 컬렉션 전부 · 깊이 끝까지)에 남아 있는 문서 경로. 문서 자신도 있으면 포함.
    static func adminDocumentPaths(under docPath: String) async throws -> [String] {
        var found: [String] = []
        if try await adminGet(docPath) != nil { found.append(docPath) }
        let ids = try await send("POST", port: firestorePort, path: documentsPath(docPath) + ":listCollectionIds",
                                 json: ["pageSize": 300])?["collectionIds"] as? [String] ?? []
        for collection in ids {
            var pageToken: String?
            repeat {
                var query = "?pageSize=300&showMissing=true"
                if let pageToken,
                   let encoded = pageToken.addingPercentEncoding(withAllowedCharacters: .alphanumerics) {
                    query += "&pageToken=\(encoded)"
                }
                let listed = try await send("GET", port: firestorePort,
                                            path: documentsPath("\(docPath)/\(collection)") + query)
                for doc in listed?["documents"] as? [[String: Any]] ?? [] {
                    guard let name = doc["name"] as? String,
                          let range = name.range(of: "/documents/") else { continue }
                    let childPath = String(name[range.upperBound...])
                    found += try await adminDocumentPaths(under: childPath)
                }
                pageToken = listed?["nextPageToken"] as? String
            } while pageToken?.isEmpty == false
        }
        return found
    }

    /// Auth 에뮬레이터에 그 계정이 아직 있나.
    static func authUserExists(uid: String) async throws -> Bool {
        let json = try await send("POST", port: authPort,
                                  path: "/identitytoolkit.googleapis.com/v1/projects/\(projectID)/accounts:lookup",
                                  json: ["localId": [uid]])
        return !((json?["users"] as? [[String: Any]]) ?? []).isEmpty
    }

    // MARK: - 내부

    private static func documentsPath(_ docPath: String) -> String {
        "/v1/projects/\(projectID)/databases/(default)/documents/\(docPath)"
    }

    private static func isReachable(port: Int) async -> Bool {
        guard let url = URL(string: "http://\(host):\(port)/") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 0.5
        do {
            _ = try await URLSession.shared.data(for: request)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    private static func send(_ method: String, port: Int, path: String, json: [String: Any]? = nil,
                             allowNotFound: Bool = false) async throws -> [String: Any]? {
        guard let url = URL(string: "http://\(host):\(port)\(path)") else {
            throw EmulatorError.badPath(path)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer owner", forHTTPHeaderField: "Authorization") // 에뮬레이터 관리자 = 규칙 무시
        if let json {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: json)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 404, allowNotFound { return nil }
        guard (200..<300).contains(status) else {
            throw EmulatorError.http(status, method, path, String(data: data, encoding: .utf8) ?? "")
        }
        guard !data.isEmpty else { return [:] }
        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    /// Swift 값 → Firestore REST 값.
    private static func restValue(_ value: Any) -> [String: Any] {
        switch value {
        case let text as String: return ["stringValue": text]
        case let flag as Bool: return ["booleanValue": flag]
        case let number as Int: return ["integerValue": String(number)]
        case let number as Double: return ["doubleValue": number]
        case let date as Date: return ["timestampValue": ISO8601DateFormatter().string(from: date)]
        case let map as [String: Any]: return ["mapValue": ["fields": map.mapValues(restValue)]]
        case let list as [Any]: return ["arrayValue": ["values": list.map(restValue)]]
        default: return ["nullValue": NSNull()]
        }
    }

    /// Firestore REST 값 → 비교하기 쉬운 Swift 값(시각은 ISO 글자 그대로).
    private static func plainValue(_ value: Any) -> Any {
        guard let wrapped = value as? [String: Any], let entry = wrapped.first else { return value }
        let inner = entry.value
        switch entry.key {
        case "integerValue": return Int(inner as? String ?? "") ?? inner
        case "mapValue": return ((inner as? [String: Any])?["fields"] as? [String: Any] ?? [:]).mapValues(plainValue)
        case "arrayValue": return ((inner as? [String: Any])?["values"] as? [Any] ?? []).map(plainValue)
        default: return inner
        }
    }

    enum EmulatorError: Error {
        case badPath(String)
        case http(Int, String, String, String)
    }
}
