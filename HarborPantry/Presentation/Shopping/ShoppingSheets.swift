//
//  ShoppingSheets.swift
//  HarborPantry
//
//  Supporting sheets: adding an item, confirming a purchase, excluding an
//  automatic row, and setting a store.
//

import SwiftUI

struct AddShoppingItemView: View {
    let currency: CurrencyOption
    let onAdd: (String, ProductCategory, Double, MeasurementUnit, String, Double?, String) -> Void

    @Environment(\.presentationMode) private var presentationMode
    @State private var name = ""
    @State private var category: ProductCategory = .other
    @State private var quantityText = "1"
    @State private var unit: MeasurementUnit = .piece
    @State private var store = ""
    @State private var priceText = ""
    @State private var shopper = ""

    private var quantity: Double? {
        Double(quantityText.replacingOccurrences(of: ",", with: "."))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: HarborMetrics.spacingM) {
                HarborCard {
                    VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                        FormRow(label: "Item", isRequired: true) {
                            HarborTextField(placeholder: "Olive oil", text: $name)
                        }
                        HStack(alignment: .top, spacing: HarborMetrics.spacingM) {
                            FormRow(label: "Quantity", isRequired: true) {
                                HarborTextField(placeholder: "1", text: $quantityText, keyboard: .decimalPad)
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

                HarborCard {
                    VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                        SectionHeader(title: "Optional")
                        FormRow(label: "Store") {
                            HarborTextField(placeholder: "Harbour market", text: $store)
                        }
                        FormRow(label: "Estimated Price (\(currency.symbol))") {
                            HarborTextField(placeholder: "0.00", text: $priceText, keyboard: .decimalPad)
                        }
                        FormRow(label: "Shopper") {
                            HarborTextField(placeholder: "Who is buying this", text: $shopper)
                        }
                    }
                }

                Button("Add to List") {
                    if let quantity = quantity {
                        onAdd(
                            name,
                            category,
                            quantity,
                            unit,
                            store,
                            Double(priceText.replacingOccurrences(of: ",", with: ".")),
                            shopper
                        )
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
        .navigationTitle("Add Item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { presentationMode.wrappedValue.dismiss() }
            }
        }
    }
}

/// Inventory only grows once the user confirms what was actually bought and
/// where it is going.
struct PurchaseConfirmationView: View {
    let item: ShoppingItem
    let zones: [StorageZone]
    let currency: CurrencyOption
    let onConfirm: (PurchaseConfirmation) -> Void

    @Environment(\.presentationMode) private var presentationMode
    @State private var quantityText: String
    @State private var unit: MeasurementUnit
    @State private var zoneId: UUID?
    @State private var useByDate: Date?
    @State private var priceText: String

    init(
        item: ShoppingItem,
        zones: [StorageZone],
        currency: CurrencyOption,
        onConfirm: @escaping (PurchaseConfirmation) -> Void
    ) {
        self.item = item
        self.zones = zones
        self.currency = currency
        self.onConfirm = onConfirm
        _quantityText = State(initialValue: item.toBuy.quantityText)
        _unit = State(initialValue: item.unit)
        _zoneId = State(initialValue: zones.first?.id)
        _priceText = State(initialValue: item.estimatedPrice.map { $0.quantityText } ?? "")
    }

    private var quantity: Double? {
        Double(quantityText.replacingOccurrences(of: ",", with: "."))
    }

    private var canConfirm: Bool {
        (quantity ?? 0) > 0 && zoneId != nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: HarborMetrics.spacingM) {
                HarborCard {
                    VStack(alignment: .leading, spacing: HarborMetrics.spacingS) {
                        Text(item.trimmedName)
                            .font(HarborFont.title(20))
                            .foregroundColor(HarborColor.textPrimary)
                        Text("Confirm what you actually bought. Only then does it join your inventory.")
                            .font(HarborFont.body(14))
                            .foregroundColor(HarborColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HarborCard {
                    VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                        HStack(alignment: .top, spacing: HarborMetrics.spacingM) {
                            FormRow(label: "Quantity Bought", isRequired: true) {
                                HarborTextField(placeholder: "1", text: $quantityText, keyboard: .decimalPad)
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

                        if zones.isEmpty {
                            Text("You have no storage zones. Add one before recording a purchase.")
                                .font(HarborFont.body(14))
                                .foregroundColor(HarborPalette.coral)
                        } else {
                            FormRow(label: "Storage Zone", isRequired: true) {
                                HarborMenuPicker(
                                    items: zones.map(\.id),
                                    title: { id in zones.first { $0.id == id }?.name ?? "Choose" },
                                    selection: Binding(
                                        get: { zoneId ?? zones[0].id },
                                        set: { zoneId = $0 }
                                    )
                                )
                            }
                        }

                        FormRow(
                            label: "Use-By Date (yours)",
                            hint: "Optional. Nothing is guessed on your behalf."
                        ) {
                            OptionalDateField(label: "Use-by date", date: $useByDate)
                        }

                        FormRow(label: "Actual Price (\(currency.symbol))") {
                            HarborTextField(placeholder: "0.00", text: $priceText, keyboard: .decimalPad)
                        }
                    }
                }

                Button("Confirm Purchase") {
                    if let quantity = quantity, let zoneId = zoneId {
                        onConfirm(
                            PurchaseConfirmation(
                                quantity: quantity,
                                unit: unit,
                                zoneId: zoneId,
                                useByDate: useByDate,
                                actualPrice: Double(priceText.replacingOccurrences(of: ",", with: "."))
                            )
                        )
                    }
                }
                .buttonStyle(HarborPrimaryButtonStyle(isEnabled: canConfirm))
                .disabled(!canConfirm)
            }
            .padding(HarborMetrics.spacingL)
        }
        .harborScreenBackground()
        .navigationTitle("Confirm Purchase")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { presentationMode.wrappedValue.dismiss() }
            }
        }
    }
}

/// Automatic rows need a reason before they leave the list.
struct ExcludeItemView: View {
    let item: ShoppingItem
    let onExclude: (String) -> Void

    @Environment(\.presentationMode) private var presentationMode
    @State private var reason = ""

    private let suggestions = [
        "Already have enough at home",
        "Swapping for something else",
        "Not cooking this after all",
        "Buying it another week"
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: HarborMetrics.spacingM) {
                HarborCard {
                    VStack(alignment: .leading, spacing: HarborMetrics.spacingS) {
                        Text("Why skip \(item.trimmedName)?")
                            .font(HarborFont.title(20))
                            .foregroundColor(HarborColor.textPrimary)
                        Text("This row came from your meal plan, so it keeps a reason rather than quietly disappearing.")
                            .font(HarborFont.body(14))
                            .foregroundColor(HarborColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HarborCard {
                    VStack(alignment: .leading, spacing: HarborMetrics.spacingS) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button {
                                reason = suggestion
                            } label: {
                                HStack {
                                    Text(suggestion)
                                        .font(HarborFont.body(14))
                                        .foregroundColor(HarborColor.textPrimary)
                                    Spacer()
                                    if reason == suggestion {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(HarborColor.accent)
                                    }
                                }
                                .contentShape(Rectangle())
                                .padding(.vertical, 5)
                            }
                            .buttonStyle(.plain)
                        }

                        FormRow(label: "Or write your own") {
                            HarborTextField(placeholder: "Reason", text: $reason)
                        }
                    }
                }

                Button("Exclude Item") { onExclude(reason) }
                    .buttonStyle(
                        HarborPrimaryButtonStyle(
                            gradient: HarborGradient.coral,
                            isEnabled: !reason.trimmingCharacters(in: .whitespaces).isEmpty
                        )
                    )
                    .disabled(reason.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(HarborMetrics.spacingL)
        }
        .harborScreenBackground()
        .navigationTitle("Exclude")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { presentationMode.wrappedValue.dismiss() }
            }
        }
    }
}

struct StoreEditView: View {
    let item: ShoppingItem
    let onSave: (String) -> Void

    @Environment(\.presentationMode) private var presentationMode
    @State private var store: String

    init(item: ShoppingItem, onSave: @escaping (String) -> Void) {
        self.item = item
        self.onSave = onSave
        _store = State(initialValue: item.store)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: HarborMetrics.spacingM) {
                HarborCard {
                    FormRow(label: "Store", hint: "Leave empty to group this under “Any Store”.") {
                        HarborTextField(placeholder: "Harbour market", text: $store)
                    }
                }
                Button("Save") { onSave(store) }
                    .buttonStyle(HarborPrimaryButtonStyle())
            }
            .padding(HarborMetrics.spacingL)
        }
        .harborScreenBackground()
        .navigationTitle(item.trimmedName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { presentationMode.wrappedValue.dismiss() }
            }
        }
    }
}
