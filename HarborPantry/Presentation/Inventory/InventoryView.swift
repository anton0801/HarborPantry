//
//  InventoryView.swift
//  HarborPantry
//
//  Screen 6 — every product, with search, filters and bulk actions.
//

import SwiftUI

struct InventoryView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var viewModel: InventoryViewModel

    @State private var showAddProduct = false
    @State private var showMoveSheet = false
    @State private var showDeleteConfirmation = false

    init(dependencies: AppDependencies) {
        _viewModel = StateObject(wrappedValue: InventoryViewModel(dependencies: dependencies))
    }

    var body: some View {
        NavigationView {
            content
                .harborScreenBackground()
                .navigationTitle("Inventory")
                .navigationBarTitleDisplayMode(.large)
                .toolbar { toolbarContent }
                .searchable(text: $viewModel.searchText, prompt: "Search products, tags or notes")
        }
        .navigationViewStyle(.stack)
        .harborToast($viewModel.toast)
        .sheet(isPresented: $showAddProduct) {
            NavigationView {
                ProductFormView(dependencies: dependencies, mode: .create) { _ in
                    showAddProduct = false
                }
            }
            .navigationViewStyle(.stack)
            .environmentObject(dependencies)
        }
        .sheet(isPresented: $showMoveSheet) {
            NavigationView {
                ZonePickerView(
                    zones: viewModel.zones,
                    title: "Move \(viewModel.selection.count) product\(viewModel.selection.count == 1 ? "" : "s")"
                ) { zoneId in
                    Task {
                        await viewModel.move(to: zoneId)
                        showMoveSheet = false
                    }
                }
            }
            .navigationViewStyle(.stack)
        }
        .alert("Delete selected products?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteSelected() }
            }
        } message: {
            Text("\(viewModel.selection.count) product\(viewModel.selection.count == 1 ? "" : "s") and their photos will be removed. Their history entries stay.")
        }
        .sheet(item: $viewModel.mergePrompt) { prompt in
            NavigationView {
                MergeConfirmationView(prompt: prompt) {
                    Task { await viewModel.confirmMerge(prompt) }
                } onCancel: {
                    viewModel.mergePrompt = nil
                }
            }
            .navigationViewStyle(.stack)
        }
    }

    // MARK: - States

    @ViewBuilder
    private var content: some View {
        if viewModel.loadState.isLoading {
            LoadingStateView()
                .frame(maxHeight: .infinity)
        } else if let failure = viewModel.loadState.failureMessage, viewModel.isEmptyPantry {
            ErrorStateView(message: failure) {
                Task { await dependencies.store.load() }
            }
            .frame(maxHeight: .infinity)
        } else if viewModel.isEmptyPantry {
            ScrollView {
                VStack(spacing: HarborMetrics.spacingM) {
                    if let reason = viewModel.loadState.cachedReason {
                        CachedDataBanner(message: reason)
                    }
                    EmptyStateView(
                        title: "Nothing stored yet",
                        message: "Add the products you already have at home. Each one keeps its own quantity, storage zone and the use-by date you choose.",
                        illustration: .productCrate,
                        illustrationWidth: 240,
                        actionTitle: "Add Product",
                        action: { showAddProduct = true }
                    )
                    UserDataNotice()
                }
                .padding(HarborMetrics.spacingL)
            }
        } else {
            populatedList
        }
    }

    private var populatedList: some View {
        ScrollView {
            LazyVStack(spacing: HarborMetrics.spacingM) {
                if let reason = viewModel.loadState.cachedReason {
                    CachedDataBanner(message: reason)
                }
                if let error = viewModel.errorMessage {
                    ErrorStateView(message: error)
                }

                filters

                if viewModel.filteredProducts.isEmpty {
                    EmptyStateView(
                        title: "No matches",
                        message: "No product fits this search and filter. Try a different filter or clear the search."
                    )
                } else {
                    ForEach(viewModel.filteredProducts) { product in
                        productRow(product)
                    }
                }
            }
            .padding(.horizontal, HarborMetrics.spacingL)
            .padding(.bottom, viewModel.isSelecting ? 90 : HarborMetrics.spacingXL)
            .padding(.top, HarborMetrics.spacingS)
        }
        .overlay(alignment: .bottom) {
            if viewModel.isSelecting && !viewModel.selection.isEmpty {
                bulkBar
            }
        }
    }

    @ViewBuilder
    private func productRow(_ product: Product) -> some View {
        if viewModel.isSelecting {
            Button {
                viewModel.toggleSelection(product.id)
            } label: {
                row(product)
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink {
                ProductDetailsView(dependencies: dependencies, productId: product.id)
            } label: {
                row(product)
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("Mark Used") {
                    Task { await viewModel.markUsed(product) }
                }
                Button("Merge Duplicates") {
                    viewModel.checkForMerge(product)
                }
            }
        }
    }

    private func row(_ product: Product) -> some View {
        ProductRowView(
            product: product,
            zoneName: viewModel.zoneName(for: product),
            bucket: viewModel.bucket(for: product),
            daysText: viewModel.daysText(for: product),
            isSelected: viewModel.selection.contains(product.id),
            isSelecting: viewModel.isSelecting,
            photoStore: dependencies.photoStore
        )
    }

    private var filters: some View {
        VStack(spacing: HarborMetrics.spacingS) {
            ChipPicker(
                items: InventoryViewModel.Filter.allCases,
                title: { $0.displayName },
                selection: $viewModel.filter
            )

            if !viewModel.availableCategories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: HarborMetrics.spacingS) {
                        categoryChip(nil, label: "All categories")
                        ForEach(viewModel.availableCategories) { category in
                            categoryChip(category, label: category.displayName)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func categoryChip(_ category: ProductCategory?, label: String) -> some View {
        let isSelected = viewModel.categoryFilter == category
        return Button {
            viewModel.categoryFilter = isSelected ? nil : category
        } label: {
            HStack(spacing: 5) {
                if let category = category {
                    Image(systemName: category.symbolName)
                        .font(.system(size: 11, weight: .bold))
                }
                Text(label)
                    .font(HarborFont.caption(12.5))
            }
            .foregroundColor(isSelected ? .white : HarborColor.textSecondary)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(
                    isSelected ? AnyShapeStyle(HarborGradient.ocean) : AnyShapeStyle(HarborColor.surface)
                )
            )
            .overlay(
                Capsule().strokeBorder(isSelected ? .clear : HarborColor.separator, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var bulkBar: some View {
        HStack(spacing: HarborMetrics.spacingS) {
            Text("\(viewModel.selection.count) selected")
                .font(HarborFont.caption(13))
                .foregroundColor(HarborColor.textSecondary)
            Spacer()
            Button("Move") { showMoveSheet = true }
                .buttonStyle(HarborChipButtonStyle())
            Button("Archive") {
                Task { await viewModel.archiveSelected() }
            }
            .buttonStyle(HarborChipButtonStyle(tint: HarborPalette.sunGold))
            Button("Delete") { showDeleteConfirmation = true }
                .buttonStyle(HarborChipButtonStyle(tint: HarborPalette.coral))
        }
        .padding(.horizontal, HarborMetrics.spacingM)
        .padding(.vertical, HarborMetrics.spacingS)
        .background(
            RoundedRectangle(cornerRadius: HarborMetrics.cardRadius, style: .continuous)
                .fill(HarborColor.surface)
        )
        .harborShadow()
        .padding(.horizontal, HarborMetrics.spacingL)
        .padding(.bottom, HarborMetrics.spacingS)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            if !viewModel.isEmptyPantry {
                Button(viewModel.isSelecting ? "Done" : "Select") {
                    if viewModel.isSelecting {
                        viewModel.clearSelection()
                    } else {
                        viewModel.isSelecting = true
                    }
                }
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: HarborMetrics.spacingM) {
                NavigationLink {
                    FreshnessCalendarView(dependencies: dependencies)
                } label: {
                    Image(systemName: "calendar")
                }
                NavigationLink {
                    StorageZonesView(dependencies: dependencies)
                } label: {
                    Image(systemName: "square.stack.3d.up")
                }
                Button {
                    showAddProduct = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
    }
}

/// Reusable zone chooser used by move actions.
struct ZonePickerView: View {
    let zones: [StorageZone]
    let title: String
    let onPick: (UUID) -> Void

    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        ScrollView {
            VStack(spacing: HarborMetrics.spacingS) {
                ForEach(zones) { zone in
                    Button {
                        onPick(zone.id)
                    } label: {
                        HStack(spacing: HarborMetrics.spacingM) {
                            HarborStorageIcon(type: zone.type)
                                .foregroundColor(HarborColor.accent)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(HarborColor.accent.opacity(0.12)))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(zone.name)
                                    .font(HarborFont.headline(15))
                                    .foregroundColor(HarborColor.textPrimary)
                                Text(zone.type.displayName)
                                    .font(HarborFont.caption(11.5))
                                    .foregroundColor(HarborColor.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(HarborColor.textSecondary.opacity(0.6))
                        }
                        .padding(HarborMetrics.spacingM)
                        .background(
                            RoundedRectangle(cornerRadius: HarborMetrics.cardRadius, style: .continuous)
                                .fill(HarborColor.surface)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(HarborMetrics.spacingL)
        }
        .harborScreenBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { presentationMode.wrappedValue.dismiss() }
            }
        }
    }
}

/// Duplicate rows are only combined after the user confirms this summary.
struct MergeConfirmationView: View {
    let prompt: InventoryViewModel.MergePrompt
    let onConfirm: () -> Void
    let onCancel: () -> Void

    private var total: Double {
        prompt.candidates.reduce(prompt.primary.quantity) { $0 + $1.quantity }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: HarborMetrics.spacingM) {
                HarborCard {
                    VStack(alignment: .leading, spacing: HarborMetrics.spacingS) {
                        Text("Merge duplicates?")
                            .font(HarborFont.title(20))
                            .foregroundColor(HarborColor.textPrimary)
                        Text("These rows share a name, unit and storage zone. Merging adds their quantities together and keeps the earliest use-by date you entered.")
                            .font(HarborFont.body(14))
                            .foregroundColor(HarborColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HarborCard {
                    VStack(alignment: .leading, spacing: HarborMetrics.spacingS) {
                        rowLine(prompt.primary, label: "Keeps")
                        ForEach(prompt.candidates) { candidate in
                            rowLine(candidate, label: "Merged in")
                        }
                        Divider().background(HarborColor.separator)
                        HStack {
                            Text("Result")
                                .font(HarborFont.headline(15))
                                .foregroundColor(HarborColor.textPrimary)
                            Spacer()
                            Text(HarborFormat.quantity(total, prompt.primary.unit))
                                .font(HarborFont.numeric(16))
                                .foregroundColor(HarborColor.accent)
                        }
                    }
                }

                Button("Merge") { onConfirm() }
                    .buttonStyle(HarborPrimaryButtonStyle())
                Button("Keep Separate") { onCancel() }
                    .buttonStyle(HarborSecondaryButtonStyle())
            }
            .padding(HarborMetrics.spacingL)
        }
        .harborScreenBackground()
        .navigationTitle("Merge")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func rowLine(_ product: Product, label: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(product.trimmedName)
                    .font(HarborFont.body(15))
                    .foregroundColor(HarborColor.textPrimary)
                Text(label)
                    .font(HarborFont.caption(11))
                    .foregroundColor(HarborColor.textSecondary)
            }
            Spacer()
            Text(HarborFormat.quantity(product.quantity, product.unit))
                .font(HarborFont.caption(13))
                .foregroundColor(HarborColor.textSecondary)
        }
    }
}
