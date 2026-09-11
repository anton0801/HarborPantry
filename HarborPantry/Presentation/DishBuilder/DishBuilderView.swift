//
//  DishBuilderView.swift
//  HarborPantry
//
//  Screen 12 — build a dish and see straight away what the pantry can cover.
//

import SwiftUI

struct DishBuilderView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var viewModel: DishBuilderViewModel

    private let onSaved: (Dish?) -> Void

    @State private var showAddIngredient = false
    @State private var showInventoryPicker = false
    @State private var stepDraft = ""
    @State private var showDeleteConfirmation = false

    init(dependencies: AppDependencies, dish: Dish?, onSaved: @escaping (Dish?) -> Void) {
        self.onSaved = onSaved
        _viewModel = StateObject(
            wrappedValue: DishBuilderViewModel(dependencies: dependencies, dish: dish)
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: HarborMetrics.spacingM) {
                headerCard
                basicsCard
                ingredientsCard
                coverageCard
                timingCard
                stepsCard
                notesCard

                if let error = viewModel.errorMessage {
                    ErrorStateView(message: error)
                }

                actions
            }
            .padding(.horizontal, HarborMetrics.spacingL)
            .padding(.vertical, HarborMetrics.spacingM)
        }
        .harborScreenBackground()
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .harborToast($viewModel.toast)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    onSaved(nil)
                    presentationMode.wrappedValue.dismiss()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.isEditing {
                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash").foregroundColor(HarborPalette.coral)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddIngredient) {
            NavigationView {
                AddIngredientView { name, quantity, unit, category in
                    viewModel.addIngredient(
                        name: name,
                        quantity: quantity,
                        unit: unit,
                        category: category
                    )
                    showAddIngredient = false
                }
            }
            .navigationViewStyle(.stack)
        }
        .sheet(isPresented: $showInventoryPicker) {
            NavigationView {
                InventoryIngredientPicker(products: viewModel.inventoryProducts) { productId, quantity in
                    viewModel.addIngredientFromInventory(productId: productId, quantity: quantity)
                    showInventoryPicker = false
                }
            }
            .navigationViewStyle(.stack)
        }
        .alert("Delete this dish?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    if await viewModel.delete() {
                        onSaved(nil)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        } message: {
            Text("The dish, its planned meals and the shopping rows those meals generated are removed.")
        }
    }

    // MARK: - Cards

    private var headerCard: some View {
        HarborCard {
            HStack(spacing: HarborMetrics.spacingM) {
                HarborIllustrationView(illustration: .recipeJournal)
                    .frame(width: 120)
                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.name.isEmpty ? "New dish" : viewModel.name)
                        .font(HarborFont.headline(17))
                        .foregroundColor(HarborColor.textPrimary)
                        .lineLimit(2)
                    Text("\(viewModel.ingredients.count) ingredient\(viewModel.ingredients.count == 1 ? "" : "s") · \(viewModel.servings) serving\(viewModel.servings == 1 ? "" : "s")")
                        .font(HarborFont.caption(12))
                        .foregroundColor(HarborColor.textSecondary)
                }
                Spacer()
            }
        }
    }

    private var basicsCard: some View {
        HarborCard {
            VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                FormRow(label: "Dish Name", isRequired: true) {
                    HarborTextField(placeholder: "Baked cod with potatoes", text: $viewModel.name)
                }
                FormRow(label: "Category") {
                    HarborMenuPicker(
                        items: DishCategory.allCases,
                        title: { $0.displayName },
                        selection: $viewModel.category
                    )
                }
                FormRow(
                    label: "Serving Count",
                    isRequired: true,
                    hint: "The number this ingredient list is written for."
                ) {
                    HStack {
                        CountStepper(value: $viewModel.servings, range: 1...50, label: "servings")
                        Spacer()
                    }
                }
            }
            .onChange(of: viewModel.servings) { _ in viewModel.refreshCoverage() }
        }
    }

    private var ingredientsCard: some View {
        HarborCard {
            VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                SectionHeader(
                    title: "Ingredients",
                    subtitle: "Units of different kinds are never merged for you."
                )

                if viewModel.ingredients.isEmpty {
                    Text("No ingredients yet. Add them by hand, or pull them straight from your inventory so the units already line up.")
                        .font(HarborFont.body(14))
                        .foregroundColor(HarborColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(viewModel.ingredients) { ingredient in
                        HStack(spacing: HarborMetrics.spacingM) {
                            Image(systemName: ingredient.category.symbolName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(HarborColor.accent)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(HarborColor.accent.opacity(0.12)))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(ingredient.trimmedName)
                                    .font(HarborFont.headline(15))
                                    .foregroundColor(HarborColor.textPrimary)
                                if ingredient.linkedProductId != nil {
                                    Text("Linked to inventory")
                                        .font(HarborFont.caption(10.5))
                                        .foregroundColor(HarborPalette.leaf)
                                }
                            }
                            Spacer()
                            Text(HarborFormat.quantity(ingredient.quantity, ingredient.unit))
                                .font(HarborFont.caption(13))
                                .foregroundColor(HarborColor.textSecondary)
                            Button {
                                viewModel.removeIngredient(ingredient.id)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(HarborPalette.coral.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                HStack(spacing: HarborMetrics.spacingS) {
                    Button("Add Ingredient") { showAddIngredient = true }
                        .buttonStyle(HarborChipButtonStyle())
                    Button("Use from Inventory") { showInventoryPicker = true }
                        .buttonStyle(HarborChipButtonStyle(tint: HarborPalette.leaf))
                    Spacer()
                }
            }
        }
    }

    @ViewBuilder
    private var coverageCard: some View {
        if let coverage = viewModel.coverage, !coverage.ingredients.isEmpty {
            HarborCard {
                VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                    SectionHeader(
                        title: "Coverage",
                        subtitle: "Checked against what is in your inventory right now."
                    )

                    HStack(spacing: HarborMetrics.spacingS) {
                        StatusPill(
                            text: coverage.status.displayName,
                            systemImage: coverage.status.symbolName,
                            color: HarborColor.coverage(coverage.status),
                            filled: true
                        )
                        Text("\(coverage.ingredients.count - coverage.missingCount) of \(coverage.ingredients.count) covered")
                            .font(HarborFont.caption(12))
                            .foregroundColor(HarborColor.textSecondary)
                        Spacer()
                    }

                    ForEach(coverage.ingredients) { row in
                        HStack(spacing: HarborMetrics.spacingS) {
                            Circle()
                                .fill(HarborColor.coverage(row.status))
                                .frame(width: 7, height: 7)
                            Text(row.ingredient.trimmedName)
                                .font(HarborFont.body(14))
                                .foregroundColor(HarborColor.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            if row.hasUnitConflict {
                                Text("unit mismatch")
                                    .font(HarborFont.caption(11))
                                    .foregroundColor(HarborPalette.sunGold)
                            } else {
                                Text("\(row.available.quantityText) / \(HarborFormat.quantity(row.required, row.ingredient.unit))")
                                    .font(HarborFont.caption(11.5))
                                    .foregroundColor(HarborColor.textSecondary)
                            }
                        }
                    }

                    if coverage.missingCount > 0 {
                        Button("Add Missing to Shopping") {
                            Task { await viewModel.addMissingToShopping() }
                        }
                        .buttonStyle(HarborSecondaryButtonStyle(tint: HarborPalette.leaf))
                    }
                }
            }
        }
    }

    private var timingCard: some View {
        HarborCard {
            VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                SectionHeader(title: "Timing")
                HStack(spacing: HarborMetrics.spacingM) {
                    FormRow(label: "Prep (min)") {
                        HStack {
                            CountStepper(value: $viewModel.prepMinutes, range: 0...600, label: "min")
                            Spacer()
                        }
                    }
                }
                HStack(spacing: HarborMetrics.spacingM) {
                    FormRow(label: "Cook (min)") {
                        HStack {
                            CountStepper(value: $viewModel.cookMinutes, range: 0...600, label: "min")
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    private var stepsCard: some View {
        HarborCard {
            VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                SectionHeader(title: "Steps")

                ForEach(Array(viewModel.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: HarborMetrics.spacingS) {
                        Text("\(index + 1)")
                            .font(HarborFont.numeric(13))
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(HarborColor.accent))
                        Text(step)
                            .font(HarborFont.body(14))
                            .foregroundColor(HarborColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Button {
                            viewModel.removeStep(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(HarborPalette.coral.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: HarborMetrics.spacingS) {
                    HarborTextField(placeholder: "Add a step", text: $stepDraft)
                    Button {
                        viewModel.addStep(stepDraft)
                        stepDraft = ""
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: HarborMetrics.controlRadius, style: .continuous)
                                    .fill(HarborGradient.ocean)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(stepDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(stepDraft.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                }
            }
        }
    }

    private var notesCard: some View {
        HarborCard {
            VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                SectionHeader(title: "Dietary & Allergen Notes")
                FormRow(label: "Dietary Tags") {
                    TagEditor(tags: $viewModel.dietaryTags, placeholder: "e.g. pescatarian")
                }
                FormRow(label: "Allergen Notes") {
                    HarborTextEditor(
                        text: $viewModel.allergenNotes,
                        minHeight: 78,
                        placeholder: "What you want to remember about this dish."
                    )
                }
                UserDataNotice(
                    text: "Allergen notes show exactly what you typed. Harbor Pantry does not analyse ingredients and cannot guarantee a dish is safe for anyone."
                )
            }
        }
    }

    private var actions: some View {
        Button(viewModel.isEditing ? "Save Changes" : "Save Dish") {
            Task {
                if let dish = await viewModel.save() {
                    onSaved(dish)
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .buttonStyle(HarborPrimaryButtonStyle(isEnabled: viewModel.canSave))
        .disabled(!viewModel.canSave)
    }
}

/// Manual ingredient entry.
struct AddIngredientView: View {
    let onAdd: (String, Double, MeasurementUnit, ProductCategory) -> Void

    @Environment(\.presentationMode) private var presentationMode
    @State private var name = ""
    @State private var quantityText = "1"
    @State private var unit: MeasurementUnit = .piece
    @State private var category: ProductCategory = .other

    private var quantity: Double? {
        Double(quantityText.replacingOccurrences(of: ",", with: "."))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: HarborMetrics.spacingM) {
                HarborCard {
                    VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                        FormRow(label: "Ingredient", isRequired: true) {
                            HarborTextField(placeholder: "Cod fillet", text: $name)
                        }
                        HStack(alignment: .top, spacing: HarborMetrics.spacingM) {
                            FormRow(label: "Quantity", isRequired: true) {
                                HarborTextField(
                                    placeholder: "1",
                                    text: $quantityText,
                                    keyboard: .decimalPad
                                )
                            }
                            FormRow(label: "Unit") {
                                HarborMenuPicker(
                                    items: MeasurementUnit.allCases,
                                    title: { $0.shortLabel },
                                    selection: $unit
                                )
                            }
                            .frame(width: 116)
                        }
                        FormRow(label: "Category") {
                            HarborMenuPicker(
                                items: ProductCategory.allCases,
                                title: { $0.displayName },
                                symbol: { $0.symbolName },
                                selection: $category
                            )
                        }
                    }
                }

                Button("Add Ingredient") {
                    if let quantity = quantity {
                        onAdd(name, quantity, unit, category)
                    }
                }
                .buttonStyle(
                    HarborPrimaryButtonStyle(
                        isEnabled: !name.trimmingCharacters(in: .whitespaces).isEmpty && (quantity ?? 0) > 0
                    )
                )
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || (quantity ?? 0) <= 0)
            }
            .padding(HarborMetrics.spacingL)
        }
        .harborScreenBackground()
        .navigationTitle("Add Ingredient")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { presentationMode.wrappedValue.dismiss() }
            }
        }
    }
}

/// Picks an ingredient straight out of inventory, keeping its unit.
struct InventoryIngredientPicker: View {
    let products: [Product]
    let onPick: (UUID, Double) -> Void

    @Environment(\.presentationMode) private var presentationMode
    @State private var selected: UUID?
    @State private var quantityText = "1"

    private var quantity: Double? {
        Double(quantityText.replacingOccurrences(of: ",", with: "."))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: HarborMetrics.spacingM) {
                if products.isEmpty {
                    EmptyStateView(
                        title: "Nothing in inventory",
                        message: "Add products first and they become available here with their units already set."
                    )
                } else {
                    HarborCard {
                        VStack(alignment: .leading, spacing: HarborMetrics.spacingS) {
                            SectionHeader(title: "Choose a product")
                            ForEach(products) { product in
                                Button {
                                    selected = product.id
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(product.trimmedName)
                                                .font(HarborFont.headline(15))
                                                .foregroundColor(HarborColor.textPrimary)
                                            Text("\(HarborFormat.quantity(product.quantity, product.unit)) in stock")
                                                .font(HarborFont.caption(11.5))
                                                .foregroundColor(HarborColor.textSecondary)
                                        }
                                        Spacer()
                                        Image(systemName: selected == product.id ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selected == product.id ? HarborColor.accent : HarborColor.separator)
                                    }
                                    .contentShape(Rectangle())
                                    .padding(.vertical, 3)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    HarborCard {
                        FormRow(
                            label: "Quantity needed",
                            isRequired: true,
                            hint: selected.flatMap { id in
                                products.first { $0.id == id }
                            }.map { "In \($0.unit.displayName.lowercased()), matching the product." }
                        ) {
                            HarborTextField(
                                placeholder: "1",
                                text: $quantityText,
                                keyboard: .decimalPad
                            )
                        }
                    }

                    Button("Add to Dish") {
                        if let selected = selected, let quantity = quantity {
                            onPick(selected, quantity)
                        }
                    }
                    .buttonStyle(HarborPrimaryButtonStyle(isEnabled: selected != nil && (quantity ?? 0) > 0))
                    .disabled(selected == nil || (quantity ?? 0) <= 0)
                }
            }
            .padding(HarborMetrics.spacingL)
        }
        .harborScreenBackground()
        .navigationTitle("Use from Inventory")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { presentationMode.wrappedValue.dismiss() }
            }
        }
    }
}
