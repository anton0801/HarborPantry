//
//  HarborShapes.swift
//  HarborPantry
//
//  Presentation layer — the vector primitives the harbour illustrations are
//  built from. Everything is drawn in a unit box and scaled by the caller.
//

import SwiftUI

/// How an illustration should occupy the space it is given.
///
/// Most screens want `.fit` so the art sits inside its slot; the onboarding
/// backdrops want `.fill` so no edge of the screen is left bare.
private struct HarborArtContentModeKey: EnvironmentKey {
    static let defaultValue: ContentMode = .fit
}

extension EnvironmentValues {
    var harborArtContentMode: ContentMode {
        get { self[HarborArtContentModeKey.self] }
        set { self[HarborArtContentModeKey.self] = newValue }
    }
}

/// Draws illustration content inside a fixed-aspect box and hands the resolved
/// size to the builder, so every element can be positioned proportionally.
struct ArtBox<Content: View>: View {
    @Environment(\.harborArtContentMode) private var contentMode

    let aspect: CGFloat
    let content: (CGSize) -> Content

    init(aspect: CGFloat, @ViewBuilder content: @escaping (CGSize) -> Content) {
        self.aspect = aspect
        self.content = content
    }

    var body: some View {
        Color.clear
            .aspectRatio(aspect, contentMode: contentMode)
            .overlay(
                GeometryReader { proxy in
                    content(proxy.size)
                }
            )
    }
}

// MARK: - Fish

/// A friendly cartoon fish: rounded body plus a fan tail.
struct FishShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.addEllipse(
            in: CGRect(x: rect.minX, y: rect.minY + h * 0.18, width: w * 0.74, height: h * 0.64)
        )

        var tail = Path()
        tail.move(to: CGPoint(x: rect.minX + w * 0.62, y: rect.minY + h * 0.5))
        tail.addQuadCurve(
            to: CGPoint(x: rect.minX + w, y: rect.minY + h * 0.12),
            control: CGPoint(x: rect.minX + w * 0.84, y: rect.minY + h * 0.26)
        )
        tail.addQuadCurve(
            to: CGPoint(x: rect.minX + w, y: rect.minY + h * 0.88),
            control: CGPoint(x: rect.minX + w * 0.88, y: rect.minY + h * 0.5)
        )
        tail.addQuadCurve(
            to: CGPoint(x: rect.minX + w * 0.62, y: rect.minY + h * 0.5),
            control: CGPoint(x: rect.minX + w * 0.84, y: rect.minY + h * 0.74)
        )
        path.addPath(tail)

        return path
    }
}

/// The dorsal fin that sits on top of the fish body.
struct FinShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

/// A complete fish with gloss, fin and eye.
struct HarborFish: View {
    var bodyGradient: LinearGradient = HarborGradient.ocean
    var size: CGSize
    var flipped: Bool = false

    var body: some View {
        ZStack {
            FishShape()
                .fill(bodyGradient)

            // Glossy highlight along the top of the body.
            Ellipse()
                .fill(HarborGradient.gloss)
                .frame(width: size.width * 0.36, height: size.height * 0.2)
                .offset(x: -size.width * 0.14, y: -size.height * 0.16)

            FinShape()
                .fill(Color.white.opacity(0.45))
                .frame(width: size.width * 0.26, height: size.height * 0.2)
                .offset(x: -size.width * 0.04, y: -size.height * 0.28)

            Circle()
                .fill(Color.white)
                .frame(width: size.height * 0.16, height: size.height * 0.16)
                .overlay(
                    Circle()
                        .fill(HarborPalette.ink)
                        .frame(width: size.height * 0.08, height: size.height * 0.08)
                        .offset(x: -size.height * 0.01)
                )
                .offset(x: -size.width * 0.2, y: -size.height * 0.06)
        }
        .frame(width: size.width, height: size.height)
        .scaleEffect(x: flipped ? -1 : 1, y: 1)
    }
}

// MARK: - Water

/// A sine-wave band used for water surfaces and decorative arcs.
struct WaveShape: Shape {
    var amplitude: CGFloat
    var wavelength: CGFloat
    var phase: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        var x = rect.minX
        while x <= rect.maxX {
            let relative = (x - rect.minX) / max(wavelength, 1)
            let y = rect.midY + sin(relative * .pi * 2 + phase) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
            x += 1
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Sunlight shafts falling through water.
struct SunRays: View {
    var size: CGSize
    var tint: Color = .white

    var body: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                let width = size.width * (index.isMultiple(of: 2) ? 0.12 : 0.07)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.34), tint.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: width, height: size.height * 0.85)
                    .rotationEffect(.degrees(Double(index) * 7 - 14))
                    .offset(x: size.width * (CGFloat(index) * 0.2 - 0.36))
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .blur(radius: 6)
    }
}

/// Scattered bubbles. Positions are deterministic so the art never flickers.
struct BubbleCluster: View {
    var size: CGSize
    var count: Int = 9
    var tint: Color = .white

    private let seeds: [(CGFloat, CGFloat, CGFloat)] = [
        (0.08, 0.22, 0.9), (0.19, 0.62, 0.55), (0.31, 0.12, 0.7),
        (0.44, 0.78, 1.0), (0.57, 0.34, 0.5), (0.68, 0.66, 0.8),
        (0.79, 0.18, 0.6), (0.88, 0.52, 1.1), (0.95, 0.82, 0.45),
        (0.14, 0.88, 0.65), (0.62, 0.06, 0.5), (0.36, 0.46, 0.35)
    ]

    var body: some View {
        ZStack {
            ForEach(0..<min(count, seeds.count), id: \.self) { index in
                let seed = seeds[index]
                let diameter = size.width * 0.05 * seed.2
                Circle()
                    .strokeBorder(tint.opacity(0.5), lineWidth: max(1, diameter * 0.12))
                    .background(Circle().fill(tint.opacity(0.14)))
                    .frame(width: diameter, height: diameter)
                    .position(x: size.width * seed.0, y: size.height * seed.1)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - Objects

/// A glossy wooden crate — the recurring container motif.
struct CrateShape: View {
    var size: CGSize

    private var wood: LinearGradient {
        LinearGradient(
            colors: [Color(hex: 0xD79A5B), Color(hex: 0xA96B33)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size.height * 0.12, style: .continuous)
                .fill(wood)

            VStack(spacing: size.height * 0.11) {
                ForEach(0..<3, id: \.self) { _ in
                    Capsule()
                        .fill(Color.black.opacity(0.10))
                        .frame(height: max(1.5, size.height * 0.035))
                }
            }
            .padding(.horizontal, size.width * 0.08)
            .padding(.vertical, size.height * 0.16)

            RoundedRectangle(cornerRadius: size.height * 0.12, style: .continuous)
                .fill(HarborGradient.gloss)
                .padding(.bottom, size.height * 0.55)
                .padding(.horizontal, size.width * 0.05)
        }
        .frame(width: size.width, height: size.height)
    }
}

/// A stylised lemon / round fruit with a highlight.
struct RoundFruit: View {
    var diameter: CGFloat
    var gradient: LinearGradient

    var body: some View {
        Circle()
            .fill(gradient)
            .overlay(
                Ellipse()
                    .fill(Color.white.opacity(0.45))
                    .frame(width: diameter * 0.38, height: diameter * 0.24)
                    .offset(x: -diameter * 0.13, y: -diameter * 0.2)
            )
            .frame(width: diameter, height: diameter)
    }
}

/// Leafy greens poking out of a crate or basket.
struct GreensSprig: View {
    var size: CGSize

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Ellipse()
                    .fill(HarborGradient.leaf)
                    .frame(width: size.width * 0.42, height: size.height)
                    .rotationEffect(.degrees(Double(index - 1) * 26))
                    .offset(x: size.width * CGFloat(index - 1) * 0.16)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

/// A simple bottle silhouette for oils and sauces.
struct BottleShape: View {
    var size: CGSize
    var tint: Color = HarborPalette.leaf

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(tint.opacity(0.85))
                .frame(width: size.width * 0.3, height: size.height * 0.3)
            RoundedRectangle(cornerRadius: size.width * 0.22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.95), tint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size.width, height: size.height * 0.7)
                .overlay(
                    Capsule()
                        .fill(Color.white.opacity(0.4))
                        .frame(width: size.width * 0.16, height: size.height * 0.4)
                        .offset(x: -size.width * 0.24)
                )
        }
        .frame(width: size.width, height: size.height)
    }
}
