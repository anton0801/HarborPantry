//
//  ProductDetailsView.swift
//  HarborPantry
//
//  Screen 8 — one product, and everything connected to it.
//

import SwiftUI

struct ProductDetailsView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var viewModel: ProductDetailsViewModel

    @State private var showEdit = false
    @State private var showMove = false
    @State private var showDeleteConfirmation = false
    @State private var showAddToShopping = false
    @State private var shoppingQuantityText = "1"

    init(dependencies: AppDependencies, productId: UUID) {
        _viewModel = StateObject(
            wrappedValue: ProductDetailsViewModel(dependencies: dependencies, productId: productId)
        )
    }

    var body: some View {
        Group {
            if let product = viewModel.product {
                content(product)
            } else {
                EmptyStateView(
                    title: "Product not found",
                    message: "This product is no longer in your inventory."
                )
            }
        }
        .harborScreenBackground()
        .navigationTitle(viewModel.product?.trimmedName ?? "Product")
        .navigationBarTitleDisplayMode(.inline)
        .harborToast($viewModel.toast)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Edit") { showEdit = true }
                    Button("Duplicate") { Task { await viewModel.duplicate() } }
                    Button(viewModel.product?.isArchived == true ? "Restore" : "Archive") {
                        Task { await viewModel.setArchived(!(viewModel.product?.isArchived ?? false)) }
                    }
                    Button("Delete", role: .destructive) { showDeleteConfirmation = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            if let product = viewModel.product {
                NavigationView {
                    ProductFormView(dependencies: dependencies, mode: .edit(product.id)) { _ in
                        showEdit = false
                    }
                }
                .navigationViewStyle(.stack)
                .environmentObject(dependencies)
            }
        }
        .sheet(isPresented: $showMove) {
            NavigationView {
                ZonePickerView(zones: viewModel.zones, title: "Move Product") { zoneId in
                    Task {
                        await viewModel.move(to: zoneId)
                        showMove = false
                    }
                }
            }
            .navigationViewStyle(.stack)
        }
        .alert("Delete this product?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    if await viewModel.delete() {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        } message: {
            Text("The product is removed from your inventory. Its history entries stay.")
        }
        .alert("Add to shopping list", isPresented: $showAddToShopping) {
            TextField("Quantity", text: $shoppingQuantityText)
                .keyboardType(.decimalPad)
            Button("Cancel", role: .cancel) {}
            Button("Add") {
                let amount = Double(shoppingQuantityText.replacingOccurrences(of: ",", with: ".")) ?? 1
                Task { await viewModel.addToShopping(quantity: amount) }
            }
        } message: {
            Text("How much more do you want to buy?")
        }
    }

    private func content(_ product: Product) -> some View {
        ScrollView {
            VStack(spacing: HarborMetrics.spacingM) {
                // The user's own photo leads; the crate stands in when there
                // is none.
                ProductPhotoView(
                    fileName: product.photoFileName,
                    photoStore: dependencies.photoStore,
                    height: 190
                )

                if let error = viewModel.errorMessage {
                    ErrorStateView(message: error)
                }

                summaryCard(product)
                useCard(product)
                datesCard(product)
                if !viewModel.linkedDishes.isEmpty { dishesCard }
                if !product.notes.isEmpty || !product.tags.isEmpty { notesCard(product) }
                historyCard
            }
            .padding(.horizontal, HarborMetrics.spacingL)
            .padding(.vertical, HarborMetrics.spacingM)
        }
    }

    // MARK: - Cards

    private func summaryCard(_ product: Product) -> some View {
        HarborCard {
            VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(product.trimmedName)
                            .font(HarborFont.title(22))
                            .foregroundColor(HarborColor.textPrimary)
                        Text(product.category.displayName)
                            .font(HarborFont.caption(12))
                            .foregroundColor(HarborColor.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(product.quantity.quantityText)
                            .font(HarborFont.numeric(24))
                            .foregroundColor(HarborColor.accent)
                        Text(product.unit.shortLabel)
                            .font(HarborFont.caption(12))
                            .foregroundColor(HarborColor.textSecondary)
                    }
                }

                HStack(spacing: HarborMetrics.spacingS) {
                    if let bucket = viewModel.bucket {
                        StatusPill(
                            text: viewModel.daysText ?? bucket.displayName,
                            systemImage: bucket.symbolName,
                            color: HarborColor.bucket(bucket)
                        )
                    }
                    if let zone = viewModel.zone {
                        StatusPill(text: zone.name, systemImage: zone.type.symbolName, color: HarborColor.accent)
                    }
                    if product.isArchived {
                        StatusPill(text: "Archived", color: HarborColor.textSecondary)
                    }
                }

                HStack(spacing: HarborMetrics.spacingS) {
                    Button("Move") { showMove = true }
                        .buttonStyle(HarborChipButtonStyle())
                    Button("Add to Shopping") { showAddToShopping = true }
                        .buttonStyle(HarborChipButtonStyle(tint: HarborPalette.leaf))
                    Spacer()
                }
            }
        }
    }

    private func useCard(_ product: Product) -> some View {
        HarborCard {
            VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                SectionHeader(
                    title: "Use or Discard",
                    subtitle: "You have \(HarborFormat.quantity(product.quantity, product.unit)) left."
                )

                HStack(spacing: HarborMetrics.spacingS) {
                    HarborTextField(
                        placeholder: "Amount",
                        text: $viewModel.useAmountText,
                        keyboard: .decimalPad
                    )
                    Text(product.unit.shortLabel)
                        .font(HarborFont.caption(13))
                        .foregroundColor(HarborColor.textSecondary)
                        .frame(width: 46)
                }

                HStack(spacing: HarborMetrics.spacingS) {
                    Button("Use") {
                        Task { await viewModel.useQuantity() }
                    }
                    .buttonStyle(HarborPrimaryButtonStyle(isEnabled: viewModel.canUse))
                    .disabled(!viewModel.canUse)

                    Button("Discard") {
                        Task { await viewModel.discardQuantity() }
                    }
                    .buttonStyle(HarborSecondaryButtonStyle(tint: HarborPalette.coral))
                    .disabled(!viewModel.canUse)
                    .opacity(viewModel.canUse ? 1 : 0.5)
                }

                Text("You cannot use more than you have. Each action records one history entry and can be undone straight away.")
                    .font(HarborFont.caption(11.5))
                    .foregroundColor(HarborColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func datesCard(_ product: Product) -> some View {
        HarborCard {
            VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                SectionHeader(title: "Dates")
                dateRow("Purchased", product.purchaseDate)
                dateRow("Use by (yours)", product.useByDate)
                dateRow("Opened", product.openedDate)
                if let price = product.price {
                    HStack {
                        Text("Price")
                            .font(HarborFont.body(14))
                            .foregroundColor(HarborColor.textSecondary)
                        Spacer()
                        Text(HarborFormat.price(price, currency: dependencies.profileRepository.currentProfile().currency))
                            .font(HarborFont.body(14))
                            .foregroundColor(HarborColor.textPrimary)
                    }
                }
                UserDataNotice(
                    text: "These are the dates you entered. Harbor Pantry does not assess freshness or food safety."
                )
            }
        }
    }

    private func dateRow(_ label: String, _ date: Date?) -> some View {
        HStack {
            Text(label)
                .font(HarborFont.body(14))
                .foregroundColor(HarborColor.textSecondary)
            Spacer()
            Text(date.map { HarborFormat.fullDate.string(from: $0) } ?? "Not set")
                .font(HarborFont.body(14))
                .foregroundColor(date == nil ? HarborColor.textSecondary.opacity(0.7) : HarborColor.textPrimary)
        }
    }

    private var dishesCard: some View {
        HarborCard {
            VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                SectionHeader(title: "Used in Dishes")
                ForEach(viewModel.linkedDishes) { dish in
                    HStack {
                        Image(systemName: "fork.knife")
                            .foregroundColor(HarborColor.accent)
                        Text(dish.trimmedName)
                            .font(HarborFont.body(15))
                            .foregroundColor(HarborColor.textPrimary)
                        Spacer()
                        Text("\(dish.servings) serving\(dish.servings == 1 ? "" : "s")")
                            .font(HarborFont.caption(12))
                            .foregroundColor(HarborColor.textSecondary)
                    }
                }
            }
        }
    }

    private func notesCard(_ product: Product) -> some View {
        HarborCard {
            VStack(alignment: .leading, spacing: HarborMetrics.spacingS) {
                SectionHeader(title: "Notes & Tags")
                if !product.notes.isEmpty {
                    Text(product.notes)
                        .font(HarborFont.body(14))
                        .foregroundColor(HarborColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !product.tags.isEmpty {
                    FlowLayoutView(items: product.tags) { tag in
                        StatusPill(text: tag, color: HarborColor.accentSoft)
                    }
                }
            }
        }
    }

    private var historyCard: some View {
        HarborCard {
            VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                SectionHeader(title: "History", subtitle: "Everything that happened to this product.")
                if viewModel.history.isEmpty {
                    Text("No entries yet.")
                        .font(HarborFont.body(14))
                        .foregroundColor(HarborColor.textSecondary)
                } else {
                    ForEach(viewModel.history) { entry in
                        HStack(alignment: .top, spacing: HarborMetrics.spacingM) {
                            Image(systemName: entry.kind.symbolName)
                                .font(.system(size: 15))
                                .foregroundColor(HarborColor.accent)
                                .frame(width: 26)
                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 5) {
                                    Text(entry.kind.displayName)
                                        .font(HarborFont.headline(14))
                                        .foregroundColor(HarborColor.textPrimary)
                                    if let delta = entry.quantityDelta, let unit = entry.unit {
                                        Text("\(delta > 0 ? "+" : "")\(delta.quantityText) \(unit.shortLabel)")
                                            .font(HarborFont.caption(12))
                                            .foregroundColor(delta < 0 ? HarborPalette.coral : HarborPalette.leaf)
                                    }
                                }
                                if !entry.note.isEmpty {
                                    Text(entry.note)
                                        .font(HarborFont.caption(11.5))
                                        .foregroundColor(HarborColor.textSecondary)
                                }
                                Text(HarborFormat.dateTime.string(from: entry.createdAt))
                                    .font(HarborFont.caption(11))
                                    .foregroundColor(HarborColor.textSecondary.opacity(0.8))
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
    }
}
