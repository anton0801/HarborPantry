import Foundation

struct Freight: Codable {
    var raw: [String: String] = [:]
    var links: [String: String] = [:]
    var route: String?
    var mode: String?
    var fresh = true
    var organicSwept = false
    var consentGrant = false
    var consentDeny = false
    var consentAt: Date?
}

extension Freight {
    var hasData: Bool { !raw.isEmpty }

    var isOrganic: Bool {
        (raw["af_status"] ?? "").caseInsensitiveCompare("Organic") == .orderedSame
    }

    var needsOrganic: Bool { isOrganic && fresh && !organicSwept }

    var consentRipe: Bool {
        if consentGrant || consentDeny { return false }
        guard let at = consentAt else { return true }
        return Date().timeIntervalSince(at) / 86_400 >= 3
    }
}
