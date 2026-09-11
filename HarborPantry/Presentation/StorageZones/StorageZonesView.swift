//
//  StorageZonesView.swift
//  HarborPantry
//
//  Screen 9 — the zones themselves, what is in them and how full they are.
//

import SwiftUI

struct StorageZonesView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var viewModel: StorageZonesViewModel

    @State private var editingZone: StorageZone?
    @State private var showAddZone = false
    @State private var zonePendingDeletion: StorageZone?
    @State private var movingZone: StorageZone?

    init(dependencies: AppDependencies) {
        _viewModel = StateObject(wrappedValue: StorageZonesViewModel(dependencies: dependencies))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: HarborMetrics.spacingM) {
                ScreenHeader(
                    title: "Storage Zones",
                    subtitle: "Capacity is an organising hint — Harbor Pantry does not monitor temperature.",
                    illustration: .storageCabinet,
                    illustrationWidth: 130
                )
                .padding(.top, HarborMetrics.spacingS)

                if let error = viewModel.errorMessage {
                    ErrorStateView(message: error)
                }

                if viewModel.rows.isEmpty {
                    EmptyStateView(
                        title: "No zones yet",
                        message: "Add the places you actually store food: a fridge, a freezer, a cupboard, or anything else you use.",
                        actionTitle: "Add Zone",
                        action: { showAddZone = true }
                    )
                } else {
                    ForEach(viewModel.rows) { row in
                        zoneCard(row)
                    }

                    Button("Add Zone") { showAddZone = true }
                        .buttonStyle(HarborSecondaryButtonStyle())
                }
            }
            .padding(.horizontal, HarborMetrics.spacingL)
            .padding(.bottom, HarborMetrics.spacingXL)
        }
        .harborScreenBackground()
        .navigationTitle("Storage Zones")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddZone) {
            NavigationView {
                ZoneFormView(dependencies: dependencies, zone: nil) { showAddZone = false }
            }
            .navigationViewStyle(.stack)
            .environmentObject(dependencies)
        }
        .sheet(item: $editingZone) { zone in
            NavigationView {
                ZoneFormView(dependencies: dependencies, zone: zone) { editingZone = nil }
            }
            .navigationViewStyle(.stack)
            .environmentObject(dependencies)
        }
        .sheet(item: $movingZone) { zone in
            NavigationView {
                MoveZoneContentsView(
                    sourceZone: zone,
                    zones: viewModel.otherZones.filter { $0.id != zone.id },
                    productCount: viewModel.products(in: zone.id).count
                ) { destination in
                    Task {
                        await viewModel.moveAllProducts(from: zone.id, to: destination)
                        movingZone = nil
                    }
                }
            }
            .navigationViewStyle(.stack)
        }
        .alert(item: $zonePendingDeletion) { zone in
            Alert(
                title: Text("Delete “\(zone.name)”?"),
                message: Text("This zone is empty, so nothing will be lost."),
                primaryButton: .destructive(Text("Delete")) {
                    Task { await viewModel.delete(zone: zone) }
                },
                secondaryButton: .cancel()
            )
        }
    }

    private func zoneCard(_ row: StorageZonesViewModel.ZoneRow) -> some View {
        HarborCard {
            VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                HStack(spacing: HarborMetrics.spacingM) {
                    HarborStorageIcon(type: row.zone.type, size: 32)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 42, height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(HarborGradient.ocean)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.zone.name)
                            .font(HarborFont.headline(17))
                            .foregroundColor(HarborColor.textPrimary)
                        Text(row.zone.type.displayName)
                            .font(HarborFont.caption(12))
                            .foregroundColor(HarborColor.textSecondary)
                    }
                    Spacer()
                    if row.zone.isArchived {
                        StatusPill(text: "Archived", color: HarborColor.textSecondary)
                    }
                }

                HStack(spacing: HarborMetrics.spacingS) {
                    StatusPill(
                        text: "\(row.productCount) product\(row.productCount == 1 ? "" : "s")",
                        systemImage: "shippingbox",
                        color: HarborColor.accent
                    )
                    if row.useSoonCount > 0 {
                        StatusPill(
                            text: "\(row.useSoonCount) use soon",
                            systemImage: "clock",
                            color: HarborPalette.sunGold
                        )
                    }
                }

                if let ratio = row.fillRatio, let capacity = row.zone.capacity {
                    VStack(alignment: .leading, spacing: 4) {
                        HarborProgressBar(value: ratio, tint: HarborColor.accentSoft, height: 8)
                        Text("\(row.productCount) of \(capacity) slots used — a guide you set, not a limit.")
                            .font(HarborFont.caption(11))
                            .foregroundColor(HarborColor.textSecondary)
                    }
                }

                if !row.zone.note.isEmpty {
                    Text(row.zone.note)
                        .font(HarborFont.caption(12))
                        .foregroundColor(HarborColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider().background(HarborColor.separator)

                HStack(spacing: HarborMetrics.spacingS) {
                    NavigationLink {
                        ZoneContentsView(zone: row.zone, dependencies: dependencies)
                    } label: {
                        Text("Open")
                            .font(HarborFont.caption(13))
                            .foregroundColor(HarborColor.accent)
                            .padding(.horizontal, HarborMetrics.spacingM)
                            .padding(.vertical, HarborMetrics.spacingS)
                            .frame(minHeight: 34)
                            .background(Capsule().fill(HarborColor.accent.opacity(0.13)))
                    }

                    Button("Rename") { editingZone = row.zone }
                        .buttonStyle(HarborChipButtonStyle())

                    if row.productCount > 0 {
                        Button("Move Products") { movingZone = row.zone }
                            .buttonStyle(HarborChipButtonStyle(tint: HarborPalette.sunGold))
                    }

                    Spacer()

                    Menu {
                        Button(row.zone.isArchived ? "Restore" : "Archive") {
                            Task { await viewModel.setArchived(!row.zone.isArchived, zone: row.zone) }
                        }
                        Button("Delete", role: .destructive) {
                            if row.productCount > 0 {
                                movingZone = row.zone
                            } else {
                                zonePendingDeletion = row.zone
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 19))
                            .foregroundColor(HarborColor.textSecondary)
                            .frame(width: 34, height: 34)
                    }
                }
            }
        }
    }
}

/// The contents of a single zone.
struct ZoneContentsView: View {
    let zone: StorageZone
    @StateObject private var viewModel: StorageZonesViewModel
    private let dependencies: AppDependencies

    init(zone: StorageZone, dependencies: AppDependencies) {
        self.zone = zone
        self.dependencies = dependencies
        _viewModel = StateObject(wrappedValue: StorageZonesViewModel(dependencies: dependencies))
    }

    var body: some View {
        let products = viewModel.products(in: zone.id)
        ScrollView {
            VStack(spacing: HarborMetrics.spacingM) {
                if products.isEmpty {
                    EmptyStateView(
                        title: "\(zone.name) is empty",
                        message: "Products you store here will show up in this list."
                    )
                } else {
                    ForEach(products) { product in
                        NavigationLink {
                            ProductDetailsView(dependencies: dependencies, productId: product.id)
                        } label: {
                            ProductRowView(
                                product: product,
                                zoneName: zone.name,
                                bucket: dependencies.freshnessService.bucket(for: product),
                                daysText: dependencies.freshnessService.daysRemaining(for: product)
                                    .map(HarborFormat.relativeDays) ?? "No date"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, HarborMetrics.spacingL)
            .padding(.vertical, HarborMetrics.spacingM)
        }
        .harborScreenBackground()
        .navigationTitle(zone.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Asks where the contents of a zone should go before the zone is removed.
struct MoveZoneContentsView: View {
    let sourceZone: StorageZone
    let zones: [StorageZone]
    let productCount: Int
    let onMove: (UUID) -> Void

    @Environment(\.presentationMode) private var presentationMode
    @State private var destination: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                HarborCard {
                    VStack(alignment: .leading, spacing: HarborMetrics.spacingS) {
                        Text("Move \(productCount) product\(productCount == 1 ? "" : "s")")
                            .font(HarborFont.title(20))
                            .foregroundColor(HarborColor.textPrimary)
                        Text("A zone that still holds products cannot be deleted. Choose where these should go.")
                            .font(HarborFont.body(14))
                            .foregroundColor(HarborColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if zones.isEmpty {
                    EmptyStateView(
                        title: "No other zone",
                        message: "Create another storage zone first, then move these products into it."
                    )
                } else {
                    ForEach(zones) { zone in
                        Button {
                            destination = zone.id
                        } label: {
                            HStack {
                                HarborStorageIcon(type: zone.type)
                                    .foregroundColor(HarborColor.accent)
                                Text(zone.name)
                                    .font(HarborFont.headline(15))
                                    .foregroundColor(HarborColor.textPrimary)
                                Spacer()
                                if destination == zone.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(HarborColor.accent)
                                }
                            }
                            .padding(HarborMetrics.spacingM)
                            .background(
                                RoundedRectangle(cornerRadius: HarborMetrics.controlRadius, style: .continuous)
                                    .fill(HarborColor.surface)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Button("Move Products") {
                        if let destination = destination { onMove(destination) }
                    }
                    .buttonStyle(HarborPrimaryButtonStyle(isEnabled: destination != nil))
                    .disabled(destination == nil)
                }
            }
            .padding(HarborMetrics.spacingL)
        }
        .harborScreenBackground()
        .navigationTitle("Move Products")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { presentationMode.wrappedValue.dismiss() }
            }
        }
    }
}
