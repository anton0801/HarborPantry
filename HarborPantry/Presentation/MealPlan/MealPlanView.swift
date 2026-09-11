//
//  MealPlanView.swift
//  HarborPantry
//
//  Screen 11 — the weekly plan, with ingredient coverage for every meal.
//

import SwiftUI

struct MealPlanView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var viewModel: MealPlanViewModel

    @State private var showAddMeal = false
    @State private var showDishBuilder = false
    @State private var showDuplicateDay = false
    @State private var showClearConfirmation = false
    @State private var movingMeal: MealPlanViewModel.PlannedMeal?

    init(dependencies: AppDependencies) {
        _viewModel = StateObject(wrappedValue: MealPlanViewModel(dependencies: dependencies))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: HarborMetrics.spacingM) {
                    weekStrip

                    if let error = viewModel.errorMessage {
                        ErrorStateView(message: error)
                    }

                    if viewModel.isDayEmpty {
                        emptyDay
                    } else {
                        summaryCard
                        ForEach(viewModel.meals) { meal in
                            mealCard(meal)
                        }
                        dayActions
                    }
                }
                .padding(.horizontal, HarborMetrics.spacingL)
                .padding(.bottom, HarborMetrics.spacingXL)
            }
            .harborScreenBackground()
            .navigationTitle("Meal Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Add Dish to Plan") { showAddMeal = true }
                        Button("Create New Dish") { showDishBuilder = true }
                        Divider()
                        Button("Duplicate This Day") { showDuplicateDay = true }
                        Button("Clear This Day", role: .destructive) { showClearConfirmation = true }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .harborToast($viewModel.toast)
        .sheet(isPresented: $showAddMeal) {
            NavigationView {
                AddMealView(
                    dishes: viewModel.dishes,
                    defaultServings: viewModel.profile.peopleCount,
                    day: viewModel.selectedDay,
                    onCreateDish: {
                        showAddMeal = false
                        showDishBuilder = true
                    }
                ) { dishId, slot, customName, servings, guests in
                    Task {
                        await viewModel.addDish(
                            dishId: dishId,
                            slot: slot,
                            customName: customName,
                            servings: servings,
                            guests: guests
                        )
                        showAddMeal = false
                    }
                }
            }
            .navigationViewStyle(.stack)
        }
        .sheet(isPresented: $showDishBuilder) {
            NavigationView {
                DishBuilderView(dependencies: dependencies, dish: nil) { _ in
                    showDishBuilder = false
                }
            }
            .navigationViewStyle(.stack)
            .environmentObject(dependencies)
        }
        .sheet(isPresented: $showDuplicateDay) {
            NavigationView {
                DayPickerView(
                    title: "Copy this day to",
                    days: viewModel.weekDays,
                    excluding: viewModel.selectedDay
                ) { destination in
                    Task {
                        await viewModel.duplicateDay(to: destination)
                        showDuplicateDay = false
                    }
                }
            }
            .navigationViewStyle(.stack)
        }
        .sheet(item: $movingMeal) { meal in
            NavigationView {
                MoveMealView(
                    meal: meal,
                    days: viewModel.weekDays
                ) { day, slot in
                    Task {
                        await viewModel.move(entryId: meal.entry.id, to: day, slot: slot)
                        movingMeal = nil
                    }
                }
            }
            .navigationViewStyle(.stack)
        }
        .sheet(item: $viewModel.servingsPreview) { preview in
            NavigationView {
                ServingsPreviewView(preview: preview) { servings, guests in
                    if let entryId = viewModel.previewEntryId {
                        Task { await viewModel.applyServings(entryId: entryId, servings: servings, guests: guests) }
                    }
                } onCancel: {
                    viewModel.servingsPreview = nil
                    viewModel.previewEntryId = nil
                }
            }
            .navigationViewStyle(.stack)
        }
        .alert("Clear this day?", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                Task { await viewModel.clearDay() }
            }
        } message: {
            Text("Every meal planned for \(HarborFormat.fullDate.string(from: viewModel.selectedDay)) is removed, along with the shopping rows it generated.")
        }
    }

    // MARK: - Week strip

    private var weekStrip: some View {
        VStack(spacing: HarborMetrics.spacingS) {
            HStack {
                Button {
                    viewModel.shiftWeek(by: -1)
                } label: {
                    Image(systemName: "chevron.left").frame(width: 32, height: 32)
                }
                Spacer()
                Text(HarborFormat.fullDate.string(from: viewModel.selectedDay))
                    .font(HarborFont.headline(16))
                    .foregroundColor(HarborColor.textPrimary)
                Spacer()
                Button {
                    viewModel.shiftWeek(by: 1)
                } label: {
                    Image(systemName: "chevron.right").frame(width: 32, height: 32)
                }
            }
            .foregroundColor(HarborColor.accent)

            HStack(spacing: 6) {
                ForEach(viewModel.weekDays, id: \.self) { day in
                    dayTab(day)
                }
            }
        }
        .padding(.top, HarborMetrics.spacingS)
    }

    private func dayTab(_ day: Date) -> some View {
        let isSelected = Calendar.current.isDate(day, inSameDayAs: viewModel.selectedDay)
        let count = viewModel.mealCount(on: day)
        return Button {
            viewModel.selectDay(day)
        } label: {
            VStack(spacing: 3) {
                Text(HarborFormat.weekdayShort.string(from: day))
                    .font(HarborFont.caption(10.5))
                    .foregroundColor(isSelected ? .white.opacity(0.85) : HarborColor.textSecondary)
                Text(HarborFormat.dayNumber.string(from: day))
                    .font(HarborFont.numeric(16))
                    .foregroundColor(isSelected ? .white : HarborColor.textPrimary)
                Circle()
                    .fill(count > 0 ? (isSelected ? Color.white : HarborPalette.sunGold) : .clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, HarborMetrics.spacingS)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(HarborGradient.ocean) : AnyShapeStyle(HarborColor.surface))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? .clear : HarborColor.separator, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty

    private var emptyDay: some View {
        VStack(spacing: HarborMetrics.spacingM) {
            EmptyStateView(
                title: viewModel.hasDishes ? "Nothing planned yet" : "No dishes yet",
                message: viewModel.hasDishes
                    ? "Add one of your dishes to this day and Harbor Pantry will check it against what you already have."
                    : "Build your first dish with its ingredients and servings. Nothing is pre-filled — the recipes are entirely yours.",
                illustration: .mealPlate,
                illustrationWidth: 190,
                actionTitle: viewModel.hasDishes ? "Add Dish" : "Create a Dish",
                action: {
                    if viewModel.hasDishes { showAddMeal = true } else { showDishBuilder = true }
                }
            )
        }
    }

    // MARK: - Cards

    private var summaryCard: some View {
        HarborCard {
            HStack(spacing: HarborMetrics.spacingM) {
                // The small variant of the plate art; the big one only shows in
                // the empty state.
                HarborIllustrationView(illustration: .mealPlate)
                    .frame(width: 88)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(viewModel.meals.count) meal\(viewModel.meals.count == 1 ? "" : "s") planned")
                        .font(HarborFont.headline(16))
                        .foregroundColor(HarborColor.textPrimary)
                    Text("\(totalServings) serving\(totalServings == 1 ? "" : "s") · \(totalMinutes) min of prep and cooking")
                        .font(HarborFont.caption(12))
                        .foregroundColor(HarborColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
        }
    }

    private var totalServings: Int {
        viewModel.meals.reduce(0) { $0 + $1.entry.totalServings }
    }

    private var totalMinutes: Int {
        viewModel.meals.reduce(0) { $0 + $1.dish.totalMinutes }
    }

    private func mealCard(_ meal: MealPlanViewModel.PlannedMeal) -> some View {
        HarborAccentCard(accent: HarborColor.coverage(meal.coverage.status)) {
            VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Image(systemName: meal.entry.slot.symbolName)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(HarborColor.textSecondary)
                            Text(meal.entry.slotTitle)
                                .font(HarborFont.caption(11.5))
                                .foregroundColor(HarborColor.textSecondary)
                        }
                        Text(meal.dish.trimmedName)
                            .font(HarborFont.headline(17))
                            .foregroundColor(HarborColor.textPrimary)
                    }
                    Spacer()
                    StatusPill(
                        text: meal.coverage.status.displayName,
                        systemImage: meal.coverage.status.symbolName,
                        color: HarborColor.coverage(meal.coverage.status)
                    )
                }

                HStack(spacing: HarborMetrics.spacingM) {
                    metric(
                        value: "\(meal.entry.totalServings)",
                        label: meal.entry.guests > 0
                            ? "\(meal.entry.servings) + \(meal.entry.guests) guest\(meal.entry.guests == 1 ? "" : "s")"
                            : "servings"
                    )
                    metric(value: "\(meal.dish.totalMinutes)", label: "minutes")
                    metric(
                        value: "\(meal.coverage.ingredients.count - meal.coverage.missingCount)/\(meal.coverage.ingredients.count)",
                        label: "in stock"
                    )
                }

                if meal.coverage.missingCount > 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(meal.coverage.ingredients.filter { $0.status != .available }) { row in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(HarborColor.coverage(row.status))
                                    .frame(width: 6, height: 6)
                                Text(row.ingredient.trimmedName)
                                    .font(HarborFont.caption(12))
                                    .foregroundColor(HarborColor.textPrimary)
                                Spacer()
                                if row.hasUnitConflict {
                                    Text("unit mismatch")
                                        .font(HarborFont.caption(11))
                                        .foregroundColor(HarborPalette.sunGold)
                                } else {
                                    Text("need \(HarborFormat.quantity(row.missing, row.ingredient.unit))")
                                        .font(HarborFont.caption(11))
                                        .foregroundColor(HarborColor.textSecondary)
                                }
                            }
                        }
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: HarborMetrics.spacingS) {
                        Button("Scale Servings") {
                            viewModel.prepareServingsChange(
                                entryId: meal.entry.id,
                                newTotal: meal.entry.totalServings + 1
                            )
                        }
                        .buttonStyle(HarborChipButtonStyle())

                        Button("Move") { movingMeal = meal }
                            .buttonStyle(HarborChipButtonStyle())

                        if meal.coverage.missingCount > 0 {
                            Button("Add Missing to Shopping") {
                                Task { await viewModel.addMissingToShopping(meal) }
                            }
                            .buttonStyle(HarborChipButtonStyle(tint: HarborPalette.leaf))
                        }

                        Button("Remove") {
                            Task { await viewModel.remove(entryId: meal.entry.id) }
                        }
                        .buttonStyle(HarborChipButtonStyle(tint: HarborPalette.coral))
                    }
                }
            }
        }
    }

    private func metric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(HarborFont.numeric(17))
                .foregroundColor(HarborColor.accent)
            Text(label)
                .font(HarborFont.caption(10.5))
                .foregroundColor(HarborColor.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dayActions: some View {
        HStack(spacing: HarborMetrics.spacingS) {
            Button("Add Dish") { showAddMeal = true }
                .buttonStyle(HarborPrimaryButtonStyle())
            Button("New Dish") { showDishBuilder = true }
                .buttonStyle(HarborSecondaryButtonStyle())
        }
    }
}

extension ServingsPreview: Identifiable {
    public var id: String { "\(currentServings)-\(newServings)-\(lines.count)" }
}
