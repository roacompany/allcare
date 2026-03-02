import Foundation

@MainActor @Observable
final class TodoViewModel {
    var todos: [TodoItem] = []
    var isLoading = false
    var errorMessage: String?
    var showAddTodo = false

    // Form
    var title = ""
    var description = ""
    var dueDate: Date? = nil
    var hasDueDate = false
    var category: TodoItem.TodoCategory = .other
    var isRecurring = false
    var recurringInterval: TodoItem.RecurringInterval = .daily
    var selectedBabyId: String?

    private let firestoreService = FirestoreService.shared

    // MARK: - Computed (상태 중복 제거)

    var pendingTodos: [TodoItem] {
        todos.filter { !$0.isCompleted }.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    var completedTodos: [TodoItem] {
        todos.filter(\.isCompleted)
    }

    var overdueTodos: [TodoItem] {
        let now = Date()
        return pendingTodos.filter { todo in
            guard let due = todo.dueDate else { return false }
            return due < now
        }
    }

    var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - CRUD

    func loadTodos(userId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            todos = try await firestoreService.fetchTodos(userId: userId)
        } catch {
            errorMessage = "할 일을 불러오지 못했습니다: \(error.localizedDescription)"
        }
    }

    func addTodo(userId: String) async {
        guard isFormValid else {
            errorMessage = "제목을 입력해주세요."
            return
        }

        let todo = TodoItem(
            title: title.trimmingCharacters(in: .whitespaces),
            description: description.isEmpty ? nil : description,
            dueDate: hasDueDate ? dueDate : nil,
            category: category,
            babyId: selectedBabyId,
            isRecurring: isRecurring,
            recurringInterval: isRecurring ? recurringInterval : nil
        )

        do {
            try await firestoreService.saveTodo(todo, userId: userId)
            todos.insert(todo, at: 0)

            if todo.dueDate != nil {
                NotificationService.shared.scheduleTodoReminder(todo: todo)
            }

            resetForm()
            showAddTodo = false
        } catch {
            errorMessage = "할 일 추가에 실패했습니다: \(error.localizedDescription)"
        }
    }

    func toggleComplete(_ todo: TodoItem, userId: String) async {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }

        let backup = todos[index]
        var updated = todo
        updated.isCompleted.toggle()
        updated.completedAt = updated.isCompleted ? Date() : nil
        todos[index] = updated

        do {
            try await firestoreService.saveTodo(updated, userId: userId)
        } catch {
            todos[index] = backup // 롤백
            errorMessage = "업데이트에 실패했습니다."
        }
    }

    func deleteTodo(_ todo: TodoItem, userId: String) async {
        let backup = todos
        todos.removeAll { $0.id == todo.id }

        do {
            try await firestoreService.deleteTodo(todo.id, userId: userId)
            NotificationService.shared.cancelNotification(identifier: "todo-\(todo.id)")
        } catch {
            todos = backup
            errorMessage = "삭제에 실패했습니다."
        }
    }

    func resetForm() {
        title = ""
        description = ""
        dueDate = nil
        hasDueDate = false
        category = .other
        isRecurring = false
        recurringInterval = .daily
        selectedBabyId = nil
        errorMessage = nil
    }
}
