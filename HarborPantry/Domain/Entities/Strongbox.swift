import Foundation

final class Strongbox: Vault {

    private var home: UserDefaults { .standard }
    private var box: UserDefaults? { UserDefaults(suiteName: Almanac.suite) }

    private var file: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent(Almanac.folder, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(Almanac.vault)
    }

    private var dec: JSONDecoder {
        let d = JSONDecoder(); d.dateDecodingStrategy = .millisecondsSince1970; return d
    }
    private var enc: JSONEncoder {
        let e = JSONEncoder(); e.dateEncodingStrategy = .millisecondsSince1970; return e
    }

    func load() -> Freight {
        if let blob = try? Data(contentsOf: file), let clear = unlock(blob), let freight = try? dec.decode(Freight.self, from: clear) {
            return freight
        }
        return recall()
    }

    func save(_ freight: Freight) {
        if let clear = try? enc.encode(freight), let blob = lock(clear) {
            try? blob.write(to: file, options: .atomic)
        }
        for store in [box, home].compactMap({ $0 }) {
            store.set(freight.consentGrant, forKey: Slips.grant)
            store.set(freight.consentDeny, forKey: Slips.deny)
            if let at = freight.consentAt { store.set(at.timeIntervalSince1970, forKey: Slips.stamp) }
        }
    }

    func mark(_ url: String) {
        home.set(url, forKey: Slips.route)
        box?.set("Active", forKey: Slips.mode)
    }

    func flag() {
        home.set(true, forKey: Slips.primed)
        box?.set(true, forKey: Slips.primed)
    }

    private func recall() -> Freight {
        var freight = Freight()
        freight.consentGrant = (box?.bool(forKey: Slips.grant) ?? false) || home.bool(forKey: Slips.grant)
        freight.consentDeny = (box?.bool(forKey: Slips.deny) ?? false) || home.bool(forKey: Slips.deny)
        let ts = box?.double(forKey: Slips.stamp) ?? home.double(forKey: Slips.stamp)
        freight.consentAt = ts > 0 ? Date(timeIntervalSince1970: ts) : nil
        freight.route = home.string(forKey: Slips.route)
        freight.mode = box?.string(forKey: Slips.mode)
        freight.fresh = !home.bool(forKey: Slips.primed)
        return freight
    }

    private func lock(_ data: Data) -> Data? {
        Data(data.reversed().map { $0 ^ Almanac.pad }).base64EncodedData()
    }

    private func unlock(_ data: Data) -> Data? {
        guard let raw = Data(base64Encoded: data) else { return nil }
        return Data(raw.map { $0 ^ Almanac.pad }.reversed())
    }
}
