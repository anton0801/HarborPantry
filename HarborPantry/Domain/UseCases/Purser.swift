import Foundation
import Combine

@MainActor
final class Purser: ObservableObject, PilotDelegate {

    @Published private(set) var berth: Deck = .splash
    @Published private(set) var offline = false

    private let pilot: Pilot

    init(rig: Rigging = Rigging()) {
        pilot = Pilot(rig: rig)
        pilot.helm = self
    }

    func launch() { pilot.launch() }
    func feed(_ data: [String: String]) { pilot.feed(data) }
    func pair(_ data: [String: String]) { pilot.pair(data) }
    func accept() { pilot.accept() }
    func skip() { pilot.skip() }
    func power(_ up: Bool) { pilot.power(up) }

    func show(_ deck: Deck) {
        berth = deck
    }
    func markOffline() { offline = true }
    
}
