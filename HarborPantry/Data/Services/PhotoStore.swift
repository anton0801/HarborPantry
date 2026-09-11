//
//  PhotoStore.swift
//  HarborPantry
//
//  Data layer — user-taken product photos on disk.
//

import Foundation

final class PhotoStore: PhotoStoring {
    private let directoryURL: URL

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
        directoryURL = base.appendingPathComponent("ProductPhotos", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
    }

    func save(imageData: Data) throws -> String {
        let fileName = "\(UUID().uuidString).jpg"
        let url = directoryURL.appendingPathComponent(fileName)
        do {
            try imageData.write(to: url, options: .atomic)
        } catch {
            throw DomainError.persistence("Could not save the photo.")
        }
        return fileName
    }

    func loadData(named fileName: String) -> Data? {
        let url = directoryURL.appendingPathComponent(fileName)
        return try? Data(contentsOf: url)
    }

    func delete(named fileName: String) {
        let url = directoryURL.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)
    }
}
