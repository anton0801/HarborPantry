//
//  SettingsView.swift
//  HarborPantry
//
//  Screen 15c — preferences and data management. No decoration here by design.
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var viewModel: SettingsViewModel

    @State private var showImporter = false
    @State private var showClearHistoryConfirmation = false
    @State private var showDeleteAllConfirmation = false

    init(dependencies: AppDependencies) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(dependencies: dependencies))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: HarborMetrics.spacingM) {
                if let error = viewModel.errorMessage {
                    ErrorStateView(message: error)
                }
                if let info = viewModel.infoMessage {
                    CachedDataBanner(message: info)
                }

                preferencesCard
                dataCard
                dangerCard
                aboutCard
            }
            .padding(.horizontal, HarborMetrics.spacingL)
            .padding(.vertical, HarborMetrics.spacingM)
        }
        .harborScreenBackground()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .harborToast($viewModel.toast)
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                if let url = urls.first {
                    Task { await viewModel.stageImport(from: url) }
                }
            case let .failure(error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
        .sheet(item: $viewModel.exportURL) { file in
            ShareSheet(items: [file.url])
        }
        .sheet(item: $viewModel.importPreview) { preview in
            NavigationView {
                ImportPreviewView(preview: preview) {
                    Task { await viewModel.confirmImport() }
                } onCancel: {
                    viewModel.cancelImport()
                }
            }
            .navigationViewStyle(.stack)
        }
        .alert("Clear history?", isPresented: $showClearHistoryConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                Task { await viewModel.clearHistory() }
            }
        } message: {
            Text("Every recorded action is removed. Products, dishes and plans stay, but Insights will start over.")
        }
        .alert("Delete all data?", isPresented: $showDeleteAllConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Everything", role: .destructive) {
                Task { await viewModel.deleteAllData() }
            }
        } message: {
            Text("Products, zones, dishes, plans, shopping rows, prep tasks, leftovers, history and photos are permanently removed from this device.")
        }
    }

    private var preferencesCard: some View {
        HarborCard {
            VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                SectionHeader(title: "Preferences")

                Toggle(isOn: Binding(
                    get: { viewModel.settings.remindersEnabled },
                    set: { newValue in Task { await viewModel.setReminders(newValue) } }
                )) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Reminders")
                            .font(HarborFont.body(15))
                            .foregroundColor(HarborColor.textPrimary)
                        Text("Local notifications for dates and tasks you set.")
                            .font(HarborFont.caption(11.5))
                            .foregroundColor(HarborColor.textSecondary)
                    }
                }
                .tint(HarborColor.accent)

                FormRow(label: "Default Unit") {
                    HarborMenuPicker(
                        items: MeasurementUnit.allCases,
                        title: { "\($0.displayName) (\($0.shortLabel))" },
                        selection: Binding(
                            get: { viewModel.profile.defaultUnit },
                            set: { newValue in Task { await viewModel.setDefaultUnit(newValue) } }
                        )
                    )
                }

                FormRow(label: "Currency") {
                    HarborMenuPicker(
                        items: CurrencyOption.all.map(\.code),
                        title: { code in
                            let option = CurrencyOption.option(for: code)
                            return "\(option.symbol) \(option.name)"
                        },
                        selection: Binding(
                            get: { viewModel.profile.currencyCode },
                            set: { newValue in Task { await viewModel.setCurrency(newValue) } }
                        )
                    )
                }
            }
        }
    }

    private var dataCard: some View {
        HarborCard {
            VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                SectionHeader(
                    title: "Your Data",
                    subtitle: "Everything stays on this device unless you export it."
                )

                Button("Export Everything") {
                    Task { await viewModel.exportData() }
                }
                .buttonStyle(HarborSecondaryButtonStyle())

                Button("Import from File") {
                    showImporter = true
                }
                .buttonStyle(HarborSecondaryButtonStyle())

                Text("An import always shows a preview with any problems it found before a single record is written.")
                    .font(HarborFont.caption(11.5))
                    .foregroundColor(HarborColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var dangerCard: some View {
        HarborCard(tint: HarborPalette.coral) {
            VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                SectionHeader(title: "Danger Zone")

                Button("Clear History") {
                    showClearHistoryConfirmation = true
                }
                .buttonStyle(HarborSecondaryButtonStyle(tint: HarborPalette.sunGold))

                FormRow(label: "Type \(viewModel.deleteKeyword) to delete everything") {
                    HarborTextField(
                        placeholder: viewModel.deleteKeyword,
                        text: $viewModel.deleteConfirmationText,
                        autocapitalization: .characters
                    )
                }

                Button("Delete All Data") {
                    showDeleteAllConfirmation = true
                }
                .buttonStyle(HarborSecondaryButtonStyle(tint: HarborPalette.coral))
                .disabled(!viewModel.canDeleteEverything)
                .opacity(viewModel.canDeleteEverything ? 1 : 0.5)
            }
        }
    }

    private var aboutCard: some View {
        HarborCard {
            VStack(alignment: .leading, spacing: HarborMetrics.spacingS) {
                SectionHeader(title: "About")
                Text("Harbor Pantry keeps track of the food you already have, the meals you plan and the shopping that follows from them.")
                    .font(HarborFont.body(14))
                    .foregroundColor(HarborColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                UserDataNotice(
                    text: "Harbor Pantry does not judge food safety and does not replace manufacturer guidance. Every date and every decision is yours."
                )
            }
        }
    }
}

/// Shows what an import file contains, and anything wrong with it, before the
/// user commits.
struct ImportPreviewView: View {
    let preview: ImportPreview
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: HarborMetrics.spacingM) {
                HarborCard {
                    VStack(alignment: .leading, spacing: HarborMetrics.spacingS) {
                        Text("Import preview")
                            .font(HarborFont.title(20))
                            .foregroundColor(HarborColor.textPrimary)
                        Text("\(preview.totalRecords) record\(preview.totalRecords == 1 ? "" : "s") found. Nothing has been written yet.")
                            .font(HarborFont.body(14))
                            .foregroundColor(HarborColor.textSecondary)
                        if let exportedAt = preview.exportedAt {
                            Text("Exported \(HarborFormat.dateTime.string(from: exportedAt))")
                                .font(HarborFont.caption(11.5))
                                .foregroundColor(HarborColor.textSecondary)
                        }
                    }
                }

                HarborCard {
                    VStack(alignment: .leading, spacing: HarborMetrics.spacingS) {
                        SectionHeader(title: "Contents")
                        countRow("Products", preview.counts.products)
                        countRow("Storage zones", preview.counts.zones)
                        countRow("Dishes", preview.counts.dishes)
                        countRow("Planned meals", preview.counts.mealEntries)
                        countRow("Shopping items", preview.counts.shoppingItems)
                        countRow("Prep tasks", preview.counts.prepTasks)
                        countRow("Leftovers", preview.counts.leftovers)
                        countRow("History entries", preview.counts.historyEntries)
                    }
                }

                if !preview.issues.isEmpty {
                    HarborCard(tint: HarborPalette.coral) {
                        VStack(alignment: .leading, spacing: HarborMetrics.spacingS) {
                            SectionHeader(
                                title: "Problems found",
                                subtitle: "These have to be fixed in the file before it can be imported."
                            )
                            ForEach(preview.issues, id: \.self) { issue in
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(HarborPalette.coral)
                                    Text(issue)
                                        .font(HarborFont.caption(12))
                                        .foregroundColor(HarborColor.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }

                Button("Replace My Data") { onConfirm() }
                    .buttonStyle(HarborPrimaryButtonStyle(isEnabled: preview.isValid))
                    .disabled(!preview.isValid)

                Button("Cancel") { onCancel() }
                    .buttonStyle(HarborSecondaryButtonStyle())

                Text("Importing replaces what is currently on this device. Export first if you want a copy.")
                    .font(HarborFont.caption(11))
                    .foregroundColor(HarborColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(HarborMetrics.spacingL)
        }
        .harborScreenBackground()
        .navigationTitle("Import")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func countRow(_ label: String, _ value: Int) -> some View {
        HStack {
            Text(label)
                .font(HarborFont.body(14))
                .foregroundColor(HarborColor.textSecondary)
            Spacer()
            Text("\(value)")
                .font(HarborFont.numeric(15))
                .foregroundColor(HarborColor.textPrimary)
        }
    }
}

extension ImportPreview: Identifiable {
    public var id: String { "\(totalRecords)-\(issues.count)-\(schemaVersion)" }
}

/// Wraps `UIActivityViewController` for exporting the data file.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
