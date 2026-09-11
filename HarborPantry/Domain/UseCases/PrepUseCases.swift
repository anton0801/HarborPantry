//
//  PrepUseCases.swift
//  HarborPantry
//
//  Domain layer — running the prep timeline and recording leftovers.
//

import Foundation

@MainActor
struct PrepUseCases {
    private let prep: PrepRepository
    private let leftovers: LeftoverRepository
    private let dishes: DishRepository
    private let products: ProductRepository
    private let zones: StorageZoneRepository
    private let history: HistoryRepository
    private let timeline = PrepTimelineService()

    init(
        prep: PrepRepository,
        leftovers: LeftoverRepository,
        dishes: DishRepository,
        products: ProductRepository,
        zones: StorageZoneRepository,
        history: HistoryRepository
    ) {
        self.prep = prep
        self.leftovers = leftovers
        self.dishes = dishes
        self.products = products
        self.zones = zones
        self.history = history
    }

    // MARK: - Reads

    func tasks(on day: Date) -> [PrepTask] {
        timeline.tasks(prep.tasks(), on: day)
    }

    func dependencyCandidates(for taskId: UUID?, on day: Date) -> [PrepTask] {
        tasks(on: day).filter { $0.id != taskId }
    }

    // MARK: - Task lifecycle

    func start(taskId: UUID) async throws {
        guard var task = prep.task(id: taskId) else {
            throw DomainError.notFound("That task no longer exists.")
        }
        if let dependencyId = task.dependencyId,
           let dependency = prep.task(id: dependencyId),
           dependency.status != .completed {
            throw DomainError.conflict("“\(dependency.title)” has to finish first.")
        }
        task.status = .inProgress
        task.startedAt = Date()
        try await prep.update(task)
    }

    /// Completes a task and returns the shift the dependents *would* need.
    /// Nothing downstream moves until `applyShifts` is called.
    @discardableResult
    func complete(taskId: UUID) async throws -> [PrepShiftProposal] {
        guard var task = prep.task(id: taskId) else {
            throw DomainError.notFound("That task no longer exists.")
        }
        task.status = .completed
        task.completedAt = Date()
        try await prep.update(task)
        return timeline.dependentShiftProposal(after: task, in: prep.tasks())
    }

    @discardableResult
    func delay(taskId: UUID, minutes: Int) async throws -> [PrepShiftProposal] {
        guard var task = prep.task(id: taskId) else {
            throw DomainError.notFound("That task no longer exists.")
        }
        guard minutes > 0 else {
            throw DomainError.validation("Choose how long to delay by.")
        }
        task.scheduledAt = task.scheduledAt.addingTimeInterval(TimeInterval(minutes * 60))
        task.status = .delayed
        try await prep.update(task)
        return timeline.dependentShiftProposal(after: task, in: prep.tasks())
    }

    @discardableResult
    func reschedule(taskId: UUID, to date: Date) async throws -> [PrepShiftProposal] {
        guard var task = prep.task(id: taskId) else {
            throw DomainError.notFound("That task no longer exists.")
        }
        task.scheduledAt = date
        if task.status == .delayed { task.status = .pending }
        try await prep.update(task)
        return timeline.dependentShiftProposal(after: task, in: prep.tasks())
    }

    /// Writes the proposed times the user just approved.
    func applyShifts(_ proposals: [PrepShiftProposal]) async throws {
        for proposal in proposals {
            guard var task = prep.task(id: proposal.taskId) else { continue }
            task.scheduledAt = proposal.suggestedTime
            try await prep.update(task)
        }
    }

    func addQuickTask(
        title: String,
        at date: Date,
        durationMinutes: Int,
        kind: PrepTaskKind,
        dependencyId: UUID?,
        linkedDishId: UUID?
    ) async throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DomainError.validation("Give the task a name.")
        }
        guard durationMinutes > 0 else {
            throw DomainError.validation("Duration must be at least one minute.")
        }
        try await prep.add(
            PrepTask(
                title: trimmed,
                kind: kind,
                scheduledAt: date,
                durationMinutes: durationMinutes,
                dependencyId: dependencyId,
                linkedDishId: linkedDishId
            )
        )
    }

    /// Lays out thaw → prep → cook for a planned meal.
    @discardableResult
    func buildTimeline(for entry: MealPlanEntry, mealTime: Date) async throws -> Int {
        guard let dish = dishes.dish(id: entry.dishId) else {
            throw DomainError.notFound("That dish no longer exists.")
        }

        let frozenZoneIds = Set(
            zones.zones(includeArchived: false)
                .filter { $0.type == .freezer }
                .map(\.id)
        )
        let inventory = products.products(includeArchived: false)
        let frozen = dish.ingredients.filter { ingredient in
            inventory.contains { product in
                frozenZoneIds.contains(product.zoneId)
                    && product.trimmedName.compare(
                        ingredient.trimmedName,
                        options: .caseInsensitive
                    ) == .orderedSame
            }
        }

        let suggested = timeline.suggestedTasks(
            for: dish,
            mealTime: mealTime,
            frozenIngredients: frozen
        )
        for task in suggested {
            try await prep.add(task)
        }
        return suggested.count
    }

    func delete(taskId: UUID) async throws {
        try await prep.delete(id: taskId)
    }

    // MARK: - Leftovers

    func addLeftover(
        name: String,
        quantity: Double,
        unit: MeasurementUnit,
        sourceDishId: UUID?,
        zoneId: UUID?,
        storageNote: String,
        useByDate: Date?
    ) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DomainError.validation("Give the leftover a name.")
        }
        guard quantity > 0 else {
            throw DomainError.validation("Quantity must be greater than zero.")
        }

        let leftover = Leftover(
            name: trimmed,
            quantity: quantity,
            unit: unit,
            sourceDishId: sourceDishId,
            zoneId: zoneId,
            storageNote: storageNote,
            useByDate: useByDate
        )
        try await leftovers.add(leftover)
        try await history.record(
            ProductHistoryEntry(
                productId: nil,
                productName: trimmed,
                kind: .leftover,
                quantityDelta: quantity,
                unit: unit,
                note: "Saved as a leftover"
            )
        )
    }

    func resolveLeftover(id: UUID, status: LeftoverStatus) async throws {
        guard var leftover = leftovers.leftover(id: id) else {
            throw DomainError.notFound("That leftover no longer exists.")
        }
        leftover.status = status
        leftover.resolvedAt = Date()
        try await leftovers.update(leftover)

        if status != .stored {
            try await history.record(
                ProductHistoryEntry(
                    productId: nil,
                    productName: leftover.trimmedName,
                    kind: status == .used ? .used : .discarded,
                    quantityDelta: -leftover.quantity,
                    unit: leftover.unit,
                    note: "Leftover"
                )
            )
        }
    }

    func deleteLeftover(id: UUID) async throws {
        try await leftovers.delete(id: id)
    }
}
