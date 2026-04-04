import Foundation

@MainActor @Observable
final class TodoViewModel {
    var todos: [TodoItem] = []
    var completedTodosCache: [TodoItem] = []
    var isLoading = false
    var isLoadingCompleted = false
    var showCompleted = false
    var errorMessage: String?
    var showAddTodo = false
    var editingTodo: TodoItem?

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
        showCompleted ? completedTodosCache : []
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

    // MARK: - Edit

    func startEditing(_ todo: TodoItem) {
        editingTodo = todo
        title = todo.title
        description = todo.description ?? ""
        dueDate = todo.dueDate
        hasDueDate = todo.dueDate != nil
        category = todo.category
        isRecurring = todo.isRecurring
        recurringInterval = todo.recurringInterval ?? .daily
        selectedBabyId = todo.babyId
        showAddTodo = true
    }

    func updateTodo(_ todo: TodoItem, userId: String) async {
        guard isFormValid else {
            errorMessage = "제목을 입력해주세요."
            return
        }

        var updated = todo
        updated.title = title.trimmingCharacters(in: .whitespaces)
        updated.description = description.isEmpty ? nil : description
        updated.dueDate = hasDueDate ? dueDate : nil
        updated.category = category
        updated.isRecurring = isRecurring
        updated.recurringInterval = isRecurring ? recurringInterval : nil

        let backup = todos
        let backupCompleted = completedTodosCache
        if updated.isCompleted {
            if let idx = completedTodosCache.firstIndex(where: { $0.id == updated.id }) {
                completedTodosCache[idx] = updated
            }
        } else {
            if let idx = todos.firstIndex(where: { $0.id == updated.id }) {
                todos[idx] = updated
            }
        }

        do {
            try await firestoreService.saveTodo(updated, userId: userId)
            resetForm()
            showAddTodo = false
        } catch {
            todos = backup
            completedTodosCache = backupCompleted
            errorMessage = "수정에 실패했습니다."
        }
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

    func toggleShowCompleted(userId: String) async {
        showCompleted.toggle()
        guard showCompleted, completedTodosCache.isEmpty else { return }
        isLoadingCompleted = true
        defer { isLoadingCompleted = false }
        do {
            completedTodosCache = try await firestoreService.fetchCompletedTodos(userId: userId)
        } catch {
            errorMessage = "완료된 할 일을 불러오지 못했습니다: \(error.localizedDescription)"
            showCompleted = false
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
        var updated = todo
        updated.isCompleted.toggle()
        updated.completedAt = updated.isCompleted ? Date() : nil

        // Optimistic update: move item between active and completed collections
        if updated.isCompleted {
            todos.removeAll { $0.id == todo.id }
            completedTodosCache.insert(updated, at: 0)
        } else {
            completedTodosCache.removeAll { $0.id == todo.id }
            todos.insert(updated, at: 0)
        }

        do {
            try await firestoreService.saveTodo(updated, userId: userId)
        } catch {
            // Rollback
            if updated.isCompleted {
                completedTodosCache.removeAll { $0.id == updated.id }
                todos.insert(todo, at: 0)
            } else {
                todos.removeAll { $0.id == updated.id }
                completedTodosCache.insert(todo, at: 0)
            }
            errorMessage = "업데이트에 실패했습니다."
        }
    }

    func deleteTodo(_ todo: TodoItem, userId: String) async {
        let backupTodos = todos
        let backupCompleted = completedTodosCache
        todos.removeAll { $0.id == todo.id }
        completedTodosCache.removeAll { $0.id == todo.id }

        do {
            try await firestoreService.deleteTodo(todo.id, userId: userId)
            NotificationService.shared.cancelNotification(identifier: "todo-\(todo.id)")
        } catch {
            todos = backupTodos
            completedTodosCache = backupCompleted
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
        editingTodo = nil
    }
}
