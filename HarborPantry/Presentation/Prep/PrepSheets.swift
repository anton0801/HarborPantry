//
//  PrepSheets.swift
//  HarborPantry
//
//  Supporting sheets for the prep timeline and leftovers.
//

import SwiftUI

struct AddPrepTaskView: View {
    let day: Date
    let dependencies: [PrepTask]
    let onAdd: (String, Date, Int, PrepTaskKind, UUID?) -> Void

    @Environment(\.presentationMode) private var presentationMode
    @State private var title = ""
    @State private var time: Date
    @State private var minutes = 15
    @State private var kind: PrepTaskKind = .prep
    @State private var dependencyId: UUID?

    init(day: Date, dependencies: [PrepTask], onAdd: @escaping (String, Date, Int, PrepTaskKind, UUID?) -> Void) {
        self.day = day
        self.dependencies = dependencies
        self.onAdd = onAdd
        let calendar = Calendar.current
        let base = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: day) ?? day
        _time = State(initialValue: base)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: HarborMetrics.spacingM) {
                HarborCard {
                    VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                        FormRow(label: "Task", isRequired: true) {
                            HarborTextField(placeholder: "Marinate the fish", text: $title)
                        }
                        FormRow(label: "Kind") {
                            HarborMenuPicker(
                                items: PrepTaskKind.allCases,
                                title: { $0.displayName },
                                symbol: { $0.symbolName },
                                selection: $kind
                            )
                        }
                        FormRow(label: "Time") {
                            DatePicker("", selection: $time, displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                        }
                        FormRow(label: "Duration") {
                            HStack {
                                CountStepper(value: $minutes, range: 1...600, label: "min")
                                Spacer()
                            }
                        }
                        if !dependencies.isEmpty {
                            FormRow(
                                label: "Runs After",
                                hint: "Optional. Changing that task will suggest a new time for this one."
                            ) {
                                HarborMenuPicker(
                                    items: [nil] + dependencies.map { Optional($0.id) },
                                    title: { id in
                                        guard let id = id else { return "No dependency" }
                                        return dependencies.first { $0.id == id }?.title ?? "Task"
                                    },
                                    selection: $dependencyId
                                )
                            }
                        }
                    }
                }

                Button("Add Task") {
                    onAdd(title, time, minutes, kind, dependencyId)
                }
                .buttonStyle(
                    HarborPrimaryButtonStyle(isEnabled: !title.trimmingCharacters(in: .whitespaces).isEmpty)
                )
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(HarborMetrics.spacingL)
        }
        .harborScreenBackground()
        .navigationTitle("Add Task")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { presentationMode.wrappedValue.dismiss() }
            }
        }
    }
}

struct RescheduleTaskView: View {
    let task: PrepTask
    let onSave: (Date) -> Void

    @Environment(\.presentationMode) private var presentationMode
    @State private var date: Date

    init(task: PrepTask, onSave: @escaping (Date) -> Void) {
        self.task = task
        self.onSave = onSave
        _date = State(initialValue: task.scheduledAt)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: HarborMetrics.spacingM) {
                HarborCard {
                    VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                        Text(task.title)
                            .font(HarborFont.title(20))
                            .foregroundColor(HarborColor.textPrimary)
                        DatePicker("New time", selection: $date, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.graphical)
                            .tint(HarborColor.accent)
                    }
                }
                Button("Reschedule") { onSave(date) }
                    .buttonStyle(HarborPrimaryButtonStyle())
            }
            .padding(HarborMetrics.spacingL)
        }
        .harborScreenBackground()
        .navigationTitle("Reschedule")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { presentationMode.wrappedValue.dismiss() }
            }
        }
    }
}

/// Asks when the meal should be ready, then works backwards from there.
struct MealTimePickerView: View {
    let dishName: String
    let day: Date
    let onPick: (Date) -> Void

    @Environment(\.presentationMode) private var presentationMode
    @State private var mealTime: Date

    init(dishName: String, day: Date, onPick: @escaping (Date) -> Void) {
        self.dishName = dishName
        self.day = day
        self.onPick = onPick
        let base = Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: day) ?? day
        _mealTime = State(initialValue: base)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: HarborMetrics.spacingM) {
                HarborCard {
                    VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                        Text(dishName)
                            .font(HarborFont.title(20))
                            .foregroundColor(HarborColor.textPrimary)
                        Text("When do you want to eat? Harbor Pantry lays out thawing, prep and cooking backwards from that time — every step stays editable.")
                            .font(HarborFont.body(14))
                            .foregroundColor(HarborColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        DatePicker("Meal time", selection: $mealTime, displayedComponents: [.hourAndMinute])
                            .labelsHidden()
                    }
                }
                Button("Build Timeline") { onPick(mealTime) }
                    .buttonStyle(HarborPrimaryButtonStyle())
            }
            .padding(HarborMetrics.spacingL)
        }
        .harborScreenBackground()
        .navigationTitle("Meal Time")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { presentationMode.wrappedValue.dismiss() }
            }
        }
    }
}

struct AddLeftoverView: View {
    let dishes: [Dish]
    let zones: [StorageZone]
    let onAdd: (String, Double, MeasurementUnit, UUID?, UUID?, String, Date?) -> Void

    @Environment(\.presentationMode) private var presentationMode
    @State private var name = ""
    @State private var quantityText = "1"
    @State private var unit: MeasurementUnit = .piece
    @State private var dishId: UUID?
    @State private var zoneId: UUID?
    @State private var note = ""
    @State private var useByDate: Date?

    private var quantity: Double? {
        Double(quantityText.replacingOccurrences(of: ",", with: "."))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: HarborMetrics.spacingM) {
                HarborCard {
                    VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                        FormRow(label: "Leftover", isRequired: true) {
                            HarborTextField(placeholder: "Baked cod", text: $name)
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
                        if !dishes.isEmpty {
                            FormRow(label: "From Dish") {
                                HarborMenuPicker(
                                    items: [nil] + dishes.map { Optional($0.id) },
                                    title: { id in
                                        guard let id = id else { return "Not linked" }
                                        return dishes.first { $0.id == id }?.trimmedName ?? "Dish"
                                    },
                                    selection: $dishId
                                )
                            }
                        }
                        if !zones.isEmpty {
                            FormRow(label: "Stored In") {
                                HarborMenuPicker(
                                    items: [nil] + zones.map { Optional($0.id) },
                                    title: { id in
                                        guard let id = id else { return "Not specified" }
                                        return zones.first { $0.id == id }?.name ?? "Zone"
                                    },
                                    selection: $zoneId
                                )
                            }
                        }
                        FormRow(
                            label: "Use-By Date (yours)",
                            hint: "Optional, and entirely your call."
                        ) {
                            OptionalDateField(label: "Use-by date", date: $useByDate)
                        }
                        FormRow(label: "Storage Note") {
                            HarborTextEditor(text: $note, minHeight: 70, placeholder: "Container, shelf, anything useful.")
                        }
                    }
                }

                Button("Save Leftover") {
                    if let quantity = quantity {
                        onAdd(name, quantity, unit, dishId, zoneId, note, useByDate)
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
        .navigationTitle("Add Leftover")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { presentationMode.wrappedValue.dismiss() }
            }
        }
    }
}
