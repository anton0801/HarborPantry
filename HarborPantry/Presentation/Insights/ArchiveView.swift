//
//  ArchiveView.swift
//  HarborPantry
//
//  Screen 15b — archived products, dishes and past plans.
//

import SwiftUI

struct ArchiveView: View {
    @StateObject private var viewModel: ArchiveViewModel

    init(dependencies: AppDependencies) {
        _viewModel = StateObject(wrappedValue: ArchiveViewModel(dependencies: dependencies))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: HarborMetrics.spacingM) {
                if let error = viewModel.errorMessage {
                    ErrorStateView(message: error)
                }

                if viewModel.isEmpty {
                    EmptyStateView(
                        title: "Archive is empty",
                        message: "Products and dishes you archive, and days that have already passed, gather here so nothing is lost.",
                        illustration: .archiveChest,
                        illustrationWidth: 180
                    )
                } else {
                    if !viewModel.archivedProducts.isEmpty {
                        HarborCard {
                            VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                                SectionHeader(title: "Archived Products")
                                ForEach(viewModel.archivedProducts) { product in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(product.trimmedName)
                                                .font(HarborFont.headline(15))
                                                .foregroundColor(HarborColor.textPrimary)
                                            Text(HarborFormat.quantity(product.quantity, product.unit))
                                                .font(HarborFont.caption(11.5))
                                                .foregroundColor(HarborColor.textSecondary)
                                        }
                                        Spacer()
                                        Button("Restore") {
                                            Task { await viewModel.restore(product: product) }
                                        }
                                        .buttonStyle(HarborChipButtonStyle())
                                    }
                                }
                            }
                        }
                    }

                    if !viewModel.archivedDishes.isEmpty {
                        HarborCard {
                            VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                                SectionHeader(title: "Archived Dishes")
                                ForEach(viewModel.archivedDishes) { dish in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(dish.trimmedName)
                                                .font(HarborFont.headline(15))
                                                .foregroundColor(HarborColor.textPrimary)
                                            Text("\(dish.ingredients.count) ingredient\(dish.ingredients.count == 1 ? "" : "s")")
                                                .font(HarborFont.caption(11.5))
                                                .foregroundColor(HarborColor.textSecondary)
                                        }
                                        Spacer()
                                        Button("Restore") {
                                            Task { await viewModel.restore(dish: dish) }
                                        }
                                        .buttonStyle(HarborChipButtonStyle())
                                    }
                                }
                            }
                        }
                    }

                    if !viewModel.pastMeals.isEmpty {
                        HarborCard {
                            VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                                SectionHeader(title: "Past Plans")
                                ForEach(viewModel.pastMeals.prefix(40)) { entry in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(viewModel.dishName(entry.dishId))
                                                .font(HarborFont.body(14))
                                                .foregroundColor(HarborColor.textPrimary)
                                            Text("\(entry.slotTitle) · \(HarborFormat.fullDate.string(from: entry.date))")
                                                .font(HarborFont.caption(11))
                                                .foregroundColor(HarborColor.textSecondary)
                                        }
                                        Spacer()
                                        Text("\(entry.totalServings)")
                                            .font(HarborFont.numeric(14))
                                            .foregroundColor(HarborColor.textSecondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, HarborMetrics.spacingL)
            .padding(.vertical, HarborMetrics.spacingM)
        }
        .harborScreenBackground()
        .navigationTitle("Archive")
        .navigationBarTitleDisplayMode(.inline)
        .harborToast($viewModel.toast)
    }
}
