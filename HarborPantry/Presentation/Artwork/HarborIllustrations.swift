//
//  HarborIllustrations.swift
//  HarborPantry
//
//  Presentation layer — bundled fishing and harbor illustrations.
//
//  Each slot resolves to a bundled image asset when one is present (drop
//  `BAS_01`…`BAS_20` into the asset catalog) and otherwise renders the vector
//  fallback defined here, so no screen ever shows a broken image box.
//

import SwiftUI

enum HarborIllustration: String, CaseIterable, Identifiable {
    /// Onboarding 1 — inventory and storage.
    case onboardingInventory = "BAS_01"
    /// Onboarding 2 — meals and portions.
    case onboardingMeals = "BAS_02"
    /// Onboarding 3 — shopping and prep.
    case onboardingShopping = "BAS_03"
    /// Home hero — the harbour keeper.
    case homeFisherman = "BAS_04"
    /// Product crate — inventory, forms, product fallback, leftovers.
    case productCrate = "BAS_05"
    /// Storage furniture — profile and zones.
    case storageCabinet = "BAS_06"
    /// Plated meal — meal plan and dish builder.
    case mealPlate = "BAS_07"
    /// Shopping basket.
    case shoppingBasket = "BAS_08"
    /// Prep clock — freshness calendar and prep timeline.
    case prepClock = "BAS_09"
    /// Lighthouse — insights and archive.
    case summaryLighthouse = "BAS_10"
    case profileCreel = "BAS_11"
    case recipeJournal = "BAS_12"
    case archiveChest = "BAS_13"
    case leftoverLunchbox = "BAS_14"
    case freshnessCalendar = "BAS_15"
    case zoneRefrigerator = "BAS_16"
    case zoneFreezer = "BAS_17"
    case zonePantry = "BAS_18"
    case zoneCustom = "BAS_19"
    case settingsCompass = "BAS_20"

    var id: String { rawValue }

    /// Natural aspect ratio of the slot, matching the art brief's sizes.
    var aspect: CGFloat {
        switch self {
        case .onboardingInventory, .onboardingMeals, .onboardingShopping:
            return 1290.0 / 2796.0
        case .homeFisherman: return 1200.0 / 1400.0
        case .productCrate, .mealPlate, .summaryLighthouse,
             .recipeJournal, .archiveChest, .leftoverLunchbox: return 1100.0 / 850.0
        case .storageCabinet, .profileCreel: return 1100.0 / 900.0
        case .shoppingBasket, .prepClock, .freshnessCalendar: return 1000.0 / 900.0
        case .zoneRefrigerator, .zoneFreezer, .zonePantry, .zoneCustom, .settingsCompass:
            return 1
        }
    }
}

/// Renders an illustration slot, preferring a real asset over the fallback.
struct HarborIllustrationView: View {
    let illustration: HarborIllustration
    /// `.fill` makes the art cover its slot (used by the onboarding backdrops);
    /// clip the result at the call site.
    var contentMode: ContentMode = .fit

    var body: some View {
        Group {
            if let image = UIImage(named: illustration.rawValue) {
                if contentMode == .fill {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    // Keep the original slot's geometry even when generated
                    // artwork has a different native pixel aspect ratio.
                    Color.clear
                        .aspectRatio(illustration.aspect, contentMode: .fit)
                        .overlay(
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                        )
                        .clipped()
                }
            } else {
                HarborVectorArt(illustration: illustration)
                    .environment(\.harborArtContentMode, contentMode)
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

/// The vector fallbacks.
struct HarborVectorArt: View {
    let illustration: HarborIllustration

    var body: some View {
        switch illustration {
        case .onboardingInventory: OnboardingInventoryArt()
        case .onboardingMeals: OnboardingMealsArt()
        case .onboardingShopping: OnboardingShoppingArt()
        case .homeFisherman: FishermanArt()
        case .productCrate: ProductCrateArt()
        case .storageCabinet: StorageCabinetArt()
        case .mealPlate: MealPlateArt()
        case .shoppingBasket: ShoppingBasketArt()
        case .prepClock: PrepClockArt()
        case .summaryLighthouse: LighthouseArt()
        case .profileCreel: StorageCabinetArt()
        case .recipeJournal: MealPlateArt()
        case .archiveChest: LighthouseArt()
        case .leftoverLunchbox: ProductCrateArt()
        case .freshnessCalendar: PrepClockArt()
        case .zoneRefrigerator, .zoneFreezer, .zonePantry, .zoneCustom: StorageCabinetArt()
        case .settingsCompass: PrepClockArt()
        }
    }
}

// MARK: - BAS_04 · Harbour keeper

/// An original slim, friendly keeper in a turquoise jacket and coral cap,
/// holding a crate of food and one bright fish.
struct FishermanArt: View {
    var body: some View {
        ArtBox(aspect: HarborIllustration.homeFisherman.aspect) { s in
            ZStack {
                // Soft halo so the figure reads on any card colour.
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [HarborPalette.aqua.opacity(0.28), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: s.width * 0.55
                        )
                    )
                    .frame(width: s.width, height: s.width)
                    .position(x: s.width * 0.5, y: s.height * 0.48)

                // Torso
                RoundedRectangle(cornerRadius: s.width * 0.16, style: .continuous)
                    .fill(HarborGradient.ocean)
                    .frame(width: s.width * 0.52, height: s.height * 0.42)
                    .overlay(
                        RoundedRectangle(cornerRadius: s.width * 0.16, style: .continuous)
                            .fill(HarborGradient.gloss)
                            .padding(.bottom, s.height * 0.24)
                    )
                    .position(x: s.width * 0.5, y: s.height * 0.68)

                // Collar and jacket zip
                Capsule()
                    .fill(HarborPalette.foam.opacity(0.95))
                    .frame(width: s.width * 0.2, height: s.height * 0.035)
                    .position(x: s.width * 0.5, y: s.height * 0.5)
                Capsule()
                    .fill(HarborPalette.deepSea.opacity(0.35))
                    .frame(width: s.width * 0.014, height: s.height * 0.2)
                    .position(x: s.width * 0.5, y: s.height * 0.63)

                // Arms hugging the crate, tucked behind the torso edges
                Capsule()
                    .fill(HarborPalette.oceanBlue)
                    .frame(width: s.width * 0.13, height: s.height * 0.3)
                    .rotationEffect(.degrees(20))
                    .position(x: s.width * 0.29, y: s.height * 0.7)
                Capsule()
                    .fill(HarborPalette.oceanBlue)
                    .frame(width: s.width * 0.13, height: s.height * 0.3)
                    .rotationEffect(.degrees(-20))
                    .position(x: s.width * 0.71, y: s.height * 0.7)

                // Head
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0xFFD9B8), Color(hex: 0xF3B98A)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: s.width * 0.28, height: s.width * 0.28)
                    .position(x: s.width * 0.5, y: s.height * 0.34)

                // Eyes and smile
                HStack(spacing: s.width * 0.07) {
                    Circle().fill(HarborPalette.ink).frame(width: s.width * 0.028)
                    Circle().fill(HarborPalette.ink).frame(width: s.width * 0.028)
                }
                .position(x: s.width * 0.5, y: s.height * 0.335)

                SmileShape()
                    .stroke(HarborPalette.ink.opacity(0.75), style: StrokeStyle(lineWidth: s.width * 0.016, lineCap: .round))
                    .frame(width: s.width * 0.1, height: s.height * 0.03)
                    .position(x: s.width * 0.5, y: s.height * 0.375)

                // Coral cap with brim
                CapShape()
                    .fill(HarborGradient.coral)
                    .frame(width: s.width * 0.32, height: s.height * 0.13)
                    .position(x: s.width * 0.5, y: s.height * 0.255)
                Capsule()
                    .fill(HarborPalette.coral)
                    .frame(width: s.width * 0.2, height: s.height * 0.022)
                    .position(x: s.width * 0.63, y: s.height * 0.288)

                // Crate of food held in front
                ZStack {
                    CrateShape(size: CGSize(width: s.width * 0.46, height: s.height * 0.2))
                    HStack(spacing: s.width * 0.03) {
                        GreensSprig(size: CGSize(width: s.width * 0.1, height: s.height * 0.07))
                        RoundFruit(diameter: s.width * 0.09, gradient: HarborGradient.sun)
                        BottleShape(size: CGSize(width: s.width * 0.06, height: s.height * 0.09))
                    }
                    .offset(y: -s.height * 0.11)
                }
                .position(x: s.width * 0.5, y: s.height * 0.82)

                // The catch of the day, tucked under one arm
                HarborFish(
                    bodyGradient: LinearGradient(
                        colors: [HarborPalette.sunGold, HarborPalette.coral],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    size: CGSize(width: s.width * 0.34, height: s.height * 0.16),
                    flipped: true
                )
                .rotationEffect(.degrees(-16))
                .position(x: s.width * 0.2, y: s.height * 0.52)
            }
        }
    }
}

private struct SmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.maxY * 1.6)
        )
        return path
    }
}

private struct CapShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.5)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - BAS_05 · Product crate

struct ProductCrateArt: View {
    var body: some View {
        ArtBox(aspect: HarborIllustration.productCrate.aspect) { s in
            ZStack {
                Ellipse()
                    .fill(HarborPalette.aqua.opacity(0.16))
                    .frame(width: s.width * 0.9, height: s.height * 0.22)
                    .position(x: s.width * 0.5, y: s.height * 0.88)

                // Contents rising above the crate lip
                HarborFish(
                    bodyGradient: HarborGradient.ocean,
                    size: CGSize(width: s.width * 0.44, height: s.height * 0.26)
                )
                .rotationEffect(.degrees(-12))
                .position(x: s.width * 0.36, y: s.height * 0.36)

                GreensSprig(size: CGSize(width: s.width * 0.26, height: s.height * 0.2))
                    .position(x: s.width * 0.66, y: s.height * 0.34)

                RoundFruit(diameter: s.width * 0.18, gradient: HarborGradient.sun)
                    .position(x: s.width * 0.78, y: s.height * 0.45)

                BottleShape(size: CGSize(width: s.width * 0.12, height: s.height * 0.3))
                    .position(x: s.width * 0.17, y: s.height * 0.38)

                CrateShape(size: CGSize(width: s.width * 0.82, height: s.height * 0.4))
                    .position(x: s.width * 0.5, y: s.height * 0.7)
            }
        }
    }
}

// MARK: - BAS_06 · Storage furniture

struct StorageCabinetArt: View {
    var body: some View {
        ArtBox(aspect: HarborIllustration.storageCabinet.aspect) { s in
            ZStack {
                Ellipse()
                    .fill(HarborPalette.aqua.opacity(0.16))
                    .frame(width: s.width * 0.92, height: s.height * 0.16)
                    .position(x: s.width * 0.5, y: s.height * 0.9)

                // Refrigerator
                unit(
                    size: CGSize(width: s.width * 0.3, height: s.height * 0.72),
                    gradient: HarborGradient.ocean,
                    dividerRatio: 0.42
                )
                .position(x: s.width * 0.22, y: s.height * 0.5)

                // Freezer drawers
                unit(
                    size: CGSize(width: s.width * 0.3, height: s.height * 0.52),
                    gradient: LinearGradient(
                        colors: [HarborPalette.aqua, HarborPalette.oceanBlue],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    dividerRatio: 0.5
                )
                .position(x: s.width * 0.54, y: s.height * 0.6)

                // Dry-goods cabinet
                unit(
                    size: CGSize(width: s.width * 0.26, height: s.height * 0.62),
                    gradient: LinearGradient(
                        colors: [Color(hex: 0xD79A5B), Color(hex: 0xA96B33)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    dividerRatio: nil
                )
                .position(x: s.width * 0.84, y: s.height * 0.55)

                Image(systemName: "snowflake")
                    .font(.system(size: s.width * 0.07, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .position(x: s.width * 0.54, y: s.height * 0.44)
            }
        }
    }

    private func unit(size: CGSize, gradient: LinearGradient, dividerRatio: CGFloat?) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size.width * 0.16, style: .continuous)
                .fill(gradient)
            RoundedRectangle(cornerRadius: size.width * 0.16, style: .continuous)
                .fill(HarborGradient.gloss)
                .padding(.bottom, size.height * 0.62)
                .padding(.horizontal, size.width * 0.08)

            if let ratio = dividerRatio {
                Rectangle()
                    .fill(Color.white.opacity(0.35))
                    .frame(height: max(1.5, size.height * 0.012))
                    .offset(y: -size.height * (0.5 - ratio))
            }

            // Gold handles
            VStack(spacing: size.height * 0.1) {
                Capsule()
                    .fill(HarborPalette.sunGold)
                    .frame(width: max(2, size.width * 0.06), height: size.height * 0.16)
                Capsule()
                    .fill(HarborPalette.sunGold)
                    .frame(width: max(2, size.width * 0.06), height: size.height * 0.16)
            }
            .offset(x: size.width * 0.3)
        }
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - BAS_07 · Plated meal

struct MealPlateArt: View {
    var body: some View {
        ArtBox(aspect: HarborIllustration.mealPlate.aspect) { s in
            ZStack {
                Ellipse()
                    .fill(HarborPalette.aqua.opacity(0.18))
                    .frame(width: s.width * 0.88, height: s.height * 0.2)
                    .position(x: s.width * 0.5, y: s.height * 0.85)

                // Plate
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [.white, Color(hex: 0xE6F4FA)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: s.width * 0.78, height: s.height * 0.46)
                    .overlay(
                        Ellipse()
                            .strokeBorder(HarborPalette.aqua.opacity(0.4), lineWidth: max(2, s.width * 0.012))
                            .frame(width: s.width * 0.64, height: s.height * 0.36)
                    )
                    .position(x: s.width * 0.5, y: s.height * 0.62)
                    .harborShadow(strength: 0.6)

                // Fish fillet
                HarborFish(
                    bodyGradient: LinearGradient(
                        colors: [Color(hex: 0xFFB48A), HarborPalette.coral],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    size: CGSize(width: s.width * 0.42, height: s.height * 0.2)
                )
                .rotationEffect(.degrees(-8))
                .position(x: s.width * 0.44, y: s.height * 0.56)

                // Potatoes
                HStack(spacing: s.width * 0.02) {
                    RoundFruit(diameter: s.width * 0.1, gradient: HarborGradient.sun)
                    RoundFruit(diameter: s.width * 0.08, gradient: HarborGradient.sun)
                }
                .position(x: s.width * 0.66, y: s.height * 0.66)

                GreensSprig(size: CGSize(width: s.width * 0.2, height: s.height * 0.14))
                    .position(x: s.width * 0.36, y: s.height * 0.68)

                // Two blank ingredient cards — labels come from the UI, never
                // from the artwork.
                ingredientCard(size: CGSize(width: s.width * 0.19, height: s.height * 0.24))
                    .rotationEffect(.degrees(-8))
                    .position(x: s.width * 0.13, y: s.height * 0.28)
                ingredientCard(size: CGSize(width: s.width * 0.19, height: s.height * 0.24))
                    .rotationEffect(.degrees(9))
                    .position(x: s.width * 0.87, y: s.height * 0.26)
            }
        }
    }

    private func ingredientCard(size: CGSize) -> some View {
        RoundedRectangle(cornerRadius: size.width * 0.2, style: .continuous)
            .fill(Color.white)
            .overlay(
                VStack(spacing: size.height * 0.08) {
                    Circle()
                        .fill(HarborGradient.ocean)
                        .frame(width: size.width * 0.4, height: size.width * 0.4)
                    // Blank label bars — no text is ever baked into the art.
                    Capsule()
                        .fill(HarborPalette.ink.opacity(0.16))
                        .frame(width: size.width * 0.56, height: size.height * 0.07)
                    Capsule()
                        .fill(HarborPalette.ink.opacity(0.10))
                        .frame(width: size.width * 0.38, height: size.height * 0.07)
                }
            )
            .frame(width: size.width, height: size.height)
            .harborShadow(strength: 0.5)
    }
}

// MARK: - BAS_08 · Shopping basket

struct ShoppingBasketArt: View {
    var body: some View {
        ArtBox(aspect: HarborIllustration.shoppingBasket.aspect) { s in
            ZStack {
                Ellipse()
                    .fill(HarborPalette.aqua.opacity(0.16))
                    .frame(width: s.width * 0.86, height: s.height * 0.16)
                    .position(x: s.width * 0.5, y: s.height * 0.9)

                // Handle
                Circle()
                    .trim(from: 0.5, to: 1.0)
                    .stroke(HarborPalette.sunGold, style: StrokeStyle(lineWidth: s.width * 0.05, lineCap: .round))
                    .frame(width: s.width * 0.44, height: s.width * 0.44)
                    .position(x: s.width * 0.5, y: s.height * 0.4)

                // Contents peeking over the rim
                GreensSprig(size: CGSize(width: s.width * 0.24, height: s.height * 0.16))
                    .position(x: s.width * 0.33, y: s.height * 0.44)
                RoundFruit(diameter: s.width * 0.15, gradient: HarborGradient.sun)
                    .position(x: s.width * 0.55, y: s.height * 0.46)
                HarborFish(
                    bodyGradient: HarborGradient.ocean,
                    size: CGSize(width: s.width * 0.3, height: s.height * 0.16)
                )
                .rotationEffect(.degrees(-18))
                .position(x: s.width * 0.72, y: s.height * 0.43)

                // Basket body
                BasketShape()
                    .fill(
                        LinearGradient(
                            colors: [HarborPalette.aqua, HarborPalette.oceanBlue],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: s.width * 0.72, height: s.height * 0.42)
                    .overlay(
                        BasketShape()
                            .fill(HarborGradient.gloss)
                            .frame(width: s.width * 0.72, height: s.height * 0.42)
                            .padding(.bottom, s.height * 0.26)
                    )
                    .overlay(weave(size: CGSize(width: s.width * 0.72, height: s.height * 0.42)))
                    .position(x: s.width * 0.5, y: s.height * 0.68)

                // Rim
                Capsule()
                    .fill(HarborPalette.sunGold)
                    .frame(width: s.width * 0.78, height: s.height * 0.07)
                    .position(x: s.width * 0.5, y: s.height * 0.5)

                // Blank coral tag — no baked-in text
                RoundedRectangle(cornerRadius: s.width * 0.03, style: .continuous)
                    .fill(HarborPalette.coral)
                    .frame(width: s.width * 0.16, height: s.height * 0.1)
                    .rotationEffect(.degrees(-12))
                    .position(x: s.width * 0.2, y: s.height * 0.68)
            }
        }
    }

    private func weave(size: CGSize) -> some View {
        VStack(spacing: size.height * 0.16) {
            ForEach(0..<3, id: \.self) { _ in
                Capsule()
                    .fill(Color.white.opacity(0.22))
                    .frame(height: max(1.5, size.height * 0.05))
            }
        }
        .padding(.horizontal, size.width * 0.12)
        .padding(.top, size.height * 0.16)
        .frame(width: size.width, height: size.height, alignment: .top)
    }
}

private struct BasketShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset = rect.width * 0.12
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY - rect.height * 0.1))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + inset, y: rect.maxY - rect.height * 0.1),
            control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.12)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - BAS_09 · Prep clock

struct PrepClockArt: View {
    var body: some View {
        ArtBox(aspect: HarborIllustration.prepClock.aspect) { s in
            ZStack {
                // Cutting board
                RoundedRectangle(cornerRadius: s.width * 0.06, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0xE0AC72), Color(hex: 0xB77B41)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: s.width * 0.62, height: s.height * 0.34)
                    .position(x: s.width * 0.55, y: s.height * 0.74)

                // Knife, laid flat and away from the edge
                ZStack {
                    Capsule()
                        .fill(Color(hex: 0x8A5A2B))
                        .frame(width: s.width * 0.16, height: s.height * 0.045)
                        .offset(x: -s.width * 0.16)
                    KnifeBladeShape()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0xE9F3F8), Color(hex: 0xB8CBD6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: s.width * 0.26, height: s.height * 0.07)
                        .offset(x: s.width * 0.04)
                }
                .rotationEffect(.degrees(-6))
                .position(x: s.width * 0.58, y: s.height * 0.76)

                // Clock face
                Circle()
                    .fill(HarborGradient.sun)
                    .frame(width: s.width * 0.46, height: s.width * 0.46)
                    .overlay(
                        Circle()
                            .fill(Color.white)
                            .frame(width: s.width * 0.36, height: s.width * 0.36)
                    )
                    .overlay(
                        Circle()
                            .fill(HarborGradient.gloss)
                            .frame(width: s.width * 0.46, height: s.width * 0.46)
                            .padding(.bottom, s.width * 0.28)
                    )
                    .overlay(
                        ZStack {
                            Capsule()
                                .fill(HarborPalette.ink)
                                .frame(width: max(2, s.width * 0.018), height: s.width * 0.12)
                                .offset(y: -s.width * 0.06)
                            Capsule()
                                .fill(HarborPalette.ink)
                                .frame(width: max(2, s.width * 0.018), height: s.width * 0.09)
                                .rotationEffect(.degrees(100))
                                .offset(x: s.width * 0.04)
                        }
                    )
                    .position(x: s.width * 0.38, y: s.height * 0.36)
                    .harborShadow(strength: 0.6)

                Image(systemName: "snowflake")
                    .font(.system(size: s.width * 0.14, weight: .bold))
                    .foregroundColor(HarborPalette.aqua)
                    .position(x: s.width * 0.78, y: s.height * 0.26)

                HarborFish(
                    bodyGradient: HarborGradient.ocean,
                    size: CGSize(width: s.width * 0.24, height: s.height * 0.13)
                )
                .position(x: s.width * 0.82, y: s.height * 0.55)
            }
        }
    }
}

private struct KnifeBladeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - BAS_10 · Lighthouse

struct LighthouseArt: View {
    var body: some View {
        ArtBox(aspect: HarborIllustration.summaryLighthouse.aspect) { s in
            ZStack {
                // Calm water
                WaveShape(amplitude: s.height * 0.02, wavelength: s.width * 0.5, phase: 0)
                    .fill(HarborPalette.aqua.opacity(0.3))
                    .frame(width: s.width, height: s.height * 0.3)
                    .position(x: s.width * 0.5, y: s.height * 0.86)

                // Island
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0xF2D9A8), Color(hex: 0xD7B274)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: s.width * 0.7, height: s.height * 0.22)
                    .position(x: s.width * 0.5, y: s.height * 0.79)

                // Light beam
                BeamShape()
                    .fill(
                        LinearGradient(
                            colors: [HarborPalette.sunGold.opacity(0.55), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: s.width * 0.42, height: s.height * 0.22)
                    .position(x: s.width * 0.72, y: s.height * 0.2)

                // Tower
                TowerShape()
                    .fill(Color.white)
                    .frame(width: s.width * 0.24, height: s.height * 0.5)
                    .overlay(
                        TowerShape()
                            .fill(HarborGradient.coral)
                            .frame(width: s.width * 0.24, height: s.height * 0.5)
                            .mask(
                                VStack(spacing: 0) {
                                    ForEach(0..<4, id: \.self) { index in
                                        Rectangle()
                                            .frame(height: s.height * 0.5 / 8)
                                            .opacity(index.isMultiple(of: 2) ? 1 : 0)
                                        Rectangle()
                                            .frame(height: s.height * 0.5 / 8)
                                            .opacity(0)
                                    }
                                }
                            )
                    )
                    .position(x: s.width * 0.5, y: s.height * 0.45)

                // Lantern room
                RoundedRectangle(cornerRadius: s.width * 0.02, style: .continuous)
                    .fill(HarborGradient.sun)
                    .frame(width: s.width * 0.14, height: s.height * 0.09)
                    .position(x: s.width * 0.5, y: s.height * 0.19)
                Triangle()
                    .fill(HarborPalette.deepSea)
                    .frame(width: s.width * 0.18, height: s.height * 0.06)
                    .position(x: s.width * 0.5, y: s.height * 0.12)

                // Tidy crates around the base
                CrateShape(size: CGSize(width: s.width * 0.16, height: s.height * 0.1))
                    .position(x: s.width * 0.26, y: s.height * 0.74)
                CrateShape(size: CGSize(width: s.width * 0.13, height: s.height * 0.08))
                    .position(x: s.width * 0.75, y: s.height * 0.75)
            }
        }
    }
}

private struct TowerShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset = rect.width * 0.18
        path.move(to: CGPoint(x: rect.minX + inset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct BeamShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
