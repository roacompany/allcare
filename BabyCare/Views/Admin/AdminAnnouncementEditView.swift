import SwiftUI

struct AdminAnnouncementEditView: View {
    @Environment(AnnouncementViewModel.self) private var announcementVM
    @Environment(\.dismiss) private var dismiss

    let announcement: Announcement?

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var priority: Announcement.Priority = .normal
    @State private var isActive: Bool = true
    @State private var isSaving = false

    private var isNew: Bool { announcement == nil }

    var body: some View {
        Form {
            Section("제목") {
                TextField("공지 제목", text: $title)
            }

            Section("내용") {
                TextEditor(text: $content)
                    .frame(minHeight: 120)
            }

            Section("설정") {
                Picker("우선순위", selection: $priority) {
                    Text("낮음").tag(Announcement.Priority.low)
                    Text("보통").tag(Announcement.Priority.normal)
                    Text("높음").tag(Announcement.Priority.high)
                    Text("긴급").tag(Announcement.Priority.urgent)
                }

                Toggle("활성화", isOn: $isActive)
            }
        }
        .navigationTitle(isNew ? "새 공지" : "공지 수정")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isNew {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("저장") {
                    Task { await save() }
                }
                .disabled(title.isEmpty || content.isEmpty || isSaving)
            }
        }
        .onAppear {
            if let announcement {
                title = announcement.title
                content = announcement.content
                priority = announcement.priority
                isActive = announcement.isActive
            }
        }
    }

    private func save() async {
        isSaving = true
        if var existing = announcement {
            existing.title = title
            existing.content = content
            existing.priority = priority
            existing.isActive = isActive
            await announcementVM.updateAnnouncement(existing)
        } else {
            await announcementVM.createAnnouncement(title: title, content: content, priority: priority)
        }
        isSaving = false
        dismiss()
    }
}
