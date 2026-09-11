//
//  FreshnessCalendarView.swift
//  HarborPantry
//
//  Screen 10 — products grouped by the dates the user entered. Future dates
//  are never styled as a problem, and a missing date is never filled in.
//

import SwiftUI

struct FreshnessCalendarView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var viewModel: FreshnessCalendarViewModel

    @State private var dateEditProduct: Product?
    @State private var pendingDate = Date()

    init(dependencies: AppDependencies) {
        _viewModel = StateObject(
            wrappedValue: FreshnessCalendarViewModel(dependencies: dependencies)
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: HarborMetrics.spacingM) {
                header

                if let message = viewModel.reminderMessage {
                    CachedDataBanner(message: message)
                }
                if let error = viewModel.errorMessage {
                    ErrorStateView(message: error)
                }

                Picker("View", selection: $viewModel.presentation) {
                    ForEach(FreshnessCalendarViewModel.Presentation.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                if viewModel.isEmpty {
                    EmptyStateView(
                        title: "No dated products yet",
                        message: "Once you add products and give them your own use-by dates, they gather here by how soon you plan to use them."
                    )
                } else if viewModel.presentation == .list {
                    listContent
                } else {
                    calendarContent
                }

                UserDataNotice(
                    text: "Grouping is based only on the dates you typed. Harbor Pantry never estimates a date and never rules on whether food is safe."
                )
            }
            .padding(.horizontal, HarborMetrics.spacingL)
            .padding(.bottom, HarborMetrics.spacingXL)
        }
        .harborScreenBackground()
        .navigationTitle("Freshness")
        .navigationBarTitleDisplayMode(.inline)
        .harborToast($viewModel.toast)
        .sheet(item: $dateEditProduct) { product in
            NavigationView {
                AdjustDateView(
                    product: product,
                    initialDate: product.useByDate ?? Date()
                ) { newDate in
                    Task {
                        await viewModel.adjustDate(for: product, to: newDate)
                        dateEditProduct = nil
                    }
                }
            }
            .navigationViewStyle(.stack)
        }
    }

    private var header: some View {
        ScreenHeader(
            title: "Freshness Calendar",
            subtitle: "Your dates, grouped by how soon they arrive.",
            illustration: .freshnessCalendar,
            illustrationWidth: 112
        )
        .padding(.top, HarborMetrics.spacingS)
    }

    // MARK: - List

    private var listContent: some View {
        VStack(spacing: HarborMetrics.spacingM) {
            ForEach(viewModel.orderedBuckets, id: \.self) { bucket in
                HarborCard {
                    VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                        HStack(spacing: HarborMetrics.spacingS) {
                            Image(systemName: bucket.symbolName)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(HarborColor.bucket(bucket))
                            Text(bucket.displayName)
                                .font(HarborFont.headline(17))
                                .foregroundColor(HarborColor.textPrimary)
                            Spacer()
                            Text("\(viewModel.products(in: bucket).count)")
                                .font(HarborFont.numeric(15))
                                .foregroundColor(HarborColor.textSecondary)
                        }

                        if bucket == .missingDate {
                            Text("These have no date yet. Add one when you are ready — nothing is assumed for you.")
                                .font(HarborFont.caption(11.5))
                                .foregroundColor(HarborColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        ForEach(viewModel.products(in: bucket)) { product in
                            productRow(product, bucket: bucket)
                        }
                    }
                }
            }
        }
    }

    private func productRow(_ product: Product, bucket: FreshnessBucket) -> some View {
        VStack(alignment: .leading, spacing: HarborMetrics.spacingS) {
            HStack(spacing: HarborMetrics.spacingM) {
                NavigationLink {
                    ProductDetailsView(dependencies: dependencies, productId: product.id)
                } label: {
                    HStack(spacing: HarborMetrics.spacingM) {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(HarborColor.bucket(bucket).opacity(0.15))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: product.category.symbolName)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(HarborColor.bucket(bucket))
                            )
                        VStack(alignment: .leading, spacing: 1) {
                            Text(product.trimmedName)
                                .font(HarborFont.headline(15))
                                .foregroundColor(HarborColor.textPrimary)
                                .lineLimit(1)
                            Text("\(HarborFormat.quantity(product.quantity, product.unit)) · \(viewModel.zoneName(for: product))")
                                .font(HarborFont.caption(11.5))
                                .foregroundColor(HarborColor.textSecondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 4)
                        Text(viewModel.daysText(for: product))
                            .font(HarborFont.caption(12))
                            .foregroundColor(HarborColor.bucket(bucket))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            let meals = viewModel.linkedMealNames(for: product)
            if !meals.isEmpty {
                Text("Planned in: \(meals.joined(separator: ", "))")
                    .font(HarborFont.caption(11))
                    .foregroundColor(HarborColor.accent)
                    .lineLimit(1)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: HarborMetrics.spacingS) {
                    Button(product.hasUseByDate ? "Adjust Date" : "Add Date") {
                        dateEditProduct = product
                    }
                    .buttonStyle(HarborChipButtonStyle())

                    Button("Mark Used") {
                        Task { await viewModel.markUsed(product) }
                    }
                    .buttonStyle(HarborChipButtonStyle(tint: HarborPalette.leaf))

                    if product.hasUseByDate {
                        Button("Remind Me") {
                            Task { await viewModel.createReminder(for: product) }
                        }
                        .buttonStyle(HarborChipButtonStyle(tint: HarborPalette.sunGold))
                    }
                }
            }

            Divider().background(HarborColor.separator)
        }
    }

    // MARK: - Calendar

    private var calendarContent: some View {
        VStack(spacing: HarborMetrics.spacingM) {
            HarborCard {
                VStack(spacing: HarborMetrics.spacingM) {
                    HStack {
                        Button {
                            viewModel.shiftMonth(by: -1)
                        } label: {
                            Image(systemName: "chevron.left")
                                .frame(width: 34, height: 34)
                        }
                        Spacer()
                        Text(monthTitle)
                            .font(HarborFont.headline(17))
                            .foregroundColor(HarborColor.textPrimary)
                        Spacer()
                        Button {
                            viewModel.shiftMonth(by: 1)
                        } label: {
                            Image(systemName: "chevron.right")
                                .frame(width: 34, height: 34)
                        }
                    }
                    .foregroundColor(HarborColor.accent)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                        ForEach(weekdaySymbols, id: \.self) { symbol in
                            Text(symbol)
                                .font(HarborFont.caption(11))
                                .foregroundColor(HarborColor.textSecondary)
                        }
                        ForEach(viewModel.monthDays, id: \.self) { day in
                            dayCell(day)
                        }
                    }
                }
            }

            let dayProducts = viewModel.products(on: viewModel.selectedDay)
            HarborCard {
                VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                    SectionHeader(title: HarborFormat.fullDate.string(from: viewModel.selectedDay))
                    if dayProducts.isEmpty {
                        Text("Nothing is dated for this day.")
                            .font(HarborFont.body(14))
                            .foregroundColor(HarborColor.textSecondary)
                    } else {
                        ForEach(dayProducts) { product in
                            productRow(product, bucket: .today)
                        }
                    }
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let count = viewModel.products(on: day).count
        let isSelected = Calendar.current.isDate(day, inSameDayAs: viewModel.selectedDay)
        let inMonth = viewModel.isInSelectedMonth(day)

        return Button {
            viewModel.selectedDay = day
        } label: {
            VStack(spacing: 3) {
                Text(HarborFormat.dayNumber.string(from: day))
                    .font(HarborFont.caption(13))
                    .foregroundColor(
                        isSelected ? .white : (inMonth ? HarborColor.textPrimary : HarborColor.textSecondary.opacity(0.4))
                    )
                Circle()
                    .fill(count > 0 ? HarborPalette.sunGold : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(HarborGradient.ocean) : AnyShapeStyle(Color.clear))
            )
        }
        .buttonStyle(.plain)
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: viewModel.selectedDay)
    }

    private var weekdaySymbols: [String] {
        let calendar = Calendar.current
        let symbols = calendar.shortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }
}

/// Small sheet for changing (or clearing) a user-entered date.
struct AdjustDateView: View {
    let product: Product
    @State var initialDate: Date
    let onSave: (Date?) -> Void

    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        ScrollView {
            VStack(spacing: HarborMetrics.spacingM) {
                HarborCard {
                    VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                        Text(product.trimmedName)
                            .font(HarborFont.title(20))
                            .foregroundColor(HarborColor.textPrimary)
                        Text("Pick the date you want to use this by. It is your judgement — Harbor Pantry only stores it.")
                            .font(HarborFont.body(14))
                            .foregroundColor(HarborColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        DatePicker(
                            "Use-by date",
                            selection: $initialDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .tint(HarborColor.accent)
                    }
                }

                Button("Save Date") {
                    onSave(initialDate)
                }
                .buttonStyle(HarborPrimaryButtonStyle())

                if product.hasUseByDate {
                    Button("Remove Date") {
                        onSave(nil)
                    }
                    .buttonStyle(HarborSecondaryButtonStyle(tint: HarborPalette.coral))
                }
            }
            .padding(HarborMetrics.spacingL)
        }
        .harborScreenBackground()
        .navigationTitle("Adjust Date")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { presentationMode.wrappedValue.dismiss() }
            }
        }
    }
}
