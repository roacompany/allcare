import FirebaseFirestore
import Foundation

extension FirestoreService {
        // MARK: - Todo

    func saveTodo(_ todo: TodoItem, userId: String) async throws {
        let ref = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.todos)
            .document(todo.id)
        try ref.setData(from: todo)
    }

    func fetchTodos(userId: String) async throws -> [TodoItem] {
        let snapshot = try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.todos)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return decodeDocuments(snapshot.documents, as: TodoItem.self)
    }

    func deleteTodo(_ todoId: String, userId: String) async throws {
        try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.todos)
            .document(todoId)
            .delete()
    }
}
