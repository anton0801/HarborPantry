//
//  PantryStore.swift
//  HarborPantry
//
//  Data layer — the single in-memory source of truth every repository reads
//  from and writes through.
//

import Foundation
import Combine

/// How the local store is doing right now. Screens render loading, populated,
/// empty, cached and error states from this.
enum StoreLoadState: Equatable {
    case idle
    case loading
    case loaded
    /// The file could not be read, but a previous snapshot is still in memory.
    case cached(reason: String)
    case failed(message: String)

    var isLoading: Bool { self == .loading }

    var cachedReason: String? {
        if case let .cached(reason) = self { return reason }
        return nil
    }

    var failureMessage: String? {
        if case let .failed(message) = self { return message }
        return nil
    }
}

@MainActor
final class PantryStore: ObservableObject {
    @Published private(set) var snapshot: PantrySnapshot
    @Published private(set) var loadState: StoreLoadState = .idle

    private let fileStore: SnapshotFileStore
    private var saveTask: Task<Void, Never>?

    init(fileStore: SnapshotFileStore = SnapshotFileStore()) {
        self.fileStore = fileStore
        self.snapshot = .empty
    }

    // MARK: - Lifecycle

    func load() async {
        loadState = .loading
        do {
            if let loaded = try await fileStore.load() {
                snapshot = loaded
            } else {
                // First launch: seed the default zones, nothing else.
                snapshot = .empty
                try await fileStore.save(snapshot)
            }
            loadState = .loaded
        } catch {
            // Keep whatever is in memory and tell the user plainly.
            loadState = .cached(
                reason: "Showing the last data held in memory. The saved file could not be read."
            )
        }
    }

    // MARK: - Mutation

    /// Applies a change in memory, republishes it, then persists.
    /// Throws if the mutation itself rejects the change.
    func mutate(_ body: (inout PantrySnapshot) throws -> Void) async throws {
        var working = snapshot
        try body(&working)
        snapshot = working
        try await persist(working)
    }

    /// Replaces the entire snapshot (import, delete-all, reset).
    func replace(with newSnapshot: PantrySnapshot) async throws {
        snapshot = newSnapshot
        try await persist(newSnapshot)
    }

    private func persist(_ snapshot: PantrySnapshot) async throws {
        do {
            try await fileStore.save(snapshot)
            if case .failed = loadState {
                loadState = .loaded
            } else if loadState.cachedReason != nil {
                loadState = .loaded
            }
        } catch {
            loadState = .failed(message: "Changes are in memory but could not be written to disk.")
            throw DomainError.persistence("Could not save your changes. Please try again.")
        }
    }

    // MARK: - Bulk data operations

    func exportData() async throws -> Data {
        do {
            return try await fileStore.encode(snapshot)
        } catch {
            throw DomainError.persistence("Could not prepare the export file.")
        }
    }

    func decodeSnapshot(from data: Data) async throws -> PantrySnapshot {
        do {
            return try await fileStore.decode(data)
        } catch {
            throw DomainError.importFailed("The file is not a valid Harbor Pantry export.")
        }
    }

    func wipe() async throws {
        try await fileStore.deleteFile()
        snapshot = .empty
        try await persist(snapshot)
    }
}
