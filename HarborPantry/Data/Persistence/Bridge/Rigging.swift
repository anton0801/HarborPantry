import Foundation

final class Rigging {
    lazy var vault: Vault = Strongbox()
    lazy var sounder: Sounder = Beacon()
    lazy var caller: Caller = Runner()
    lazy var bell: Bell = Lantern()
}
