//
//  FreshnessCalendarViewModel.swift
//  HarborPantry
//

import SwiftUI
import Combine

@MainActor
final class FreshnessCalendarViewModel: ObservableObject {
    enum Presentation: String, CaseIterable, Identifiable, Hashable {
        case list
        case calendar

        var id: String { rawValue }
        var displayName: String { self == .list ? "List" : "Calendar" }
    }

    @Published var presentation: Presentation = .list
    @Published var selectedDay: Date = Calendar.current.startOfDay(for: Date())
    @Published private(set) var grouped: [FreshnessBucket: [Product]] = [:]
    @Published private(set) var zonesById: [UUID: StorageZone] = [:]
    @Published var errorMessage: String?
    @Published var toast: ToastState?
    @Published var reminderMessage: String?

    private let productRepository: ProductRepository
    private let zoneRepository: StorageZoneRepository
    private let dishRepository: DishRepository
    private let mealPlanRepository: MealPlanRepository
    private let inventoryUseCases: InventoryUseCases
    private let reminders: ReminderScheduling
    private let freshness: FreshnessService
    private let store: PantryStore
    private let calendar = Calendar.current
    private var cancellables = Set<AnyCancellable>()

    convenience init(dependencies: AppDependencies) {
        self.init(
            productRepository: dependencies.productRepository,
            zoneRepository: dependencies.zoneRepository,
            dishRepository: dependencies.dishRepository,
            mealPlanRepository: dependencies.mealPlanRepository,
            inventoryUseCases: dependencies.inventoryUseCases,
            reminders: dependencies.reminderScheduler,
            freshness: dependencies.freshnessService,
            store: dependencies.store
        )
    }

    init(
        productRepository: ProductRepository,
        zoneRepository: StorageZoneRepository,
        dishRepository: DishRepository,
        mealPlanRepository: MealPlanRepository,
        inventoryUseCases: InventoryUseCases,
        reminders: ReminderScheduling,
        freshness: FreshnessService,
        store: PantryStore
    ) {
        self.productRepository = productRepository
        self.zoneRepository = zoneRepository
        self.dishRepository = dishRepository
        self.mealPlanRepository = mealPlanRepository
        self.inventoryUseCases = inventoryUseCases
        self.reminders = reminders
        self.freshness = freshness
        self.store = store

        store.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reload() }
            .store(in: &cancellables)
        reload()
    }

    func reload() {
        let products = productRepository.products(includeArchived: false)
        grouped = freshness.group(products: products)
        zonesById = Dictionary(
            uniqueKeysWithValues: zoneRepository.zones(includeArchived: true).map { ($0.id, $0) }
        )
    }

    var isEmpty: Bool { grouped.values.allSatisfy(\.isEmpty) }

    var orderedBuckets: [FreshnessBucket] {
        FreshnessBucket.displayOrder.filter { !(grouped[$0] ?? []).isEmpty }
    }

    func products(in bucket: FreshnessBucket) -> [Product] {
        grouped[bucket] ?? []
    }

    func zoneName(for product: Product) -> String {
        zonesById[product.zoneId]?.name ?? "Unassigned"
    }

    func daysText(for product: Product) -> String {
        guard let days = freshness.daysRemaining(for: product) else { return "No date" }
        return HarborFormat.relativeDays(days)
    }

    /// Dish names the product is linked to, so the calendar can show what a
    /// product is already committed to.
    func linkedMealNames(for product: Product) -> [String] {
        let dishes = dishRepository.dishes(includeArchived: false).filter { dish in
            dish.ingredients.contains { ingredient in
                ingredient.linkedProductId == product.id
                    || ingredient.trimmedName.compare(
                        product.trimmedName,
                        options: .caseInsensitive
                    ) == .orderedSame
            }
        }
        let dishIds = Set(dishes.map(\.id))
        let planned = mealPlanRepository.entries().filter { dishIds.contains($0.dishId) }
        guard !planned.isEmpty else { return [] }
        return dishes.map(\.trimmedName)
    }

    // MARK: - Calendar view

    /// Days of the month around `selectedDay`, padded to whole weeks.
    var monthDays: [Date] {
        guard
            let interval = calendar.dateInterval(of: .month, for: selectedDay),
            let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: interval.start)
        else { return [] }

        var days: [Date] = []
        var cursor = firstWeek.start
        while cursor < interval.end || calendar.component(.weekday, from: cursor) != calendar.firstWeekday {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
            if days.count >= 42 { break }
        }
        return days
    }

    func products(on day: Date) -> [Product] {
        let target = calendar.startOfDay(for: day)
        return productRepository.products(includeArchived: false).filter { product in
            guard let useBy = product.useByDate else { return false }
            return calendar.startOfDay(for: useBy) == target
        }
    }

    func isInSelectedMonth(_ day: Date) -> Bool {
        calendar.isDate(day, equalTo: selectedDay, toGranularity: .month)
    }

    func shiftMonth(by value: Int) {
        if let next = calendar.date(byAdding: .month, value: value, to: selectedDay) {
            selectedDay = next
        }
    }

    // MARK: - Actions

    func adjustDate(for product: Product, to date: Date?) async {
        var updated = product
        updated.useByDate = date
        do {
            try await inventoryUseCases.updateProduct(updated, previous: product)
            toast = ToastState(message: date == nil
                ? "Date cleared for \(product.trimmedName)."
                : "Date updated for \(product.trimmedName).")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markUsed(_ product: Product) async {
        do {
            let token = try await inventoryUseCases.useQuantity(
                productId: product.id,
                amount: product.quantity,
                note: "Marked used from the calendar"
            )
            toast = ToastState(message: "\(product.trimmedName) marked used.") { [weak self] in
                Task {
                    try? await self?.inventoryUseCases.undo(token)
                    self?.toast = nil
                }
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Schedules a local reminder for the date the user chose.
    func createReminder(for product: Product) async {
        guard let useBy = product.useByDate else {
            reminderMessage = "Add a date to this product first — Harbor Pantry will not invent one."
            return
        }
        var fireDate = calendar.date(
            bySettingHour: 9, minute: 0, second: 0,
            of: calendar.startOfDay(for: useBy)
        ) ?? useBy
        if fireDate <= Date() {
            fireDate = Date().addingTimeInterval(60 * 60)
        }

        let reminder = PantryReminder(
            title: "Harbor Pantry",
            body: "\(product.trimmedName) reaches the date you set.",
            fireDate: fireDate,
            subject: .product(product.id)
        )
        do {
            try await reminders.schedule(reminder)
            reminderMessage = "Reminder set for \(HarborFormat.dateTime.string(from: fireDate))."
        } catch {
            reminderMessage = error.localizedDescription
        }
    }
}
