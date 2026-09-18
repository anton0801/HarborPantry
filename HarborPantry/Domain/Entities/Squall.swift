import Foundation

enum Squall: Error {
    case pipe
    case gone404
    case shut
    case throttle(TimeInterval)
    case garble

    var sealed: Bool {
        switch self {
        case .gone404, .shut: return true
        default: return false
        }
    }
}
