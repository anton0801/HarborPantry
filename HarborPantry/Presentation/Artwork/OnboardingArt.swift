//
//  OnboardingArt.swift
//  HarborPantry
//
//  Presentation layer — the three full-bleed onboarding backdrops.
//
//  Each keeps its lower third calm so the text panel above it stays readable,
//  and none of them contains baked-in text.
//

import SwiftUI

/// Shared water backdrop: gradient, light shafts and a soft surface line.
private struct OceanBackdrop: View {
    var size: CGSize
    var topColor: Color = HarborPalette.aqua
    var bottomColor: Color = HarborPalette.deepSea

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [topColor, HarborPalette.oceanBlue, bottomColor],
                startPoint: .top,
                endPoint: .bottom
            )

            SunRays(size: CGSize(width: size.width, height: size.height * 0.62))
                .frame(width: size.width, height: size.height * 0.62)
                .position(x: size.width * 0.5, y: size.height * 0.31)

            WaveShape(amplitude: size.height * 0.012, wavelength: size.width * 0.8, phase: 0.4)
                .fill(Color.white.opacity(0.12))
                .frame(width: size.width, height: size.height * 0.12)
                .position(x: size.width * 0.5, y: size.height * 0.14)
        }
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - BAS_01 · Inventory

struct OnboardingInventoryArt: View {
    var body: some View {
        ArtBox(aspect: HarborIllustration.onboardingInventory.aspect) { s in
            ZStack {
                OceanBackdrop(size: s)

                BubbleCluster(size: CGSize(width: s.width, height: s.height * 0.6), count: 8)
                    .position(x: s.width * 0.5, y: s.height * 0.3)

                // Glossy fish framing the upper half
                HarborFish(
                    bodyGradient: HarborGradient.sun,
                    size: CGSize(width: s.width * 0.46, height: s.height * 0.1)
                )
                .rotationEffect(.degrees(-10))
                .position(x: s.width * 0.24, y: s.height * 0.2)

                HarborFish(
                    bodyGradient: LinearGradient(
                        colors: [Color(hex: 0x9BF1FA), HarborPalette.aqua],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    size: CGSize(width: s.width * 0.38, height: s.height * 0.085),
                    flipped: true
                )
                .rotationEffect(.degrees(12))
                .position(x: s.width * 0.8, y: s.height * 0.35)

                // Floating blank cards: a fridge and a basket, no labels
                floatingCard(size: CGSize(width: s.width * 0.3, height: s.height * 0.14)) {
                    StorageCabinetArt()
                        .padding(s.width * 0.02)
                }
                .rotationEffect(.degrees(-7))
                .position(x: s.width * 0.26, y: s.height * 0.44)

                floatingCard(size: CGSize(width: s.width * 0.28, height: s.height * 0.13)) {
                    ShoppingBasketArt()
                        .padding(s.width * 0.02)
                }
                .rotationEffect(.degrees(8))
                .position(x: s.width * 0.74, y: s.height * 0.55)

                // Calm band for the text panel
                LinearGradient(
                    colors: [.clear, HarborPalette.deepSea.opacity(0.45)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: s.height * 0.4)
                .position(x: s.width * 0.5, y: s.height * 0.8)
            }
            .frame(width: s.width, height: s.height)
            .clipped()
        }
    }

    private func floatingCard<Content: View>(
        size: CGSize,
        @ViewBuilder content: () -> Content
    ) -> some View {
        RoundedRectangle(cornerRadius: size.height * 0.24, style: .continuous)
            .fill(Color.white.opacity(0.92))
            .frame(width: size.width, height: size.height)
            .overlay(content())
            .harborShadow()
    }
}

// MARK: - BAS_02 · Meals

struct OnboardingMealsArt: View {
    var body: some View {
        ArtBox(aspect: HarborIllustration.onboardingMeals.aspect) { s in
            ZStack {
                OceanBackdrop(
                    size: s,
                    topColor: Color(hex: 0x7FE6F2),
                    bottomColor: HarborPalette.deepSea
                )

                // Distant keeper on the pier — small, and clearly our own
                // character rather than anyone else's.
                FishermanArt()
                    .frame(width: s.width * 0.3)
                    .opacity(0.9)
                    .position(x: s.width * 0.76, y: s.height * 0.31)

                // Pier decking
                deck(size: CGSize(width: s.width * 1.1, height: s.height * 0.16))
                    .position(x: s.width * 0.5, y: s.height * 0.47)

                // Crates of produce on the deck
                ProductCrateArt()
                    .frame(width: s.width * 0.42)
                    .position(x: s.width * 0.27, y: s.height * 0.37)

                CrateShape(size: CGSize(width: s.width * 0.2, height: s.height * 0.06))
                    .position(x: s.width * 0.62, y: s.height * 0.43)

                // The finished plate
                MealPlateArt()
                    .frame(width: s.width * 0.44)
                    .position(x: s.width * 0.6, y: s.height * 0.6)

                HarborFish(
                    bodyGradient: HarborGradient.ocean,
                    size: CGSize(width: s.width * 0.3, height: s.height * 0.07)
                )
                .position(x: s.width * 0.2, y: s.height * 0.62)

                LinearGradient(
                    colors: [.clear, HarborPalette.deepSea.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: s.height * 0.38)
                .position(x: s.width * 0.5, y: s.height * 0.81)
            }
            .frame(width: s.width, height: s.height)
            .clipped()
        }
    }

    private func deck(size: CGSize) -> some View {
        VStack(spacing: max(1, size.height * 0.06)) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: size.height * 0.08, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0xD9A468), Color(hex: 0xB07C42)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: size.height * 0.28)
            }
        }
        .frame(width: size.width, height: size.height)
        .harborShadow()
    }
}

// MARK: - BAS_03 · Shopping

struct OnboardingShoppingArt: View {
    var body: some View {
        ArtBox(aspect: HarborIllustration.onboardingShopping.aspect) { s in
            ZStack {
                OceanBackdrop(
                    size: s,
                    topColor: Color(hex: 0x8DEBF5),
                    bottomColor: HarborPalette.deepSea
                )

                // Decorative water arch framing the shop
                Circle()
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: s.width * 0.05)
                    .frame(width: s.width * 0.86, height: s.width * 0.86)
                    .position(x: s.width * 0.5, y: s.height * 0.36)

                BubbleCluster(size: CGSize(width: s.width, height: s.height * 0.55), count: 10)
                    .position(x: s.width * 0.5, y: s.height * 0.3)

                ShoppingBasketArt()
                    .frame(width: s.width * 0.52)
                    .position(x: s.width * 0.42, y: s.height * 0.38)

                // Blank checklist card — the rows are drawn as empty bars so no
                // text is ever baked into the artwork.
                checklistCard(size: CGSize(width: s.width * 0.3, height: s.height * 0.16))
                    .rotationEffect(.degrees(6))
                    .position(x: s.width * 0.76, y: s.height * 0.5)

                HarborFish(
                    bodyGradient: HarborGradient.sun,
                    size: CGSize(width: s.width * 0.26, height: s.height * 0.06)
                )
                .rotationEffect(.degrees(-8))
                .position(x: s.width * 0.2, y: s.height * 0.58)

                HarborFish(
                    bodyGradient: LinearGradient(
                        colors: [Color(hex: 0x9BF1FA), HarborPalette.aqua],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    size: CGSize(width: s.width * 0.2, height: s.height * 0.05),
                    flipped: true
                )
                .position(x: s.width * 0.83, y: s.height * 0.22)

                LinearGradient(
                    colors: [.clear, HarborPalette.deepSea.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: s.height * 0.38)
                .position(x: s.width * 0.5, y: s.height * 0.81)
            }
            .frame(width: s.width, height: s.height)
            .clipped()
        }
    }

    private func checklistCard(size: CGSize) -> some View {
        RoundedRectangle(cornerRadius: size.width * 0.12, style: .continuous)
            .fill(Color.white.opacity(0.95))
            .frame(width: size.width, height: size.height)
            .overlay(
                VStack(alignment: .leading, spacing: size.height * 0.11) {
                    ForEach(0..<4, id: \.self) { index in
                        HStack(spacing: size.width * 0.07) {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(index < 2 ? HarborPalette.leaf : HarborPalette.aqua.opacity(0.35))
                                .frame(width: size.width * 0.12, height: size.width * 0.12)
                            Capsule()
                                .fill(HarborPalette.ink.opacity(0.16))
                                .frame(height: size.height * 0.08)
                        }
                    }
                }
                .padding(size.width * 0.12)
            )
            .harborShadow()
    }
}
