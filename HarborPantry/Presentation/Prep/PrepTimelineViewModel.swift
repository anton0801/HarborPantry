//
//  PrepTimelineViewModel.swift
//  HarborPantry
//

import SwiftUI
import Combine

@MainActor
final class PrepTimelineViewModel: ObservableObject {
    enum Tab: String, CaseIterable, Identifiable, Hashable {
        case timeline
        case leftovers

        var id: String { rawValue }
        var displayName: String { self == .timeline ? "Prep Timeline" : "Leftovers" }
    }

    @Published var tab: Tab = .timeline
    @Published var selectedDay: Date = Calendar.current.startOfDay(for: Date())
    @Published private(set) var tasks: [PrepTask] = []
    @Published private(set) var leftovers: [Leftover] = []
    @Published private(set) var dishesById: [UUID: Dish] = [:]
    @Published private(set) var zones: [StorageZone] = []
    @Published private(set) var plannedMeals: [MealPlanEntry] = []
    @Published var errorMessage: String?
    @Published var toast: ToastState?
    @Published var reminderMessage: String?
    /// Dependent tasks wait for the user to accept the suggested new times.
    @Published var pendingShifts: [PrepShiftProposal] = []

    private let prepUseCases: PrepUseCases
    private let prepRepository: PrepRepository
    private let leftoverRepository: LeftoverRepository
    private let dishRepository: DishRepository
    private let mealPlanRepository: MealPlanRepository
    private let zoneRepository: StorageZoneRepository
    private let reminders: ReminderScheduling
    private let store: PantryStore
    private var cancellables = Set<AnyCancellable>()

    convenience init(dependencies: AppDependencies) {
        self.init(
            prepUseCases: dependencies.prepUseCases,
            prepRepository: dependencies.prepRepository,
            leftoverRepository: dependencies.leftoverRepository,
            dishRepository: dependencies.dishRepository,
            mealPlanRepository: dependencies.mealPlanRepository,
            zoneRepository: dependencies.zoneRepository,
            reminders: dependencies.reminderScheduler,
            store: dependencies.store
        )
    }

    init(
        prepUseCases: PrepUseCases,
        prepRepository: PrepRepository,
        leftoverRepository: LeftoverRepository,
        dishRepository: DishRepository,
        mealPlanRepository: MealPlanRepository,
        zoneRepository: StorageZoneRepository,
        reminders: ReminderScheduling,
        store: PantryStore
    ) {
        self.prepUseCases = prepUseCases
        self.prepRepository = prepRepository
        self.leftoverRepository = leftoverRepository
        self.dishRepository = dishRepository
        self.mealPlanRepository = mealPlanRepository
        self.zoneRepository = zoneRepository
        self.reminders = reminders
        self.store = store

        store.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reload() }
            .store(in: &cancellables)
        reload()
    }

    func reload() {
        tasks = prepUseCases.tasks(on: selectedDay)
        leftovers = leftoverRepository.leftovers().sorted { $0.createdAt > $1.createdAt }
        dishesById = Dictionary(
            uniqueKeysWithValues: dishRepository.dishes(includeArchived: true).map { ($0.id, $0) }
        )
        zones = zoneRepository.zones(includeArchived: false)
        plannedMeals = mealPlanRepository.entries(on: selectedDay)
    }

    func selectDay(_ day: Date) {
        selectedDay = Calendar.current.startOfDay(for: day)
        reload()
    }

    var storedLeftovers: [Leftover] { leftovers.filter { $0.status == .stored } }
    var resolvedLeftovers: [Leftover] { leftovers.filter { $0.status != .stored } }

    func dishName(_ id: UUID?) -> String? {
        guard let id = id else { return nil }
        return dishesById[id]?.trimmedName
    }

    func dependencyTitle(_ id: UUID?) -> String? {
        guard let id = id else { return nil }
        return prepRepository.task(id: id)?.title
    }

    var dependencyCandidates: [PrepTask] {
        prepUseCases.dependencyCandidates(for: nil, on: selectedDay)
    }

    // MARK: - Task actions

    func start(_ task: PrepTask) async {
        do {
            try await prepUseCases.start(taskId: task.id)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func complete(_ task: PrepTask) async {
        do {
            let proposals = try await prepUseCases.complete(taskId: task.id)
            if proposals.isEmpty {
                toast = ToastState(message: "\(task.title) done.")
            } else {
                pendingShifts = proposals
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delay(_ task: PrepTask, minutes: Int) async {
        do {
            let proposals = try await prepUseCases.delay(taskId: task.id, minutes: minutes)
            if proposals.isEmpty {
                toast = ToastState(message: "Delayed by \(minutes) min.")
            } else {
                pendingShifts = proposals
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reschedule(_ task: PrepTask, to date: Date) async {
        do {
            let proposals = try await prepUseCases.reschedule(taskId: task.id, to: date)
            if proposals.isEmpty {
                toast = ToastState(message: "Rescheduled.")
            } else {
                pendingShifts = proposals
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Applies only after the user has approved the suggested times.
    func applyPendingShifts() async {
        do {
            try await prepUseCases.applyShifts(pendingShifts)
            toast = ToastState(message: "Updated \(pendingShifts.count) dependent task\(pendingShifts.count == 1 ? "" : "s").")
            pendingShifts = []
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dismissPendingShifts() {
        pendingShifts = []
    }

    func addQuickTask(
        title: String,
        at date: Date,
        minutes: Int,
        kind: PrepTaskKind,
        dependencyId: UUID?
    ) async {
        do {
            try await prepUseCases.addQuickTask(
                title: title,
                at: date,
                durationMinutes: minutes,
                kind: kind,
                dependencyId: dependencyId,
                linkedDishId: nil
            )
            toast = ToastState(message: "Task added.")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func buildTimeline(for entry: MealPlanEntry, mealTime: Date) async {
        do {
            let count = try await prepUseCases.buildTimeline(for: entry, mealTime: mealTime)
            toast = ToastState(message: "Added \(count) task\(count == 1 ? "" : "s") — adjust any time to suit you.")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ task: PrepTask) async {
        do {
            try await prepUseCases.delete(taskId: task.id)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createReminder(for task: PrepTask) async {
        let reminder = PantryReminder(
            title: "Harbor Pantry",
            body: task.title,
            fireDate: task.scheduledAt,
            subject: .prepTask(task.id)
        )
        do {
            try await reminders.schedule(reminder)
            reminderMessage = "Reminder set for \(HarborFormat.time.string(from: task.scheduledAt))."
        } catch {
            reminderMessage = error.localizedDescription
        }
    }

    // MARK: - Leftovers

    func addLeftover(
        name: String,
        quantity: Double,
        unit: MeasurementUnit,
        dishId: UUID?,
        zoneId: UUID?,
        note: String,
        useByDate: Date?
    ) async {
        do {
            try await prepUseCases.addLeftover(
                name: name,
                quantity: quantity,
                unit: unit,
                sourceDishId: dishId,
                zoneId: zoneId,
                storageNote: note,
                useByDate: useByDate
            )
            toast = ToastState(message: "Leftover saved.")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resolveLeftover(_ leftover: Leftover, status: LeftoverStatus) async {
        do {
            try await prepUseCases.resolveLeftover(id: leftover.id, status: status)
            toast = ToastState(message: status == .used ? "Marked as used." : "Marked as discarded.")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteLeftover(_ leftover: Leftover) async {
        do {
            try await prepUseCases.deleteLeftover(id: leftover.id)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
