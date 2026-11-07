import SwiftUI

struct AdminPushView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var pushVM = AdminPushViewModel()
    @State private var title = ""
    @State private var body_ = ""
    @State private var topic = "all_users"
    @State private var showConfirm = false

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
                    showConfirm = true
                } label: {
                    HStack {
                        Spacer()
                        if pushVM.isSending {
                            ProgressView()
                        } else {
                            Label("푸시 발송", systemImage: "paperplane.fill")
                        }
                        Spacer()
                    }
                }
                .disabled(title.isEmpty || body_.isEmpty || pushVM.isSending)
            } footer: {
                Text("전체 사용자에게 바로 발송됩니다. 보낸 기록은 웹 관리자 「푸시 이력」에 남습니다.")
                    .font(.caption2)
            }
        }
        .navigationTitle("푸시 발송")
        // 전체 사용자에게 바로 가므로 한 번 묻는다
        .confirmationDialog("모든 사용자에게 보낼까요?", isPresented: $showConfirm, titleVisibility: .visible) {
            Button("보내기") {
                Task {
                    await pushVM.send(title: title, body: body_, topic: topic, idToken: { try await authVM.idToken() })
                }
            }
            Button("취소", role: .cancel) {}
        }
        .alert("발송 결과", isPresented: Binding(
            get: { pushVM.resultMessage != nil },
            set: { if !$0 { pushVM.resultMessage = nil } }
        )) {
            Button("확인") {}
        } message: {
            Text(pushVM.resultMessage ?? "")
        }
    }
}
