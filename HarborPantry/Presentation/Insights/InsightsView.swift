//
//  InsightsView.swift
//  HarborPantry
//
//  Screen 15a — Insights. Locked until three weeks of real activity exist, and
//  every figure links back to the records it came from.
//

import SwiftUI

struct InsightsView: View {
    @StateObject private var viewModel: InsightsViewModel

    init(dependencies: AppDependencies) {
        _viewModel = StateObject(wrappedValue: InsightsViewModel(dependencies: dependencies))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: HarborMetrics.spacingM) {
                if viewModel.availability.isAvailable {
                    periodPicker
                    headlineCard
                    breakdownCard(
                        title: "Most Often Discarded",
                        subtitle: "Categories you threw away in this window.",
                        metrics: viewModel.summary.discardedByCategory,
                        tint: HarborPalette.coral
                    )
                    breakdownCard(
                        title: "What You Buy",
                        subtitle: "Purchases you recorded, by category.",
                        metrics: viewModel.summary.purchasesByCategory,
                        tint: HarborColor.accent
                    )
                    breakdownCard(
                        title: "Popular Dishes",
                        subtitle: "Dishes you planned most often.",
                        metrics: viewModel.summary.popularDishes,
                        tint: HarborPalette.leaf
                    )
                } else {
                    lockedState
                }
            }
            .padding(.horizontal, HarborMetrics.spacingL)
            .padding(.vertical, HarborMetrics.spacingM)
        }
        .harborScreenBackground()
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $viewModel.sourceMetric) { metric in
            NavigationView {
                MetricSourceView(
                    metric: metric,
                    entries: viewModel.sourceEntries(for: metric)
                )
            }
            .navigationViewStyle(.stack)
        }
    }

    private var periodPicker: some View {
        Picker("Period", selection: $viewModel.period) {
            ForEach(InsightsPeriod.allCases) { period in
                Text(period.displayName).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    private var lockedState: some View {
        VStack(spacing: HarborMetrics.spacingM) {
            EmptyStateView(
                title: "Complete More Weeks",
                message: "Insights unlock after three completed weeks of real activity. You have \(viewModel.weeksCompleted) so far — Harbor Pantry will not fill the gap with estimates.",
                illustration: .summaryLighthouse,
                illustrationWidth: 180
            )

            HarborCard {
                VStack(alignment: .leading, spacing: HarborMetrics.spacingS) {
                    Text("Progress")
                        .font(HarborFont.headline(16))
                        .foregroundColor(HarborColor.textPrimary)
                    HarborProgressBar(
                        value: Double(viewModel.weeksCompleted) / Double(InsightsService.requiredWeeks)
                    )
                    Text("\(viewModel.weeksCompleted) of \(InsightsService.requiredWeeks) weeks")
                        .font(HarborFont.caption(12))
                        .foregroundColor(HarborColor.textSecondary)
                }
            }
        }
    }

    private var headlineCard: some View {
        HarborCard {
            VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                SectionHeader(
                    title: "Stock Usage",
                    subtitle: "Of everything you closed out, how much was actually used."
                )
                HStack(spacing: HarborMetrics.spacingL) {
                    statTile(
                        value: "\(Int(viewModel.summary.stockUsageRate * 100))%",
                        label: "used",
                        tint: HarborPalette.leaf
                    )
                    statTile(
                        value: "\(viewModel.summary.discardedCount)",
                        label: "discarded",
                        tint: HarborPalette.coral
                    )
                    statTile(
                        value: viewModel.summary.averageItemsPerShoppingTrip.quantityText,
                        label: "items / trip",
                        tint: HarborColor.accent
                    )
                }
                HarborProgressBar(value: viewModel.summary.stockUsageRate, tint: HarborPalette.leaf)
            }
        }
    }

    private func statTile(value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(HarborFont.numeric(22))
                .foregroundColor(tint)
            Text(label)
                .font(HarborFont.caption(11))
                .foregroundColor(HarborColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func breakdownCard(
        title: String,
        subtitle: String,
        metrics: [InsightMetric],
        tint: Color
    ) -> some View {
        HarborCard {
            VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                SectionHeader(title: title, subtitle: subtitle)

                if metrics.isEmpty {
                    Text("Nothing recorded in this window.")
                        .font(HarborFont.body(14))
                        .foregroundColor(HarborColor.textSecondary)
                } else {
                    let maximum = metrics.map(\.value).max() ?? 1
                    ForEach(metrics) { metric in
                        Button {
                            viewModel.sourceMetric = metric
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(metric.label)
                                        .font(HarborFont.body(14))
                                        .foregroundColor(HarborColor.textPrimary)
                                    Spacer()
                                    Text("\(metric.value.quantityText) \(metric.unitLabel)")
                                        .font(HarborFont.caption(12))
                                        .foregroundColor(HarborColor.textSecondary)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(HarborColor.textSecondary.opacity(0.6))
                                }
                                HarborProgressBar(
                                    value: maximum > 0 ? metric.value / maximum : 0,
                                    tint: tint,
                                    height: 7
                                )
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    Text("Tap any row to see the entries it came from.")
                        .font(HarborFont.caption(11))
                        .foregroundColor(HarborColor.textSecondary)
                }
            }
        }
    }
}

/// The records behind a single metric.
struct MetricSourceView: View {
    let metric: InsightMetric
    let entries: [ProductHistoryEntry]

    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        ScrollView {
            VStack(spacing: HarborMetrics.spacingM) {
                HarborCard {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(metric.label)
                            .font(HarborFont.title(20))
                            .foregroundColor(HarborColor.textPrimary)
                        Text("\(metric.value.quantityText) \(metric.unitLabel) · \(entries.count) source record\(entries.count == 1 ? "" : "s")")
                            .font(HarborFont.caption(12))
                            .foregroundColor(HarborColor.textSecondary)
                    }
                }

                if entries.isEmpty {
                    EmptyStateView(
                        title: "No source records",
                        message: "The entries behind this number are no longer stored."
                    )
                } else {
                    HarborCard {
                        VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                            ForEach(entries.sorted { $0.createdAt > $1.createdAt }) { entry in
                                HStack(alignment: .top, spacing: HarborMetrics.spacingM) {
                                    Image(systemName: entry.kind.symbolName)
                                        .foregroundColor(HarborColor.accent)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(entry.productName)
                                            .font(HarborFont.headline(14))
                                            .foregroundColor(HarborColor.textPrimary)
                                        Text("\(entry.kind.displayName) · \(HarborFormat.dateTime.string(from: entry.createdAt))")
                                            .font(HarborFont.caption(11))
                                            .foregroundColor(HarborColor.textSecondary)
                                    }
                                    Spacer()
                                    if let delta = entry.quantityDelta, let unit = entry.unit {
                                        Text("\(delta.quantityText) \(unit.shortLabel)")
                                            .font(HarborFont.caption(11.5))
                                            .foregroundColor(HarborColor.textSecondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(HarborMetrics.spacingL)
        }
        .harborScreenBackground()
        .navigationTitle("Source")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { presentationMode.wrappedValue.dismiss() }
            }
        }
    }
}
