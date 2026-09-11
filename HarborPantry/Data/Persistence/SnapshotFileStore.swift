//
//  SnapshotFileStore.swift
//  HarborPantry
//
//  Data layer — atomic JSON persistence for the pantry snapshot.
//

import Foundation

/// Serialises all disk access off the main actor.
actor SnapshotFileStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileName: String = "pantry-store.json", directory: URL? = nil) {
        let base = directory ?? FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = base.appendingPathComponent(fileName)

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    var storeURL: URL { fileURL }

    var fileExists: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    func load() throws -> PantrySnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        guard !data.isEmpty else { return nil }
        return try decoder.decode(PantrySnapshot.self, from: data)
    }

    func save(_ snapshot: PantrySnapshot) throws {
        let data = try encoder.encode(snapshot)
        // Write to a sibling file first so a crash mid-write cannot truncate
        // the real store.
        let temporaryURL = fileURL.appendingPathExtension("tmp")
        try data.write(to: temporaryURL, options: .atomic)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: temporaryURL)
        } else {
            try FileManager.default.moveItem(at: temporaryURL, to: fileURL)
        }
    }

    func encode(_ snapshot: PantrySnapshot) throws -> Data {
        var copy = snapshot
        copy.exportedAt = Date()
        return try encoder.encode(copy)
    }

    func decode(_ data: Data) throws -> PantrySnapshot {
        try decoder.decode(PantrySnapshot.self, from: data)
    }

    func deleteFile() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
}
