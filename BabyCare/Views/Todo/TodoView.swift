import SwiftUI

struct TodoView: View {
    @Environment(TodoViewModel.self) private var todoVM
    @Environment(AuthViewModel.self) private var authVM

    var body: some View {
        NavigationStack {
            List {
                if !todoVM.overdueTodos.isEmpty {
                    Section("지연됨") {
                        ForEach(todoVM.overdueTodos) { todo in
                            TodoRowView(todo: todo)
                        }
                    }
                }

                Section("할 일 (\(todoVM.pendingTodos.count))") {
                    ForEach(todoVM.pendingTodos) { todo in
                        TodoRowView(todo: todo)
                    }
                    .onDelete { indexSet in
                        Task {
                            guard let userId = authVM.currentUserId else { return }
                            for index in indexSet {
                                let todo = todoVM.pendingTodos[index]
                                await todoVM.deleteTodo(todo, userId: userId)
                            }
                        }
                    }
                }

                if !todoVM.completedTodos.isEmpty {
                    Section("완료 (\(todoVM.completedTodos.count))") {
                        ForEach(todoVM.completedTodos) { todo in
                            TodoRowView(todo: todo)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("할 일")
            .toolbar {
                Button {
                    todoVM.showAddTodo = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: Bindable(todoVM).showAddTodo) {
                AddTodoView()
            }
            .overlay {
                if todoVM.todos.isEmpty && !todoVM.isLoading {
                    EmptyStateView(
                        icon: "checklist",
                        title: "할 일 없음",
                        message: "할 일을 추가해보세요",
                        actionTitle: "추가하기"
                    ) {
                        todoVM.showAddTodo = true
                    }
                }
            }
            .task {
                guard let userId = authVM.currentUserId else { return }
                await todoVM.loadTodos(userId: userId)
            }
        }
    }
}

// MARK: - Todo Row

struct TodoRowView: View {
    let todo: TodoItem
    @Environment(TodoViewModel.self) private var todoVM
    @Environment(AuthViewModel.self) private var authVM

    var body: some View {
        HStack(spacing: 12) {
            Button {
                Task {
                    guard let userId = authVM.currentUserId else { return }
                    await todoVM.toggleComplete(todo, userId: userId)
                }
            } label: {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(todo.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(todo.title)
                    .font(.body)
                    .strikethrough(todo.isCompleted)
                    .foregroundStyle(todo.isCompleted ? .secondary : .primary)

                HStack(spacing: 6) {
                    Image(systemName: todo.category.icon)
                        .font(.caption2)
                    Text(todo.category.displayName)
                        .font(.caption)

                    if let due = todo.dueDate {
                        Text(DateFormatters.shortDate.string(from: due))
                            .font(.caption)
                            .foregroundStyle(due < Date() && !todo.isCompleted ? .red : .secondary)
                    }

                    if todo.isRecurring {
                        Image(systemName: "repeat")
                            .font(.caption2)
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Add Todo View

struct AddTodoView: View {
    @Environment(TodoViewModel.self) private var todoVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var vm = todoVM

        NavigationStack {
            Form {
                Section("기본 정보") {
                    TextField("제목", text: $vm.title)
                    TextField("설명 (선택)", text: $vm.description)
                }

                Section("카테고리") {
                    Picker("카테고리", selection: $vm.category) {
                        ForEach(TodoItem.TodoCategory.allCases, id: \.self) { cat in
                            Label(cat.displayName, systemImage: cat.icon).tag(cat)
                        }
                    }
                }

                Section("마감일") {
                    Toggle("마감일 설정", isOn: $vm.hasDueDate)

                    if todoVM.hasDueDate {
                        DatePicker("마감일", selection: Binding(
                            get: { todoVM.dueDate ?? Date() },
                            set: { todoVM.dueDate = $0 }
                        ))
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                    }
                }

                Section("반복") {
                    Toggle("반복", isOn: $vm.isRecurring)

                    if todoVM.isRecurring {
                        Picker("반복 주기", selection: $vm.recurringInterval) {
                            ForEach(TodoItem.RecurringInterval.allCases, id: \.self) { interval in
                                Text(interval.displayName).tag(interval)
                            }
                        }
                    }
                }
            }
            .navigationTitle("할 일 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        todoVM.resetForm()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("추가") {
                        Task {
                            guard let userId = authVM.currentUserId else { return }
                            await todoVM.addTodo(userId: userId)
                            dismiss()
                        }
                    }
                    .disabled(todoVM.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
