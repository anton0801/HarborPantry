//
//  PrepTimelineService.swift
//  HarborPantry
//
//  Domain layer — dependency-aware scheduling suggestions for prep tasks.
//

import Foundation

struct PrepTimelineService {

    /// Tasks for one day, ordered by time and then by kind.
    func tasks(_ tasks: [PrepTask], on day: Date, calendar: Calendar = .current) -> [PrepTask] {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return tasks
            .filter { $0.scheduledAt >= start && $0.scheduledAt < end }
            .sorted { lhs, rhs in
                if lhs.scheduledAt == rhs.scheduledAt {
                    return lhs.kind.id < rhs.kind.id
                }
                return lhs.scheduledAt < rhs.scheduledAt
            }
    }

    /// Suggests new times for tasks that depend on `changed`.
    ///
    /// The result is only a *proposal* — nothing is written until the user
    /// confirms the shift.
    func dependentShiftProposal(
        after changed: PrepTask,
        in tasks: [PrepTask]
    ) -> [PrepShiftProposal] {
        var proposals: [PrepShiftProposal] = []
        var queue: [PrepTask] = tasks.filter { $0.dependencyId == changed.id }
        var visited: Set<UUID> = [changed.id]
        var resolvedEnds: [UUID: Date] = [changed.id: changed.endsAt]

        while let task = queue.first {
            queue.removeFirst()
            guard !visited.contains(task.id) else { continue }
            visited.insert(task.id)
            guard task.status != .completed else { continue }

            guard let dependencyId = task.dependencyId,
                  let dependencyEnd = resolvedEnds[dependencyId] else { continue }

            if task.scheduledAt < dependencyEnd {
                proposals.append(
                    PrepShiftProposal(
                        taskId: task.id,
                        title: task.title,
                        currentTime: task.scheduledAt,
                        suggestedTime: dependencyEnd
                    )
                )
                resolvedEnds[task.id] = dependencyEnd
                    .addingTimeInterval(TimeInterval(task.durationMinutes * 60))
            } else {
                resolvedEnds[task.id] = task.endsAt
            }

            queue.append(contentsOf: tasks.filter { $0.dependencyId == task.id })
        }

        return proposals
    }

    /// Builds a starter timeline for a planned meal: thaw for frozen items,
    /// then prep, then cook, finishing at the meal time.
    func suggestedTasks(
        for dish: Dish,
        mealTime: Date,
        frozenIngredients: [DishIngredient]
    ) -> [PrepTask] {
        var result: [PrepTask] = []
        let cookStart = mealTime.addingTimeInterval(TimeInterval(-dish.cookMinutes * 60))
        let prepStart = cookStart.addingTimeInterval(TimeInterval(-dish.prepMinutes * 60))

        if !frozenIngredients.isEmpty {
            // A generous default the user can move; the app never claims this
            // is the safe or required thawing time.
            let thawMinutes = 8 * 60
            let thawStart = prepStart.addingTimeInterval(TimeInterval(-thawMinutes))
            let names = frozenIngredients.map(\.trimmedName).joined(separator: ", ")
            result.append(
                PrepTask(
                    title: "Thaw \(names)",
                    kind: .thaw,
                    scheduledAt: thawStart,
                    durationMinutes: thawMinutes,
                    linkedDishId: dish.id,
                    note: "Suggested time — adjust it to suit your own routine."
                )
            )
        }

        if dish.prepMinutes > 0 {
            result.append(
                PrepTask(
                    title: "Prep \(dish.trimmedName)",
                    kind: .prep,
                    scheduledAt: prepStart,
                    durationMinutes: dish.prepMinutes,
                    dependencyId: result.last?.id,
                    linkedDishId: dish.id
                )
            )
        }

        if dish.cookMinutes > 0 {
            result.append(
                PrepTask(
                    title: "Cook \(dish.trimmedName)",
                    kind: .cook,
                    scheduledAt: cookStart,
                    durationMinutes: dish.cookMinutes,
                    dependencyId: result.last?.id,
                    linkedDishId: dish.id
                )
            )
        }

        if result.isEmpty {
            result.append(
                PrepTask(
                    title: "Prepare \(dish.trimmedName)",
                    kind: .prep,
                    scheduledAt: mealTime.addingTimeInterval(-30 * 60),
                    durationMinutes: 30,
                    linkedDishId: dish.id
                )
            )
        }

        return result
    }
}

struct PrepShiftProposal: Hashable, Identifiable {
    let taskId: UUID
    let title: String
    let currentTime: Date
    let suggestedTime: Date

    var id: UUID { taskId }
}
