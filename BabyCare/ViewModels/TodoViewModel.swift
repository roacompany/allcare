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

    func loadTodos(userId: String) async {
        isLoading = true
        do {
            todos = try await firestoreService.fetchTodos(userId: userId)
        } catch {
            errorMessage = "할 일을 불러오지 못했습니다."
        }
        isLoading = false
    }

    func addTodo(userId: String) async {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else {
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

            if let dueDate = todo.dueDate {
                NotificationService.shared.scheduleTodoReminder(todo: todo)
            }

            resetForm()
            showAddTodo = false
        } catch {
            errorMessage = "할 일 추가에 실패했습니다."
        }
    }

    func toggleComplete(_ todo: TodoItem, userId: String) async {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        var updated = todo
        updated.isCompleted.toggle()
        updated.completedAt = updated.isCompleted ? Date() : nil

        do {
            try await firestoreService.saveTodo(updated, userId: userId)
            todos[index] = updated
        } catch {
            errorMessage = "업데이트에 실패했습니다."
        }
    }

    func deleteTodo(_ todo: TodoItem, userId: String) async {
        do {
            try await firestoreService.deleteTodo(todo.id, userId: userId)
            todos.removeAll { $0.id == todo.id }
            NotificationService.shared.cancelNotification(identifier: "todo-\(todo.id)")
        } catch {
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
