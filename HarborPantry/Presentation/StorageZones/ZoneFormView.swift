//
//  ZoneFormView.swift
//  HarborPantry
//
//  Add or rename a storage zone. Names have to stay unique.
//

import SwiftUI

struct ZoneFormView: View {
    @Environment(\.presentationMode) private var presentationMode

    private let dependencies: AppDependencies
    private let zone: StorageZone?
    private let onFinished: () -> Void

    @State private var name: String
    @State private var type: StorageZoneType
    @State private var capacityText: String
    @State private var note: String
    @State private var errorMessage: String?
    @State private var isSaving = false

    init(dependencies: AppDependencies, zone: StorageZone?, onFinished: @escaping () -> Void) {
        self.dependencies = dependencies
        self.zone = zone
        self.onFinished = onFinished
        _name = State(initialValue: zone?.name ?? "")
        _type = State(initialValue: zone?.type ?? .custom)
        _capacityText = State(initialValue: zone?.capacity.map(String.init) ?? "")
        _note = State(initialValue: zone?.note ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: HarborMetrics.spacingM) {
                HarborCard {
                    VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                        FormRow(label: "Zone Name", isRequired: true) {
                            HarborTextField(placeholder: "Top shelf", text: $name)
                        }

                        FormRow(label: "Type") {
                            HarborMenuPicker(
                                items: StorageZoneType.allCases,
                                title: { $0.displayName },
                                symbol: { $0.symbolName },
                                selection: $type
                            )
                        }

                        FormRow(
                            label: "Capacity",
                            hint: "Optional. A number of slots you find useful — it is never enforced."
                        ) {
                            HarborTextField(
                                placeholder: "Optional",
                                text: $capacityText,
                                keyboard: .numberPad
                            )
                        }

                        FormRow(label: "Note") {
                            HarborTextEditor(text: $note, minHeight: 74, placeholder: "Anything worth remembering.")
                        }
                    }
                }

                if let errorMessage = errorMessage {
                    ErrorStateView(message: errorMessage)
                }

                Button(zone == nil ? "Add Zone" : "Save Changes") {
                    save()
                }
                .buttonStyle(HarborPrimaryButtonStyle(isEnabled: !isSaving && !name.trimmingCharacters(in: .whitespaces).isEmpty))
                .disabled(isSaving || name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(HarborMetrics.spacingL)
        }
        .harborScreenBackground()
        .navigationTitle(zone == nil ? "New Zone" : "Edit Zone")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    onFinished()
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }

    private func save() {
        isSaving = true
        Task {
            do {
                if let zone = zone {
                    try await dependencies.profileUseCases.updateZone(
                        zone,
                        name: name,
                        type: type,
                        capacityText: capacityText,
                        note: note
                    )
                } else {
                    try await dependencies.profileUseCases.addZone(
                        name: name,
                        type: type,
                        capacityText: capacityText,
                        note: note
                    )
                }
                errorMessage = nil
                onFinished()
                presentationMode.wrappedValue.dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}
