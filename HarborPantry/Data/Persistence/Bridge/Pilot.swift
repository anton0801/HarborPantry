import Foundation

enum Deck: Equatable {
    case splash
    case consent
    case web
    case main
}

protocol PilotDelegate: AnyObject {
    func show(_ deck: Deck)
    func markOffline()
}

@MainActor
final class Pilot {

    weak var helm: PilotDelegate?

    private let rig: Rigging
    private var freight = Freight()
    private var sealed = false
    private var busy = false
    private var loaded = false
    private var clock: Task<Void, Never>?

    init(rig: Rigging) {
        self.rig = rig
    }

    func launch() {
        hydrate()
        clock = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            self?.strand()
        }
        pump()
    }

    func feed(_ pour: [String: String]) {
        hydrate()
        freight.raw.merge(pour) { _, fresh in fresh }
        rig.vault.save(freight)
        pump()
    }

    func pair(_ pour: [String: String]) {
        hydrate()
        for (key, value) in pour where freight.links[key] == nil { freight.links[key] = value }
        rig.vault.save(freight)
    }

    func accept() {
        hydrate()
        Task { [weak self] in
            guard let self = self else { return }
            let granted = await self.rig.bell.ring()
            self.freight.consentGrant = granted
            self.freight.consentDeny = !granted
            self.freight.consentAt = Date()
            self.rig.vault.save(self.freight)
            self.helm?.show(.web)
        }
    }

    func skip() {
        hydrate()
        freight.consentAt = Date()
        rig.vault.save(freight)
        helm?.show(.web)
    }

    func power(_ up: Bool) {
        if !up { helm?.markOffline() }
    }

    private func pump() {
        guard !sealed, !busy else { return }

        if let push = pending, push.isEmpty == false {
            anchor(push)
            return
        }
        guard freight.hasData else { return }

        busy = true
        Task { [weak self] in
            guard let self = self else { return }

            if self.freight.needsOrganic {
                self.freight.organicSwept = true
                self.rig.vault.save(self.freight)
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                let fresh = await self.rig.sounder.fetch()
                if fresh.isEmpty == false {
                    var pooled = fresh
                    for (key, value) in self.freight.links where pooled[key] == nil { pooled[key] = value }
                    self.freight.raw = pooled
                    self.rig.vault.save(self.freight)
                }
            }

            let verdict = await self.rig.caller.send(self.freight.raw)
            self.busy = false
            switch verdict {
            case .open(let url): self.anchor(url)
            case .shut:
                if let saved = UserDefaults.standard.string(forKey: Slips.route), saved.isEmpty == false {
                    self.anchor(saved)
                } else if let saved = self.freight.route, saved.isEmpty == false {
                    UserDefaults.standard.set(saved, forKey: Slips.route)
                    self.anchor(saved)
                } else {
                    self.strand()
                }
            }
        }
    }

    private func anchor(_ url: String) {
        guard latch() else { return }
        let ripe = freight.consentRipe
        freight.route = url
        freight.mode = "Active"
        freight.fresh = false
        rig.vault.save(freight)
        rig.vault.mark(url)
        rig.vault.flag()
        UserDefaults.standard.removeObject(forKey: Slips.pushURL)
        helm?.show(ripe ? .consent : .web)
    }

    private func strand() {
        guard latch() else { return }
        helm?.show(.main)
    }

    private func latch() -> Bool {
        guard !sealed else { return false }
        sealed = true
        clock?.cancel()
        return true
    }

    private func hydrate() {
        guard !loaded else { return }
        loaded = true
        freight = rig.vault.load()
    }

    private var pending: String? {
        let value = UserDefaults.standard.string(forKey: Slips.pushURL) ?? ""
        return value.isEmpty ? nil : value
    }
}
