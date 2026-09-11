//
//  SettingsViewModel.swift
//  HarborPantry
//

import SwiftUI
import Combine
import UniformTypeIdentifiers

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var settings = AppSettings()
    @Published private(set) var profile = PantryProfile()
    @Published var errorMessage: String?
    @Published var infoMessage: String?
    @Published var toast: ToastState?

    @Published var importPreview: ImportPreview?
    @Published var exportURL: ExportFile?
    /// Held aside until the user has seen the preview and approved it.
    private var pendingImportData: Data?

    @Published var deleteConfirmationText = ""
    let deleteKeyword = "DELETE"

    private let profileUseCases: ProfileUseCases
    private let settingsRepository: SettingsRepository
    private let profileRepository: ProfileRepository
    private let store: PantryStore
    private var cancellables = Set<AnyCancellable>()

    struct ExportFile: Identifiable {
        let id = UUID()
        let url: URL
    }

    convenience init(dependencies: AppDependencies) {
        self.init(
            profileUseCases: dependencies.profileUseCases,
            settingsRepository: dependencies.settingsRepository,
            profileRepository: dependencies.profileRepository,
            store: dependencies.store
        )
    }

    init(
        profileUseCases: ProfileUseCases,
        settingsRepository: SettingsRepository,
        profileRepository: ProfileRepository,
        store: PantryStore
    ) {
        self.profileUseCases = profileUseCases
        self.settingsRepository = settingsRepository
        self.profileRepository = profileRepository
        self.store = store

        store.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshot in
                self?.settings = snapshot.settings
                self?.profile = snapshot.profile
            }
            .store(in: &cancellables)

        settings = settingsRepository.settings()
        profile = profileRepository.currentProfile()
    }

    var canDeleteEverything: Bool {
        deleteConfirmationText.trimmingCharacters(in: .whitespaces).uppercased() == deleteKeyword
    }

    // MARK: - Preferences

    func setReminders(_ enabled: Bool) async {
        do {
            try await profileUseCases.setRemindersEnabled(enabled)
            let granted = settingsRepository.settings().remindersEnabled
            if enabled && !granted {
                infoMessage = "Notifications are switched off for Harbor Pantry in iOS Settings. Everything else keeps working."
            } else {
                infoMessage = nil
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setDefaultUnit(_ unit: MeasurementUnit) async {
        var updated = profile
        updated.defaultUnit = unit
        await saveProfile(updated)
    }

    func setCurrency(_ code: String) async {
        var updated = profile
        updated.currencyCode = code
        await saveProfile(updated)
    }

    private func saveProfile(_ updated: PantryProfile) async {
        do {
            try await profileRepository.save(updated)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Export / import

    func exportData() async {
        do {
            let data = try await profileUseCases.exportData()
            let name = "harbor-pantry-\(Int(Date().timeIntervalSince1970)).json"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
            try data.write(to: url, options: .atomic)
            exportURL = ExportFile(url: url)
            errorMessage = nil
        } catch {
            errorMessage = "Could not prepare the export file."
        }
    }

    /// Validates first and shows a preview — nothing is written yet.
    func stageImport(from url: URL) async {
        do {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let preview = try await profileUseCases.validateImport(data)
            pendingImportData = data
            importPreview = preview
            errorMessage = nil
        } catch {
            pendingImportData = nil
            errorMessage = error.localizedDescription
        }
    }

    func confirmImport() async {
        guard let data = pendingImportData else { return }
        do {
            try await profileUseCases.applyImport(data)
            pendingImportData = nil
            importPreview = nil
            toast = ToastState(message: "Import complete.")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancelImport() {
        pendingImportData = nil
        importPreview = nil
    }

    // MARK: - Destructive

    func clearHistory() async {
        do {
            try await profileUseCases.clearHistory()
            toast = ToastState(message: "History cleared.")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteAllData() async {
        guard canDeleteEverything else { return }
        do {
            try await profileUseCases.deleteAllData()
            deleteConfirmationText = ""
            toast = ToastState(message: "All data deleted.")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
