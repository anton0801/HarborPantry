//
//  MealPlanSheets.swift
//  HarborPantry
//
//  Supporting sheets for the meal plan: adding, moving, copying and scaling.
//

import SwiftUI

/// Adds one of the user's dishes to the selected day.
struct AddMealView: View {
    let dishes: [Dish]
    let defaultServings: Int
    let day: Date
    let onCreateDish: () -> Void
    let onAdd: (UUID, MealSlot, String, Int, Int) -> Void

    @Environment(\.presentationMode) private var presentationMode
    @State private var selectedDishId: UUID?
    @State private var slot: MealSlot = .dinner
    @State private var customName = ""
    @State private var servings: Int
    @State private var guests = 0

    init(
        dishes: [Dish],
        defaultServings: Int,
        day: Date,
        onCreateDish: @escaping () -> Void,
        onAdd: @escaping (UUID, MealSlot, String, Int, Int) -> Void
    ) {
        self.dishes = dishes
        self.defaultServings = defaultServings
        self.day = day
        self.onCreateDish = onCreateDish
        self.onAdd = onAdd
        _servings = State(initialValue: max(1, defaultServings))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: HarborMetrics.spacingM) {
                if dishes.isEmpty {
                    EmptyStateView(
                        title: "No dishes to add",
                        message: "Create a dish first — Harbor Pantry ships with no sample recipes.",
                        illustration: .mealPlate,
                        illustrationWidth: 170,
                        actionTitle: "Create a Dish",
                        action: onCreateDish
                    )
                } else {
                    HarborCard {
                        VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                            SectionHeader(title: "Dish")
                            ForEach(dishes) { dish in
                                Button {
                                    selectedDishId = dish.id
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(dish.trimmedName)
                                                .font(HarborFont.headline(15))
                                                .foregroundColor(HarborColor.textPrimary)
                                            Text("\(dish.ingredients.count) ingredient\(dish.ingredients.count == 1 ? "" : "s") · base \(dish.servings) serving\(dish.servings == 1 ? "" : "s")")
                                                .font(HarborFont.caption(11.5))
                                                .foregroundColor(HarborColor.textSecondary)
                                        }
                                        Spacer()
                                        Image(systemName: selectedDishId == dish.id ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedDishId == dish.id ? HarborColor.accent : HarborColor.separator)
                                    }
                                    .contentShape(Rectangle())
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    HarborCard {
                        VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                            SectionHeader(title: "When and for whom")

                            FormRow(label: "Meal Slot") {
                                HarborMenuPicker(
                                    items: MealSlot.allCases,
                                    title: { $0.displayName },
                                    symbol: { $0.symbolName },
                                    selection: $slot
                                )
                            }

                            if slot == .custom {
                                FormRow(label: "Slot Name") {
                                    HarborTextField(placeholder: "Late supper", text: $customName)
                                }
                            }

                            FormRow(label: "Household Servings", isRequired: true) {
                                HStack {
                                    CountStepper(value: $servings, range: 1...50, label: "servings")
                                    Spacer()
                                }
                            }

                            FormRow(label: "Guests", hint: "Added on top of household servings.") {
                                HStack {
                                    CountStepper(value: $guests, range: 0...50, label: "guests")
                                    Spacer()
                                }
                            }

                            HStack {
                                Text("Total plates")
                                    .font(HarborFont.body(14))
                                    .foregroundColor(HarborColor.textSecondary)
                                Spacer()
                                Text("\(servings + guests)")
                                    .font(HarborFont.numeric(18))
                                    .foregroundColor(HarborColor.accent)
                            }
                        }
                    }

                    Button("Add to \(HarborFormat.dayMonth.string(from: day))") {
                        if let id = selectedDishId {
                            onAdd(id, slot, customName, servings, guests)
                        }
                    }
                    .buttonStyle(HarborPrimaryButtonStyle(isEnabled: selectedDishId != nil))
                    .disabled(selectedDishId == nil)
                }
            }
            .padding(HarborMetrics.spacingL)
        }
        .harborScreenBackground()
        .navigationTitle("Add Dish")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { presentationMode.wrappedValue.dismiss() }
            }
        }
    }
}

/// Moves an existing meal — the entry is updated in place, never duplicated.
struct MoveMealView: View {
    let meal: MealPlanViewModel.PlannedMeal
    let days: [Date]
    let onMove: (Date, MealSlot) -> Void

    @Environment(\.presentationMode) private var presentationMode
    @State private var day: Date
    @State private var slot: MealSlot

    init(meal: MealPlanViewModel.PlannedMeal, days: [Date], onMove: @escaping (Date, MealSlot) -> Void) {
        self.meal = meal
        self.days = days
        self.onMove = onMove
        _day = State(initialValue: meal.entry.date)
        _slot = State(initialValue: meal.entry.slot)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: HarborMetrics.spacingM) {
                HarborCard {
                    VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                        Text(meal.dish.trimmedName)
                            .font(HarborFont.title(20))
                            .foregroundColor(HarborColor.textPrimary)
                        Text("Moving keeps this one meal — no copy is left behind on the old day.")
                            .font(HarborFont.caption(12))
                            .foregroundColor(HarborColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        FormRow(label: "Day") {
                            HarborMenuPicker(
                                items: days,
                                title: { HarborFormat.fullDate.string(from: $0) },
                                selection: $day
                            )
                        }

                        FormRow(label: "Meal Slot") {
                            HarborMenuPicker(
                                items: MealSlot.allCases,
                                title: { $0.displayName },
                                symbol: { $0.symbolName },
                                selection: $slot
                            )
                        }
                    }
                }

                Button("Move Meal") { onMove(day, slot) }
                    .buttonStyle(HarborPrimaryButtonStyle())
            }
            .padding(HarborMetrics.spacingL)
        }
        .harborScreenBackground()
        .navigationTitle("Move Meal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { presentationMode.wrappedValue.dismiss() }
            }
        }
    }
}

/// Picks a destination day for "Duplicate Day".
struct DayPickerView: View {
    let title: String
    let days: [Date]
    let excluding: Date
    let onPick: (Date) -> Void

    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        ScrollView {
            VStack(spacing: HarborMetrics.spacingS) {
                ForEach(days.filter { !Calendar.current.isDate($0, inSameDayAs: excluding) }, id: \.self) { day in
                    Button {
                        onPick(day)
                    } label: {
                        HStack {
                            Text(HarborFormat.fullDate.string(from: day))
                                .font(HarborFont.body(15))
                                .foregroundColor(HarborColor.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(HarborColor.textSecondary.opacity(0.6))
                        }
                        .padding(HarborMetrics.spacingM)
                        .background(
                            RoundedRectangle(cornerRadius: HarborMetrics.cardRadius, style: .continuous)
                                .fill(HarborColor.surface)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(HarborMetrics.spacingL)
        }
        .harborScreenBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { presentationMode.wrappedValue.dismiss() }
            }
        }
    }
}

/// Screen 12's portions half — shows exactly what changes before it is applied.
struct ServingsPreviewView: View {
    let preview: ServingsPreview
    let onApply: (Int, Int) -> Void
    let onCancel: () -> Void

    @State private var servings: Int
    @State private var guests: Int

    init(preview: ServingsPreview, onApply: @escaping (Int, Int) -> Void, onCancel: @escaping () -> Void) {
        self.preview = preview
        self.onApply = onApply
        self.onCancel = onCancel
        _servings = State(initialValue: max(1, preview.newServings))
        _guests = State(initialValue: 0)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: HarborMetrics.spacingM) {
                HarborCard {
                    VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                        Text("Portions & Guests")
                            .font(HarborFont.title(20))
                            .foregroundColor(HarborColor.textPrimary)
                        Text("Nothing changes until you apply this. Here is what the new count would need.")
                            .font(HarborFont.body(14))
                            .foregroundColor(HarborColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        FormRow(label: "Household Servings") {
                            HStack {
                                CountStepper(value: $servings, range: 1...50, label: "servings")
                                Spacer()
                            }
                        }
                        FormRow(label: "Guests") {
                            HStack {
                                CountStepper(value: $guests, range: 0...50, label: "guests")
                                Spacer()
                            }
                        }
                    }
                }

                HarborCard {
                    VStack(alignment: .leading, spacing: HarborMetrics.spacingS) {
                        SectionHeader(
                            title: "Recalculation preview",
                            subtitle: "From \(preview.currentServings) to \(preview.newServings) serving\(preview.newServings == 1 ? "" : "s")"
                        )
                        ForEach(preview.lines) { line in
                            HStack {
                                Text(line.name)
                                    .font(HarborFont.body(14))
                                    .foregroundColor(HarborColor.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                Text(HarborFormat.quantity(line.currentQuantity, line.unit))
                                    .font(HarborFont.caption(12))
                                    .foregroundColor(HarborColor.textSecondary)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(HarborColor.textSecondary)
                                Text(HarborFormat.quantity(line.newQuantity, line.unit))
                                    .font(HarborFont.caption(12.5))
                                    .foregroundColor(HarborColor.accent)
                            }
                        }

                        if preview.newlyMissingCount > 0 {
                            Text("\(preview.newlyMissingCount) more ingredient\(preview.newlyMissingCount == 1 ? "" : "s") would fall short of what you have in stock.")
                                .font(HarborFont.caption(11.5))
                                .foregroundColor(HarborPalette.coral)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Button("Apply \(servings + guests) Serving\(servings + guests == 1 ? "" : "s")") {
                    onApply(servings, guests)
                }
                .buttonStyle(HarborPrimaryButtonStyle())

                Button("Cancel") { onCancel() }
                    .buttonStyle(HarborSecondaryButtonStyle())
            }
            .padding(HarborMetrics.spacingL)
        }
        .harborScreenBackground()
        .navigationTitle("Scale Servings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
