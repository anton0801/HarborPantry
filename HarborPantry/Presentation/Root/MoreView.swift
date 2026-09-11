//
//  MoreView.swift
//  HarborPantry
//
//  The fifth tab — everything that does not need its own tab.
//

import SwiftUI

struct MoreView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @State private var showProfile = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: HarborMetrics.spacingM) {
                    header

                    HarborCard {
                        VStack(spacing: 0) {
                            navigationRow(
                                title: "Prep & Leftovers",
                                subtitle: "Line up thawing and cooking, log what is left",
                                symbol: "timer"
                            ) {
                                PrepTimelineView(dependencies: dependencies)
                            }
                            separator
                            navigationRow(
                                title: "Freshness Calendar",
                                subtitle: "Your dates, grouped by how soon they land",
                                symbol: "calendar"
                            ) {
                                FreshnessCalendarView(dependencies: dependencies)
                            }
                            separator
                            navigationRow(
                                title: "Storage Zones",
                                subtitle: "Fridge, freezer, cupboards and your own places",
                                symbol: "square.stack.3d.up"
                            ) {
                                StorageZonesView(dependencies: dependencies)
                            }
                        }
                    }

                    HarborCard {
                        VStack(spacing: 0) {
                            navigationRow(
                                title: "Insights",
                                subtitle: "Unlocks after three completed weeks",
                                symbol: "chart.bar"
                            ) {
                                InsightsView(dependencies: dependencies)
                            }
                            separator
                            navigationRow(
                                title: "Archive",
                                subtitle: "Archived products, dishes and past plans",
                                symbol: "archivebox"
                            ) {
                                ArchiveView(dependencies: dependencies)
                            }
                        }
                    }

                    HarborCard {
                        VStack(spacing: 0) {
                            Button {
                                showProfile = true
                            } label: {
                                rowLabel(
                                    title: "Pantry Profile",
                                    subtitle: "Household size, units, currency and zones",
                                    symbol: "person.2"
                                )
                            }
                            .buttonStyle(.plain)
                            separator
                            navigationRow(
                                title: "Settings",
                                subtitle: "Reminders, export, import and data",
                                symbol: "gearshape"
                            ) {
                                SettingsView(dependencies: dependencies)
                            }
                        }
                    }

                    UserDataNotice()
                }
                .padding(.horizontal, HarborMetrics.spacingL)
                .padding(.bottom, HarborMetrics.spacingXL)
            }
            .harborScreenBackground()
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showProfile) {
            NavigationView {
                PantryProfileView(dependencies: dependencies, mode: .edit) {
                    showProfile = false
                }
            }
            .navigationViewStyle(.stack)
            .environmentObject(dependencies)
        }
    }

    private var header: some View {
        HStack(spacing: HarborMetrics.spacingM) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Everything else")
                    .font(HarborFont.title(24))
                    .foregroundColor(HarborColor.textPrimary)
                Text("Prep, insights and the settings behind your pantry.")
                    .font(HarborFont.caption(12.5))
                    .foregroundColor(HarborColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            HarborIllustrationView(illustration: .summaryLighthouse)
                .frame(width: 96)
        }
        .padding(.top, HarborMetrics.spacingS)
    }

    private var separator: some View {
        Divider()
            .background(HarborColor.separator)
            .padding(.vertical, 2)
    }

    private func navigationRow<Destination: View>(
        title: String,
        subtitle: String,
        symbol: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination()) {
            rowLabel(title: title, subtitle: subtitle, symbol: symbol)
        }
        .buttonStyle(.plain)
    }

    private func rowLabel(title: String, subtitle: String, symbol: String) -> some View {
        HStack(spacing: HarborMetrics.spacingM) {
            menuIcon(symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(HarborGradient.ocean)
                )
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(HarborFont.headline(16))
                    .foregroundColor(HarborColor.textPrimary)
                Text(subtitle)
                    .font(HarborFont.caption(11.5))
                    .foregroundColor(HarborColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(HarborColor.textSecondary.opacity(0.6))
        }
        .padding(.vertical, HarborMetrics.spacingS)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func menuIcon(_ symbol: String) -> some View {
        if let illustration = menuIllustration(symbol) {
            HarborIllustrationView(illustration: illustration)
                .frame(width: 30, height: 30)
        } else {
            Image(systemName: symbol)
        }
    }

    private func menuIllustration(_ symbol: String) -> HarborIllustration? {
        switch symbol {
        case "timer": return .prepClock
        case "calendar": return .freshnessCalendar
        case "square.stack.3d.up": return .storageCabinet
        case "chart.bar": return .summaryLighthouse
        case "archivebox": return .archiveChest
        case "person.2": return .profileCreel
        case "gearshape": return .settingsCompass
        default: return nil
        }
    }
}
