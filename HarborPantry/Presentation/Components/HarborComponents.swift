//
//  HarborComponents.swift
//  HarborPantry
//
//  Presentation layer — the shared building blocks every screen is made of.
//

import SwiftUI

// MARK: - Cards

/// The calm, light working surface the brief asks for: content stays readable
/// and decoration never sits on top of fields.
struct HarborCard<Content: View>: View {
    var padding: CGFloat = HarborMetrics.spacingL
    var tint: Color?
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: HarborMetrics.cardRadius, style: .continuous)
                    .fill(HarborColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HarborMetrics.cardRadius, style: .continuous)
                    .strokeBorder((tint ?? HarborColor.separator).opacity(tint == nil ? 1 : 0.35), lineWidth: 1)
            )
            .harborShadow(strength: 0.7)
    }
}

/// A card with a coloured leading rail, used for cards that carry a status.
struct HarborAccentCard<Content: View>: View {
    var accent: Color
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(accent)
                .frame(width: 5)
            content()
                .padding(HarborMetrics.spacingM)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(HarborColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: HarborMetrics.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: HarborMetrics.cardRadius, style: .continuous)
                .strokeBorder(HarborColor.separator, lineWidth: 1)
        )
        .harborShadow(strength: 0.6)
    }
}

// MARK: - Headers

struct SectionHeader: View {
    let title: String
    var subtitle: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(HarborFont.headline(18))
                    .foregroundColor(HarborColor.textPrimary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(HarborFont.caption())
                        .foregroundColor(HarborColor.textSecondary)
                }
            }
            Spacer(minLength: HarborMetrics.spacingS)
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .font(HarborFont.caption(13))
                    .foregroundColor(HarborColor.accent)
            }
        }
    }
}

/// Large screen title with an optional small illustration beside it.
struct ScreenHeader: View {
    let title: String
    var subtitle: String?
    var illustration: HarborIllustration?
    var illustrationWidth: CGFloat = 104

    var body: some View {
        HStack(alignment: .center, spacing: HarborMetrics.spacingM) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(HarborFont.title(26))
                    .foregroundColor(HarborColor.textPrimary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(HarborFont.body(14))
                        .foregroundColor(HarborColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let illustration = illustration {
                Spacer(minLength: HarborMetrics.spacingS)
                HarborIllustrationView(illustration: illustration)
                    .frame(width: illustrationWidth)
            }
        }
    }
}

// MARK: - Buttons

struct HarborPrimaryButtonStyle: ButtonStyle {
    var gradient: LinearGradient = HarborGradient.ocean
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(HarborFont.headline(16))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: HarborMetrics.minimumTapTarget + 6)
            .background(
                RoundedRectangle(cornerRadius: HarborMetrics.controlRadius, style: .continuous)
                    .fill(gradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: HarborMetrics.controlRadius, style: .continuous)
                            .fill(HarborGradient.gloss)
                            .padding(.bottom, 22)
                            .padding(.horizontal, 4)
                    )
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.86 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct HarborSecondaryButtonStyle: ButtonStyle {
    var tint: Color = HarborColor.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(HarborFont.headline(16))
            .foregroundColor(tint)
            .frame(maxWidth: .infinity, minHeight: HarborMetrics.minimumTapTarget + 6)
            .background(
                RoundedRectangle(cornerRadius: HarborMetrics.controlRadius, style: .continuous)
                    .fill(tint.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: HarborMetrics.controlRadius, style: .continuous)
                    .strokeBorder(tint.opacity(0.28), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// Small pill button used for inline actions inside cards.
struct HarborChipButtonStyle: ButtonStyle {
    var tint: Color = HarborColor.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(HarborFont.caption(13))
            .foregroundColor(tint)
            .padding(.horizontal, HarborMetrics.spacingM)
            .padding(.vertical, HarborMetrics.spacingS)
            .frame(minHeight: 34)
            .background(Capsule().fill(tint.opacity(0.13)))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

// MARK: - Status pills

struct StatusPill: View {
    let text: String
    var systemImage: String?
    var color: Color = HarborColor.accent
    var filled: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage = systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .bold))
            }
            Text(text)
                .font(HarborFont.caption(12))
        }
        .foregroundColor(filled ? .white : color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(filled ? color : color.opacity(0.14))
        )
    }
}

// MARK: - Chips

/// Horizontally scrolling single-select chips.
struct ChipPicker<Item: Hashable>: View {
    let items: [Item]
    let title: (Item) -> String
    var symbol: ((Item) -> String?)? = nil
    @Binding var selection: Item

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: HarborMetrics.spacingS) {
                ForEach(items, id: \.self) { item in
                    let isSelected = item == selection
                    Button {
                        selection = item
                    } label: {
                        HStack(spacing: 5) {
                            if let symbol = symbol?(item) {
                                Image(systemName: symbol)
                                    .font(.system(size: 11, weight: .bold))
                            }
                            Text(title(item))
                                .font(HarborFont.caption(13))
                        }
                        .foregroundColor(isSelected ? .white : HarborColor.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            Capsule()
                                .fill(isSelected ? AnyShapeStyle(HarborGradient.ocean) : AnyShapeStyle(HarborColor.surface))
                        )
                        .overlay(
                            Capsule().strokeBorder(
                                isSelected ? Color.clear : HarborColor.separator,
                                lineWidth: 1
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 3)
        }
    }
}

// MARK: - Empty / loading / error states

/// The empty state used across the app: one illustration, a clear explanation
/// and the single next step.
struct EmptyStateView: View {
    let title: String
    let message: String
    var illustration: HarborIllustration?
    var illustrationWidth: CGFloat = 200
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: HarborMetrics.spacingM) {
            if let illustration = illustration {
                HarborIllustrationView(illustration: illustration)
                    .frame(width: illustrationWidth)
            }
            Text(title)
                .font(HarborFont.title(20))
                .foregroundColor(HarborColor.textPrimary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(HarborFont.body(14))
                .foregroundColor(HarborColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(HarborPrimaryButtonStyle())
                    .padding(.top, HarborMetrics.spacingS)
                    .frame(maxWidth: 280)
            }
        }
        .padding(HarborMetrics.spacingL)
        .frame(maxWidth: .infinity)
    }
}

struct LoadingStateView: View {
    var message: String = "Loading your pantry…"

    var body: some View {
        VStack(spacing: HarborMetrics.spacingM) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(HarborColor.accent)
            Text(message)
                .font(HarborFont.body(14))
                .foregroundColor(HarborColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, HarborMetrics.spacingXL)
    }
}

struct ErrorStateView: View {
    let message: String
    var retryTitle: String = "Try Again"
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: HarborMetrics.spacingM) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 34))
                .foregroundColor(HarborPalette.coral)
            Text("Something went wrong")
                .font(HarborFont.headline(17))
                .foregroundColor(HarborColor.textPrimary)
            Text(message)
                .font(HarborFont.body(14))
                .foregroundColor(HarborColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let retry = retry {
                Button(retryTitle, action: retry)
                    .buttonStyle(HarborSecondaryButtonStyle())
                    .frame(maxWidth: 220)
            }
        }
        .padding(HarborMetrics.spacingL)
        .frame(maxWidth: .infinity)
    }
}

/// Shown when the screen is rendering data held in memory because the saved
/// file could not be read.
struct CachedDataBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: HarborMetrics.spacingS) {
            Image(systemName: "internaldrive")
                .foregroundColor(HarborPalette.sunGold)
            Text(message)
                .font(HarborFont.caption(12.5))
                .foregroundColor(HarborColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(HarborMetrics.spacingM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: HarborMetrics.controlRadius, style: .continuous)
                .fill(HarborPalette.sunGold.opacity(0.14))
        )
    }
}

// MARK: - Progress

/// A rounded progress bar used for shopping progress and coverage.
struct HarborProgressBar: View {
    var value: Double
    var tint: Color = HarborColor.accent
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(tint.opacity(0.16))
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, min(1, value)) * proxy.size.width)
            }
        }
        .frame(height: height)
        .accessibilityValue(Text("\(Int((max(0, min(1, value))) * 100)) percent"))
    }
}

// MARK: - Toast

/// Transient confirmation with an optional Undo action.
struct UndoToast: View {
    let message: String
    var undoTitle: String = "Undo"
    var onUndo: (() -> Void)?
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: HarborMetrics.spacingM) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(HarborPalette.leaf)
            Text(message)
                .font(HarborFont.caption(13))
                .foregroundColor(HarborColor.textPrimary)
                .lineLimit(2)
            Spacer(minLength: 4)
            if let onUndo = onUndo {
                Button(undoTitle, action: onUndo)
                    .font(HarborFont.headline(14))
                    .foregroundColor(HarborColor.accent)
            }
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(HarborColor.textSecondary)
            }
        }
        .padding(.horizontal, HarborMetrics.spacingM)
        .padding(.vertical, HarborMetrics.spacingM)
        .background(
            RoundedRectangle(cornerRadius: HarborMetrics.controlRadius, style: .continuous)
                .fill(HarborColor.surface)
        )
        .harborShadow()
        .padding(.horizontal, HarborMetrics.spacingL)
    }
}

/// Attaches a toast above the bottom edge.
struct ToastModifier: ViewModifier {
    @Binding var toast: ToastState?

    func body(content: Content) -> some View {
        content.overlay(
            Group {
                if let toast = toast {
                    VStack {
                        Spacer()
                        UndoToast(
                            message: toast.message,
                            onUndo: toast.undo,
                            onDismiss: { self.toast = nil }
                        )
                        .padding(.bottom, HarborMetrics.spacingL)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: toast?.id)
        )
    }
}

struct ToastState: Identifiable, Equatable {
    let id = UUID()
    let message: String
    var undo: (() -> Void)?

    static func == (lhs: ToastState, rhs: ToastState) -> Bool { lhs.id == rhs.id }
}

extension View {
    func harborToast(_ toast: Binding<ToastState?>) -> some View {
        modifier(ToastModifier(toast: toast))
    }
}

// MARK: - Disclaimer

/// The recurring reminder that dates and decisions belong to the user.
struct UserDataNotice: View {
    var text: String = "Dates and decisions are yours. Harbor Pantry stores what you enter and never judges whether food is safe to eat."

    var body: some View {
        HStack(alignment: .top, spacing: HarborMetrics.spacingS) {
            Image(systemName: "info.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(HarborColor.accent)
            Text(text)
                .font(HarborFont.caption(12))
                .foregroundColor(HarborColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(HarborMetrics.spacingM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: HarborMetrics.controlRadius, style: .continuous)
                .fill(HarborColor.accent.opacity(0.07))
        )
    }
}
