//
//  HomeView.swift
//  HarborPantry
//
//  Screen 4 — the dashboard. Every card is built from records the user
//  actually created; nothing is filled in with sample data.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var viewModel: HomeViewModel
    @State private var showAddProduct = false
    @State private var showFreshness = false

    let onNavigate: (HomeDestination) -> Void

    init(dependencies: AppDependencies, onNavigate: @escaping (HomeDestination) -> Void) {
        self.onNavigate = onNavigate
        // `StateObject` evaluates this once, so the view model survives the
        // re-creations of this struct.
        _viewModel = StateObject(wrappedValue: HomeViewModel(dependencies: dependencies))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: HarborMetrics.spacingM) {
                    header

                    if let reason = viewModel.loadState.cachedReason {
                        CachedDataBanner(message: reason)
                    }
                    if let failure = viewModel.loadState.failureMessage {
                        CachedDataBanner(message: failure)
                    }

                    if viewModel.loadState.isLoading {
                        LoadingStateView()
                    } else if viewModel.dashboard.isEmpty {
                        emptyState
                    } else {
                        filterPicker
                        useSoonCard
                        mealCard
                        shoppingCard
                        prepCard
                        storageCard
                        quickActions
                    }
                }
                .padding(.horizontal, HarborMetrics.spacingL)
                .padding(.bottom, HarborMetrics.spacingXL)
            }
            .harborScreenBackground()
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .onAppear { viewModel.refresh() }
        .sheet(isPresented: $showAddProduct) {
            NavigationView {
                ProductFormView(dependencies: dependencies, mode: .create) { _ in showAddProduct = false }
            }
            .navigationViewStyle(.stack)
            .environmentObject(dependencies)
        }
        .sheet(isPresented: $showFreshness) {
            NavigationView {
                FreshnessCalendarView(dependencies: dependencies)
            }
            .navigationViewStyle(.stack)
            .environmentObject(dependencies)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: HarborMetrics.spacingM) {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.greeting)
                    .font(HarborFont.caption(13))
                    .foregroundColor(HarborColor.textSecondary)
                Text(viewModel.profile.displayName)
                    .font(HarborFont.display(28))
                    .foregroundColor(HarborColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: HarborMetrics.spacingS)
            // Hero shrinks to 120 pt once the dashboard has real content.
            HarborIllustrationView(illustration: .homeFisherman)
                .frame(width: viewModel.dashboard.isEmpty ? 150 : 120)
        }
        .padding(.top, HarborMetrics.spacingS)
    }

    private var filterPicker: some View {
        HStack(spacing: HarborMetrics.spacingS) {
            ForEach(HomeFilter.allCases) { option in
                Button {
                    viewModel.filter = option
                } label: {
                    Text(option.displayName)
                        .font(HarborFont.caption(13))
                        .foregroundColor(viewModel.filter == option ? .white : HarborColor.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(
                            Capsule().fill(
                                viewModel.filter == option
                                    ? AnyShapeStyle(HarborGradient.ocean)
                                    : AnyShapeStyle(HarborColor.surface)
                            )
                        )
                        .overlay(
                            Capsule().strokeBorder(
                                viewModel.filter == option ? Color.clear : HarborColor.separator,
                                lineWidth: 1
                            )
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: HarborMetrics.spacingM) {
            HarborCard {
                VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                    Text("Your pantry is empty")
                        .font(HarborFont.title(22))
                        .foregroundColor(HarborColor.textPrimary)
                    Text("Start by adding one product you already have at home. Everything else — meals, portions, the shopping list and the prep timeline — builds on what you enter here.")
                        .font(HarborFont.body(14))
                        .foregroundColor(HarborColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    // The one small extra illustration allowed in the empty state.
                    HarborIllustrationView(illustration: .productCrate)
                        .frame(width: 160)
                        .frame(maxWidth: .infinity)

                    Button("Add Your First Product") {
                        showAddProduct = true
                    }
                    .buttonStyle(HarborPrimaryButtonStyle())

                    Button("Set Up Storage Zones") {
                        onNavigate(.inventory)
                    }
                    .buttonStyle(HarborSecondaryButtonStyle())
                }
            }
            UserDataNotice()
        }
    }

    // MARK: - Cards

    private var useSoonCard: some View {
        HarborCard {
            VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                SectionHeader(
                    title: "Use Soon",
                    subtitle: subtitleForUseSoon,
                    actionTitle: viewModel.dashboard.useSoon.isEmpty ? nil : "Calendar",
                    action: { showFreshness = true }
                )

                if viewModel.dashboard.useSoon.isEmpty {
                    Text(viewModel.dashboard.missingDateCount > 0
                         ? "Nothing is coming up in the dates you set. \(viewModel.dashboard.missingDateCount) product\(viewModel.dashboard.missingDateCount == 1 ? "" : "s") still have no date."
                         : "Nothing is coming up in the dates you set.")
                        .font(HarborFont.body(14))
                        .foregroundColor(HarborColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(spacing: HarborMetrics.spacingS) {
                        ForEach(viewModel.dashboard.useSoon) { product in
                            NavigationLink {
                                ProductDetailsView(dependencies: dependencies, productId: product.id)
                            } label: {
                                useSoonRow(product)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if viewModel.dashboard.reviewCount > 0 {
                        Button("Review \(viewModel.dashboard.reviewCount) item\(viewModel.dashboard.reviewCount == 1 ? "" : "s")") {
                            showFreshness = true
                        }
                        .buttonStyle(HarborChipButtonStyle(tint: HarborPalette.coral))
                    }
                }
            }
        }
    }

    private var subtitleForUseSoon: String? {
        guard viewModel.dashboard.reviewCount > 0 else { return nil }
        return "Dates you set have passed on \(viewModel.dashboard.reviewCount) item\(viewModel.dashboard.reviewCount == 1 ? "" : "s") — your call on what to do."
    }

    private func useSoonRow(_ product: Product) -> some View {
        let bucket = viewModel.bucket(for: product)
        return HStack(spacing: HarborMetrics.spacingM) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(HarborColor.bucket(bucket).opacity(0.16))
                .frame(width: 38, height: 38)
                .overlay(
                    Image(systemName: product.category.symbolName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(HarborColor.bucket(bucket))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(product.trimmedName)
                    .font(HarborFont.headline(15))
                    .foregroundColor(HarborColor.textPrimary)
                    .lineLimit(1)
                Text(HarborFormat.quantity(product.quantity, product.unit))
                    .font(HarborFont.caption(12))
                    .foregroundColor(HarborColor.textSecondary)
            }
            Spacer(minLength: 4)
            StatusPill(
                text: viewModel.daysRemainingText(for: product),
                color: HarborColor.bucket(bucket)
            )
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var mealCard: some View {
        HarborCard {
            VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                SectionHeader(
                    title: viewModel.filter == .today ? "Meals Today" : "Meals This Week",
                    actionTitle: "Plan",
                    action: { onNavigate(.mealPlan) }
                )

                if viewModel.dashboard.meals.isEmpty {
                    Text("No meals planned for this window yet.")
                        .font(HarborFont.body(14))
                        .foregroundColor(HarborColor.textSecondary)
                } else {
                    ForEach(viewModel.dashboard.meals) { meal in
                        HStack(spacing: HarborMetrics.spacingM) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(meal.dishName)
                                    .font(HarborFont.headline(15))
                                    .foregroundColor(HarborColor.textPrimary)
                                    .lineLimit(1)
                                Text("\(meal.slotTitle) · \(meal.servings) serving\(meal.servings == 1 ? "" : "s")")
                                    .font(HarborFont.caption(12))
                                    .foregroundColor(HarborColor.textSecondary)
                            }
                            Spacer(minLength: 4)
                            StatusPill(
                                text: meal.coverage.displayName,
                                systemImage: meal.coverage.symbolName,
                                color: HarborColor.coverage(meal.coverage)
                            )
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
        }
    }

    private var shoppingCard: some View {
        HarborCard {
            VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                SectionHeader(
                    title: "Shopping Progress",
                    actionTitle: "Open",
                    action: { onNavigate(.shopping) }
                )

                if viewModel.dashboard.shoppingTotal == 0 {
                    Text("Nothing on the list. Missing ingredients from your plan land here automatically.")
                        .font(HarborFont.body(14))
                        .foregroundColor(HarborColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    HStack {
                        Text("\(viewModel.dashboard.shoppingPurchased) of \(viewModel.dashboard.shoppingTotal) bought")
                            .font(HarborFont.body(14))
                            .foregroundColor(HarborColor.textPrimary)
                        Spacer()
                        Text("\(Int(viewModel.dashboard.shoppingProgress * 100))%")
                            .font(HarborFont.numeric(15))
                            .foregroundColor(HarborColor.accent)
                    }
                    HarborProgressBar(value: viewModel.dashboard.shoppingProgress)
                }
            }
        }
    }

    @ViewBuilder
    private var prepCard: some View {
        if let task = viewModel.dashboard.nextPrepTask {
            HarborAccentCard(accent: HarborPalette.sunGold) {
                HStack(spacing: HarborMetrics.spacingM) {
                    Image(systemName: task.kind.symbolName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(HarborPalette.sunGold)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(HarborPalette.sunGold.opacity(0.15)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next step: \(task.title)")
                            .font(HarborFont.headline(15))
                            .foregroundColor(HarborColor.textPrimary)
                            .lineLimit(2)
                        Text(HarborFormat.time.string(from: task.scheduledAt))
                            .font(HarborFont.caption(12))
                            .foregroundColor(HarborColor.textSecondary)
                    }
                    Spacer(minLength: 4)
                    Button("Open") { onNavigate(.prep) }
                        .buttonStyle(HarborChipButtonStyle())
                }
            }
        }
    }

    private var storageCard: some View {
        HarborCard {
            VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                SectionHeader(title: "Storage Summary")
                ForEach(viewModel.dashboard.zones) { zone in
                    HStack(spacing: HarborMetrics.spacingM) {
                        HarborStorageIcon(type: zone.type)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(HarborColor.accent)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(HarborColor.accent.opacity(0.12)))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(zone.name)
                                .font(HarborFont.headline(14))
                                .foregroundColor(HarborColor.textPrimary)
                                .lineLimit(1)
                            Text(capacityText(zone))
                                .font(HarborFont.caption(11.5))
                                .foregroundColor(HarborColor.textSecondary)
                        }
                        Spacer(minLength: 4)
                        if zone.useSoonCount > 0 {
                            StatusPill(
                                text: "\(zone.useSoonCount) soon",
                                color: HarborPalette.sunGold
                            )
                        }
                    }
                }
            }
        }
    }

    private func capacityText(_ zone: HomeDashboard.ZoneSummary) -> String {
        if let capacity = zone.capacity {
            return "\(zone.productCount) of \(capacity) slots used"
        }
        return "\(zone.productCount) product\(zone.productCount == 1 ? "" : "s")"
    }

    private var quickActions: some View {
        HarborCard {
            VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                SectionHeader(title: "Quick Actions")
                HStack(spacing: HarborMetrics.spacingS) {
                    quickAction(title: "Add Product", symbol: "plus.circle.fill") {
                        showAddProduct = true
                    }
                    quickAction(title: "Plan Meal", symbol: "calendar.badge.plus") {
                        onNavigate(.mealPlan)
                    }
                    quickAction(title: "Shopping", symbol: "cart.fill") {
                        onNavigate(.shopping)
                    }
                }
            }
        }
    }

    private func quickAction(title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(HarborColor.accent)
                Text(title)
                    .font(HarborFont.caption(11.5))
                    .foregroundColor(HarborColor.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, HarborMetrics.spacingM)
            .background(
                RoundedRectangle(cornerRadius: HarborMetrics.controlRadius, style: .continuous)
                    .fill(HarborColor.surfaceSunken)
            )
        }
        .buttonStyle(.plain)
    }
}
