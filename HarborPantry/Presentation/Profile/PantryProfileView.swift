//
//  PantryProfileView.swift
//  HarborPantry
//
//  Screen 5 — household setup. These values drive portions, filters and the
//  units offered elsewhere.
//

import SwiftUI

struct PantryProfileView: View {
    enum Mode {
        /// Reached straight after onboarding.
        case setup
        /// Reached later from More.
        case edit

        var saveTitle: String {
            switch self {
            case .setup: return "Save & Continue"
            case .edit: return "Save Changes"
            }
        }
    }

    @EnvironmentObject private var dependencies: AppDependencies
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var viewModel: PantryProfileViewModel

    let mode: Mode
    let onSaved: () -> Void

    @State private var showAddZone = false
    @State private var showDeleteConfirmation = false

    init(dependencies: AppDependencies, mode: Mode, onSaved: @escaping () -> Void) {
        self.mode = mode
        self.onSaved = onSaved
        _viewModel = StateObject(wrappedValue: PantryProfileViewModel(dependencies: dependencies))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: HarborMetrics.spacingM) {
                ScreenHeader(
                    title: "Pantry Profile",
                    subtitle: "How your household cooks and shops.",
                    illustration: .profileCreel,
                    illustrationWidth: 104
                )
                .padding(.top, HarborMetrics.spacingS)

                householdCard
                unitsCard
                zonesCard
                notesCard

                if let error = viewModel.errorMessage {
                    ErrorStateView(message: error)
                }

                actions

                if mode == .edit {
                    dangerZone
                }
            }
            .padding(.horizontal, HarborMetrics.spacingL)
            .padding(.bottom, HarborMetrics.spacingXL)
        }
        .harborScreenBackground()
        .navigationTitle("Pantry Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                if mode == .setup {
                    Button("Cancel") { onSaved() }
                } else {
                    Button("Close") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
        .sheet(isPresented: $showAddZone) {
            NavigationView {
                ZoneFormView(dependencies: dependencies, zone: nil) { showAddZone = false }
            }
            .navigationViewStyle(.stack)
            .environmentObject(dependencies)
        }
    }

    // MARK: - Cards

    private var householdCard: some View {
        HarborCard {
            VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                SectionHeader(title: "Household")

                FormRow(label: "Household Name", isRequired: true) {
                    HarborTextField(placeholder: "Harbor Kitchen", text: $viewModel.householdName)
                }

                FormRow(
                    label: "People Count",
                    isRequired: true,
                    hint: "Between \(PantryProfile.minimumPeople) and \(PantryProfile.maximumPeople). Used as the default serving size for new meals."
                ) {
                    HStack {
                        CountStepper(
                            value: $viewModel.peopleCount,
                            range: PantryProfile.minimumPeople...PantryProfile.maximumPeople,
                            label: viewModel.peopleCount == 1 ? "person" : "people"
                        )
                        Spacer()
                    }
                }

                FormRow(label: "Week Starts On") {
                    HarborMenuPicker(
                        items: Weekday.allCases,
                        title: { $0.displayName },
                        selection: $viewModel.weekStart
                    )
                }
            }
        }
    }

    private var unitsCard: some View {
        HarborCard {
            VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                SectionHeader(title: "Units & Currency")

                FormRow(label: "Default Unit", hint: "Pre-selected when you add a new product.") {
                    HarborMenuPicker(
                        items: MeasurementUnit.allCases,
                        title: { "\($0.displayName) (\($0.shortLabel))" },
                        selection: $viewModel.defaultUnit
                    )
                }

                FormRow(label: "Currency", hint: "A label for the prices you type. No conversion happens.") {
                    HarborMenuPicker(
                        items: viewModel.currencyOptions.map(\.code),
                        title: { code in
                            let option = CurrencyOption.option(for: code)
                            return "\(option.symbol) \(option.name)"
                        },
                        selection: $viewModel.currencyCode
                    )
                }
            }
        }
    }

    private var zonesCard: some View {
        HarborCard {
            VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                SectionHeader(
                    title: "Storage Zones",
                    subtitle: "Zone names must be unique.",
                    actionTitle: "Add Zone",
                    action: { showAddZone = true }
                )

                if viewModel.zones.isEmpty {
                    Text("No zones yet. Add at least one before you start adding products.")
                        .font(HarborFont.body(14))
                        .foregroundColor(HarborColor.textSecondary)
                } else {
                    ForEach(viewModel.zones) { zone in
                        HStack(spacing: HarborMetrics.spacingM) {
                            HarborStorageIcon(type: zone.type)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(HarborColor.accent)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(HarborColor.accent.opacity(0.12)))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(zone.name)
                                    .font(HarborFont.headline(15))
                                    .foregroundColor(HarborColor.textPrimary)
                                Text(zone.type.displayName)
                                    .font(HarborFont.caption(11.5))
                                    .foregroundColor(HarborColor.textSecondary)
                            }
                            Spacer()
                            if let capacity = zone.capacity {
                                StatusPill(text: "\(capacity) slots", color: HarborColor.accentSoft)
                            }
                        }
                    }
                }
            }
        }
    }

    private var notesCard: some View {
        HarborCard {
            VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                SectionHeader(title: "Dietary Notes")
                HarborTextEditor(
                    text: $viewModel.dietaryNotes,
                    placeholder: "Anything you want to remember when planning meals."
                )
                UserDataNotice(
                    text: "These notes are yours alone. Harbor Pantry stores them as written and never treats them as medical or allergy advice."
                )
            }
        }
    }

    private var actions: some View {
        VStack(spacing: HarborMetrics.spacingS) {
            Button(mode.saveTitle) {
                Task {
                    if await viewModel.save() { onSaved() }
                }
            }
            .buttonStyle(HarborPrimaryButtonStyle(isEnabled: !viewModel.isSaving))
            .disabled(viewModel.isSaving)

            if mode == .setup {
                Button("Skip for now") { onSaved() }
                    .buttonStyle(HarborSecondaryButtonStyle())
            }
        }
    }

    private var dangerZone: some View {
        HarborCard(tint: HarborPalette.coral) {
            VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                SectionHeader(
                    title: "Delete Profile",
                    subtitle: "Clears the household setup. Products, dishes and plans stay."
                )
                FormRow(label: "Type \(viewModel.deleteKeyword) to confirm") {
                    HarborTextField(
                        placeholder: viewModel.deleteKeyword,
                        text: $viewModel.deleteConfirmationText,
                        autocapitalization: .characters
                    )
                }
                Button("Delete Profile") {
                    showDeleteConfirmation = true
                }
                .buttonStyle(HarborSecondaryButtonStyle(tint: HarborPalette.coral))
                .disabled(!viewModel.canDelete)
                .opacity(viewModel.canDelete ? 1 : 0.5)
            }
        }
        .alert("Delete profile?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteProfile() }
            }
        } message: {
            Text("Your household settings will be reset. Your products, dishes and plans are not affected.")
        }
    }
}
