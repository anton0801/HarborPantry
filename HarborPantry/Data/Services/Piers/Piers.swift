import Foundation

enum Verdict {
    case open(String)
    case shut
}

protocol Vault {
    func load() -> Freight
    func save(_ freight: Freight)
    func mark(_ url: String)
    func flag()
}

protocol Sounder {
    func fetch() async -> [String: String]
}

protocol Caller {
    func send(_ body: [String: String]) async -> Verdict
}

protocol Bell {
    func ring() async -> Bool
}
