import SwiftUI

/// Decorative storage art. Zone selection and all storage behavior remain
/// owned by the existing views and view models.
struct HarborStorageIcon: View {
    let type: StorageZoneType
    var size: CGFloat = 24

    private var illustration: HarborIllustration {
        switch type {
        case .refrigerator: return .zoneRefrigerator
        case .freezer: return .zoneFreezer
        case .pantry: return .zonePantry
        case .custom: return .zoneCustom
        }
    }

    var body: some View {
        HarborIllustrationView(illustration: illustration)
            .frame(width: size, height: size)
    }
}
