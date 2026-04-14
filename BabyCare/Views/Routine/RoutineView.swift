import SwiftUI

struct RoutineView: View {
    @Environment(RoutineViewModel.self) private var routineVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(BabyViewModel.self) private var babyVM

    var body: some View {
        List {
            if routineVM.routines.isEmpty && !routineVM.isLoading {
                ContentUnavailableView(
                    "루틴이 없습니다",
                    systemImage: "list.clipboard",
                    description: Text("아침/저녁 루틴을 만들어보세요")
                )
            }

            ForEach(routineVM.routines) { routine in
                RoutineSection(routine: routine)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("루틴")
        .toolbar {
            Button {
                routineVM.resetForm()
                routineVM.showAddRoutine = true
            } label: {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: Bindable(routineVM).showAddRoutine) {
            RoutineFormSheet()
        }
        .task {
            guard let userId = authVM.currentUserId else { return }
            await routineVM.loadRoutines(userId: userId)
            await routineVM.checkAndAutoResetIfNeeded(userId: userId)
        }
    }
}

// MARK: - Routine Section

private struct RoutineSection: View {
    @Environment(RoutineViewModel.self) private var routineVM
    @Environment(AuthViewModel.self) private var authVM
    let routine: Routine

    @State private var showEditSheet = false

    private var completedCount: Int {
        routine.items.filter(\.isCompleted).count
    }

    var body: some View {
        Section {
            ForEach(routine.items.sorted(by: { $0.order < $1.order })) { item in
                Button {
                    Task {
                        guard let userId = authVM.currentUserId else { return }
                        await routineVM.toggleItem(routine, itemId: item.id, userId: userId)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(item.isCompleted ? .green : .secondary)

                        Text(item.title)
                            .strikethrough(item.isCompleted)
                            .foregroundStyle(item.isCompleted ? .secondary : .primary)

                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        } header: {
            HStack {
                Text(routine.name)
                    .onTapGesture {
                        routineVM.startEditing(routine)
                        showEditSheet = true
                    }
                Spacer()
                if let streak = routine.currentStreak, streak >= 2 {
                    Text("🔥 \(streak)일 연속")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Text("\(completedCount)/\(routine.items.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } footer: {
            HStack(spacing: 16) {
                if completedCount == routine.items.count && !routine.items.isEmpty {
                    Button("초기화") {
                        Task {
                            guard let userId = authVM.currentUserId else { return }
                            await routineVM.resetRoutine(routine, userId: userId)
                        }
                    }
                    .font(.caption)
                }

                Spacer()

                Button(role: .destructive) {
                    Task {
                        guard let userId = authVM.currentUserId else { return }
                        await routineVM.deleteRoutine(routine, userId: userId)
                    }
                } label: {
                    Text("삭제")
                        .font(.caption)
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            RoutineFormSheet()
        }
    }
}

// MARK: - Routine Form Sheet (추가 + 수정 통합)

private struct RoutineFormSheet: View {
    @Environment(RoutineViewModel.self) private var routineVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(\.dismiss) private var dismiss

    private var isEditing: Bool { routineVM.editingRoutine != nil }

    var body: some View {
        @Bindable var vm = routineVM

        NavigationStack {
            Form {
                Section("루틴 이름") {
                    TextField("예: 아침 루틴", text: $vm.routineName)
                }

                Section("항목") {
                    ForEach(vm.routineItems.indices, id: \.self) { index in
                        HStack {
                            TextField("항목 \(index + 1)", text: $vm.routineItems[index])
                            if vm.routineItems.count > 1 {
                                Button {
                                    vm.routineItems.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Button {
                        vm.routineItems.append("")
                    } label: {
                        Label("항목 추가", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle(isEditing ? "루틴 수정" : "루틴 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        routineVM.resetForm()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        Task {
                            guard let userId = authVM.currentUserId else { return }
                            if isEditing {
                                await routineVM.updateRoutine(userId: userId)
                            } else {
                                await routineVM.addRoutine(userId: userId, babyId: babyVM.selectedBaby?.id)
                            }
                            if routineVM.errorMessage == nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!routineVM.isFormValid || routineVM.isLoading)
                }
            }
        }
    }
}
