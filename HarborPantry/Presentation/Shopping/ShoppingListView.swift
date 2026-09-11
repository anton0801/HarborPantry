//
//  ShoppingListView.swift
//  HarborPantry
//
//  Screen 13 — one list holding plan-generated rows and manual additions.
//

import SwiftUI

struct ShoppingListView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var viewModel: ShoppingListViewModel

    @State private var showAddItem = false
    @State private var storeEditItem: ShoppingItem?

    init(dependencies: AppDependencies) {
        _viewModel = StateObject(wrappedValue: ShoppingListViewModel(dependencies: dependencies))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: HarborMetrics.spacingM) {
                    if let error = viewModel.errorMessage {
                        ErrorStateView(message: error)
                    }

                    if viewModel.isEmpty {
                        emptyState
                    } else {
                        summaryCard
                        controls
                        ForEach(viewModel.groups) { group in
                            groupCard(group)
                        }
                        if !viewModel.excludedItems.isEmpty {
                            excludedCard
                        }
                    }
                }
                .padding(.horizontal, HarborMetrics.spacingL)
                .padding(.bottom, HarborMetrics.spacingXL)
                .padding(.top, HarborMetrics.spacingS)
            }
            .harborScreenBackground()
            .navigationTitle("Shopping")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: HarborMetrics.spacingM) {
                        Button {
                            Task { await viewModel.syncFromPlan() }
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        Button {
                            showAddItem = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .harborToast($viewModel.toast)
        .sheet(isPresented: $showAddItem) {
            NavigationView {
                AddShoppingItemView(currency: viewModel.currency) { name, category, quantity, unit, store, price, shopper in
                    Task {
                        await viewModel.addCustomItem(
                            name: name,
                            category: category,
                            quantity: quantity,
                            unit: unit,
                            store: store,
                            estimatedPrice: price,
                            shopper: shopper
                        )
                        showAddItem = false
                    }
                }
            }
            .navigationViewStyle(.stack)
        }
        .sheet(item: $viewModel.purchasingItem) { item in
            NavigationView {
                PurchaseConfirmationView(
                    item: item,
                    zones: viewModel.zones,
                    currency: viewModel.currency
                ) { confirmation in
                    Task {
                        await viewModel.confirmPurchase(item: item, confirmation: confirmation)
                        viewModel.purchasingItem = nil
                    }
                }
            }
            .navigationViewStyle(.stack)
        }
        .sheet(item: $viewModel.excludingItem) { item in
            NavigationView {
                ExcludeItemView(item: item) { reason in
                    Task {
                        await viewModel.exclude(item: item, reason: reason)
                        viewModel.excludingItem = nil
                    }
                }
            }
            .navigationViewStyle(.stack)
        }
        .sheet(item: $storeEditItem) { item in
            NavigationView {
                StoreEditView(item: item) { store in
                    Task {
                        await viewModel.setStore(item: item, store: store)
                        storeEditItem = nil
                    }
                }
            }
            .navigationViewStyle(.stack)
        }
    }

    // MARK: - States

    private var emptyState: some View {
        VStack(spacing: HarborMetrics.spacingM) {
            EmptyStateView(
                title: "Nothing to buy",
                message: "Ingredients your meal plan cannot cover appear here automatically. You can also add anything by hand.",
                illustration: .shoppingBasket,
                illustrationWidth: 200,
                actionTitle: "Add an Item",
                action: { showAddItem = true }
            )
            Button("Check My Meal Plan") {
                Task { await viewModel.syncFromPlan() }
            }
            .buttonStyle(HarborSecondaryButtonStyle())
        }
    }

    private var summaryCard: some View {
        HarborCard {
            HStack(spacing: HarborMetrics.spacingM) {
                // Small basket in the summary; the large one only appears in
                // the empty state.
                HarborIllustrationView(illustration: .shoppingBasket)
                    .frame(width: 64)
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(viewModel.purchasedItems.count) of \(viewModel.pendingItems.count + viewModel.purchasedItems.count) bought")
                        .font(HarborFont.headline(16))
                        .foregroundColor(HarborColor.textPrimary)
                    HarborProgressBar(value: viewModel.progress)
                    HStack(spacing: HarborMetrics.spacingM) {
                        Text("Est. \(HarborFormat.price(viewModel.estimatedTotal, currency: viewModel.currency))")
                            .font(HarborFont.caption(11.5))
                            .foregroundColor(HarborColor.textSecondary)
                        Text("Spent \(HarborFormat.price(viewModel.actualTotal, currency: viewModel.currency))")
                            .font(HarborFont.caption(11.5))
                            .foregroundColor(HarborColor.textSecondary)
                    }
                }
            }
        }
    }

    private var controls: some View {
        HStack(spacing: HarborMetrics.spacingS) {
            Picker("Group", selection: $viewModel.grouping) {
                ForEach(ShoppingListViewModel.Grouping.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.segmented)

            Button {
                viewModel.showPurchased.toggle()
            } label: {
                Image(systemName: viewModel.showPurchased ? "eye" : "eye.slash")
                    .foregroundColor(HarborColor.accent)
                    .frame(width: 40, height: 32)
            }
            .accessibilityLabel(viewModel.showPurchased ? "Hide purchased items" : "Show purchased items")
        }
    }

    private func groupCard(_ group: ShoppingListViewModel.Group) -> some View {
        HarborCard {
            VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                SectionHeader(title: group.title, subtitle: "\(group.items.count) item\(group.items.count == 1 ? "" : "s")")
                ForEach(group.items) { item in
                    itemRow(item)
                }
            }
        }
    }

    private func itemRow(_ item: ShoppingItem) -> some View {
        VStack(alignment: .leading, spacing: HarborMetrics.spacingS) {
            HStack(spacing: HarborMetrics.spacingM) {
                Button {
                    if item.status == .purchased {
                        Task { await viewModel.restore(item: item) }
                    } else {
                        viewModel.purchasingItem = item
                    }
                } label: {
                    Image(systemName: item.status == .purchased ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundColor(item.status == .purchased ? HarborPalette.leaf : HarborColor.separator)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.trimmedName)
                        .font(HarborFont.headline(15))
                        .foregroundColor(HarborColor.textPrimary)
                        .strikethrough(item.status == .purchased, color: HarborColor.textSecondary)
                        .lineLimit(1)

                    HStack(spacing: 5) {
                        Text("Buy \(HarborFormat.quantity(item.toBuy, item.unit))")
                            .font(HarborFont.caption(11.5))
                            .foregroundColor(HarborColor.textSecondary)
                        if item.alreadyHave > 0 {
                            Text("· have \(item.alreadyHave.quantityText)")
                                .font(HarborFont.caption(11.5))
                                .foregroundColor(HarborPalette.leaf)
                        }
                    }
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 3) {
                    if item.origin.isAutomatic {
                        StatusPill(text: "From plan", color: HarborColor.accent)
                    }
                    if let price = item.actualPrice ?? item.estimatedPrice {
                        Text(HarborFormat.price(price, currency: viewModel.currency))
                            .font(HarborFont.caption(11.5))
                            .foregroundColor(HarborColor.textSecondary)
                    }
                }
            }

            HStack(spacing: HarborMetrics.spacingS) {
                Button(item.storeLabel) { storeEditItem = item }
                    .buttonStyle(HarborChipButtonStyle(tint: HarborPalette.sunGold))

                if item.status == .pending {
                    if item.origin.isAutomatic {
                        Button("Exclude") { viewModel.excludingItem = item }
                            .buttonStyle(HarborChipButtonStyle(tint: HarborPalette.coral))
                    } else {
                        Button("Delete") {
                            Task { await viewModel.delete(item: item) }
                        }
                        .buttonStyle(HarborChipButtonStyle(tint: HarborPalette.coral))
                    }
                }
                Spacer()
            }

            Divider().background(HarborColor.separator)
        }
    }

    private var excludedCard: some View {
        HarborCard {
            VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                SectionHeader(
                    title: "Excluded",
                    subtitle: "Kept with your reason so the list stays honest."
                )
                ForEach(viewModel.excludedItems) { item in
                    HStack(alignment: .top, spacing: HarborMetrics.spacingM) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.trimmedName)
                                .font(HarborFont.headline(14))
                                .foregroundColor(HarborColor.textPrimary)
                            Text(item.exclusionReason)
                                .font(HarborFont.caption(11.5))
                                .foregroundColor(HarborColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Button("Restore") {
                            Task { await viewModel.restore(item: item) }
                        }
                        .buttonStyle(HarborChipButtonStyle())
                    }
                }
            }
        }
    }
}
