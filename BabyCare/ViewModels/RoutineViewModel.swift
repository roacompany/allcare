import Foundation

@MainActor @Observable
final class RoutineViewModel: LoadingStateful {
    var routines: [Routine] = []
    var isLoading = false
    var errorMessage: String?
    var showAddRoutine = false

    // Form
    var routineName = ""
    var routineItems: [String] = [""]
    var editingRoutine: Routine?

    private let firestoreService = FirestoreService.shared

    var isFormValid: Bool {
        !routineName.trimmingCharacters(in: .whitespaces).isEmpty &&
        routineItems.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
    }

    // MARK: - Load

    func loadRoutines(userId: String) async {
        await withLoading {
            do {
                routines = try await firestoreService.fetchRoutines(userId: userId)
            } catch {
                errorMessage = "루틴을 불러오지 못했습니다."
            }
        }
    }

    // MARK: - Edit Form

    func startEditing(_ routine: Routine) {
        editingRoutine = routine
        routineName = routine.name
        routineItems = routine.items
            .sorted(by: { $0.order < $1.order })
            .map(\.title)
        if routineItems.isEmpty { routineItems = [""] }
    }

    // MARK: - Update

    func updateRoutine(userId: String) async {
        guard let editing = editingRoutine, isFormValid else { return }
        await withLoading {
            let updatedItems = routineItems.enumerated().compactMap { index, title -> Routine.RoutineItem? in
                let trimmed = title.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return nil }
                // 기존 완료 상태 유지: 같은 순서의 기존 항목이 있으면 isCompleted 보존
                let existingItem = editing.items.sorted(by: { $0.order < $1.order })
                    .enumerated()
                    .first(where: { $0.offset == index })?.element
                return Routine.RoutineItem(
                    id: existingItem?.id ?? UUID().uuidString,
                    title: trimmed,
                    order: index,
                    isCompleted: existingItem?.isCompleted ?? false
                )
            }

            var updated = editing
            updated.name = routineName.trimmingCharacters(in: .whitespaces)
            updated.items = updatedItems

            do {
                try await firestoreService.saveRoutine(updated, userId: userId)
                if let rIdx = routines.firstIndex(where: { $0.id == editing.id }) {
                    routines[rIdx] = updated
                }
                resetForm()
            } catch {
                errorMessage = "루틴 수정에 실패했습니다."
            }
        }
    }

    // MARK: - Add

    func addRoutine(userId: String, babyId: String?) async {
        guard isFormValid else { return }
        await withLoading {
            let items = routineItems.enumerated().compactMap { index, title -> Routine.RoutineItem? in
                let trimmed = title.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return nil }
                return Routine.RoutineItem(title: trimmed, order: index)
            }

            let routine = Routine(
                name: routineName.trimmingCharacters(in: .whitespaces),
                items: items,
                babyId: babyId
            )

            do {
                try await firestoreService.saveRoutine(routine, userId: userId)
                routines.append(routine)
                resetForm()
                showAddRoutine = false
            } catch {
                errorMessage = "루틴 추가에 실패했습니다."
            }
        }
    }

    // MARK: - Toggle Item

    func toggleItem(_ routine: Routine, itemId: String, userId: String) async {
        guard let rIdx = routines.firstIndex(where: { $0.id == routine.id }),
              let iIdx = routines[rIdx].items.firstIndex(where: { $0.id == itemId }) else { return }

        let backup = routines[rIdx]
        routines[rIdx].items[iIdx].isCompleted.toggle()

        do {
            try await firestoreService.saveRoutine(routines[rIdx], userId: userId)
        } catch {
            routines[rIdx] = backup
            errorMessage = "루틴 업데이트에 실패했습니다."
        }
    }

    // MARK: - Auto Reset (날짜 변경 시 자동 리셋 + 스트릭 갱신)

    func checkAndAutoResetIfNeeded(userId: String) async {
        let today = Calendar.current.startOfDay(for: Date())

        // 값 스냅샷을 순회하고 갱신/롤백은 id 로 위치를 찾는다 — await 도중 routines 배열이
        // 변동(추가/삭제/재정렬)돼도 stale 인덱스로 엉뚱한 항목을 덮어쓰거나 out-of-range 크래시 나지 않게 (#9).
        for original in routines {
            let last = original.lastResetDate.map { Calendar.current.startOfDay(for: $0) }

            // 이미 오늘 리셋된 경우 skip
            if last == today { continue }

            let wasFullyCompleted = !original.items.isEmpty && original.items.allSatisfy { $0.isCompleted }
            let gapDays = last.map { Calendar.current.dateComponents([.day], from: $0, to: today).day ?? 0 } ?? 0

            let newStreak: Int
            if wasFullyCompleted && gapDays == 1 {
                newStreak = (original.currentStreak ?? 0) + 1
            } else {
                newStreak = 0
            }

            var updated = original
            for i in updated.items.indices {
                updated.items[i].isCompleted = false
            }
            updated.lastResetDate = today
            updated.currentStreak = newStreak

            // 낙관적 반영도 id 로 (스냅샷 이후 배열이 바뀌었을 수 있음)
            guard let applyIdx = routines.firstIndex(where: { $0.id == updated.id }) else { continue }
            routines[applyIdx] = updated

            do {
                try await firestoreService.saveRoutine(updated, userId: userId)
                if newStreak >= 3 {
                    let event = BadgeEvaluator.Event(
                        kind: .routineStreakUpdated(newStreak: newStreak),
                        babyId: nil,
                        at: today
                    )
                    let earned = await BadgeEvaluator().evaluate(event: event, userId: userId)
                    AppState.shared.badgePresenter.enqueue(earned)
                }
            } catch {
                // 롤백도 id 로 — await 동안 배열이 변동/삭제됐을 수 있음
                if let rollbackIdx = routines.firstIndex(where: { $0.id == original.id }) {
                    routines[rollbackIdx] = original
                }
            }
        }
    }

    // MARK: - Reset All Items (for new day)

    func resetRoutine(_ routine: Routine, userId: String) async {
        guard let rIdx = routines.firstIndex(where: { $0.id == routine.id }) else { return }
        let backup = routines[rIdx]
        for i in routines[rIdx].items.indices {
            routines[rIdx].items[i].isCompleted = false
        }
        do {
            try await firestoreService.saveRoutine(routines[rIdx], userId: userId)
        } catch {
            routines[rIdx] = backup
        }
    }

    // MARK: - Delete

    func deleteRoutine(_ routine: Routine, userId: String) async {
        let backup = routines
        routines.removeAll { $0.id == routine.id }
        do {
            try await firestoreService.deleteRoutine(routine.id, userId: userId)
        } catch {
            routines = backup
            errorMessage = "루틴 삭제에 실패했습니다."
        }
    }

    // MARK: - Form

    func resetForm() {
        routineName = ""
        routineItems = [""]
        errorMessage = nil
        editingRoutine = nil
    }
}
