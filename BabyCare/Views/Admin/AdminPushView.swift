import SwiftUI

struct AdminPushView: View {
    @State private var title = ""
    @State private var body_ = ""
    @State private var topic = "all_users"
    @State private var isSending = false
    @State private var resultMessage: String?
    @State private var showResult = false

    var body: some View {
        Form {
            Section("푸시 내용") {
                TextField("제목", text: $title)
                TextEditor(text: $body_)
                    .frame(minHeight: 80)
            }

            Section("대상") {
                Picker("토픽", selection: $topic) {
                    Text("전체 사용자").tag("all_users")
                }
            }

            Section {
                Button {
                    Task { await sendPush() }
                } label: {
                    HStack {
                        Spacer()
                        if isSending {
                            ProgressView()
                        } else {
                            Label("푸시 발송", systemImage: "paperplane.fill")
                        }
                        Spacer()
                    }
                }
                .disabled(title.isEmpty || body_.isEmpty || isSending)
            } footer: {
                Text("FCM 서비스 계정 키가 앱에 포함되어 있지 않으면 발송이 실패합니다. Firebase Console에서 직접 발송하세요.")
                    .font(.caption2)
            }
        }
        .navigationTitle("푸시 발송")
        .alert("발송 결과", isPresented: $showResult) {
            Button("확인") {}
        } message: {
            Text(resultMessage ?? "")
        }
    }

    private func sendPush() async {
        isSending = true
        do {
            try await sendFCMMessage(title: title, body: body_, topic: topic)
            resultMessage = "푸시 발송 성공"
        } catch {
            resultMessage = "발송 실패: \(error.localizedDescription)"
        }
        isSending = false
        showResult = true
    }

    private func sendFCMMessage(title: String, body: String, topic: String) async throws {
        // FCM HTTP v1 API requires OAuth2 service account token.
        // Without a service account key bundled in the app, this will fail gracefully.
        guard let url = URL(string: "https://fcm.googleapis.com/v1/projects/babycare-allcare/messages:send") else {
            throw PushError.invalidURL
        }

        let message: [String: Any] = [
            "message": [
                "topic": topic,
                "notification": [
                    "title": title,
                    "body": body
                ]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: message)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw PushError.sendFailed
        }
    }

    enum PushError: LocalizedError {
        case invalidURL
        case sendFailed

        var errorDescription: String? {
            switch self {
            case .invalidURL: "잘못된 FCM URL"
            case .sendFailed: "FCM 발송 실패. Firebase Console에서 직접 발송해주세요."
            }
        }
    }
}
