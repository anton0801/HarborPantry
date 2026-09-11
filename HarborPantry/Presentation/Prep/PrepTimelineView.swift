//
//  PrepTimelineView.swift
//  HarborPantry
//
//  Screen 14 — the prep timeline and, on the other tab, what is left over.
//

import SwiftUI

struct PrepTimelineView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var viewModel: PrepTimelineViewModel

    @State private var showAddTask = false
    @State private var showAddLeftover = false
    @State private var reschedulingTask: PrepTask?
    @State private var buildingMeal: MealPlanEntry?

    init(dependencies: AppDependencies) {
        _viewModel = StateObject(wrappedValue: PrepTimelineViewModel(dependencies: dependencies))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: HarborMetrics.spacingM) {
                Picker("Mode", selection: $viewModel.tab) {
                    ForEach(PrepTimelineViewModel.Tab.allCases) { tab in
                        Text(tab.displayName).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.top, HarborMetrics.spacingS)

                if let message = viewModel.reminderMessage {
                    CachedDataBanner(message: message)
                }
                if let error = viewModel.errorMessage {
                    ErrorStateView(message: error)
                }
                if !viewModel.pendingShifts.isEmpty {
                    shiftProposalCard
                }

                if viewModel.tab == .timeline {
                    timelineContent
                } else {
                    leftoversContent
                }
            }
            .padding(.horizontal, HarborMetrics.spacingL)
            .padding(.bottom, HarborMetrics.spacingXL)
        }
        .harborScreenBackground()
        .navigationTitle("Prep & Leftovers")
        .navigationBarTitleDisplayMode(.inline)
        .harborToast($viewModel.toast)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    if viewModel.tab == .timeline { showAddTask = true } else { showAddLeftover = true }
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showAddTask) {
            NavigationView {
                AddPrepTaskView(
                    day: viewModel.selectedDay,
                    dependencies: viewModel.dependencyCandidates
                ) { title, date, minutes, kind, dependencyId in
                    Task {
                        await viewModel.addQuickTask(
                            title: title,
                            at: date,
                            minutes: minutes,
                            kind: kind,
                            dependencyId: dependencyId
                        )
                        showAddTask = false
                    }
                }
            }
            .navigationViewStyle(.stack)
        }
        .sheet(isPresented: $showAddLeftover) {
            NavigationView {
                AddLeftoverView(
                    dishes: Array(viewModel.dishesById.values).sorted { $0.trimmedName < $1.trimmedName },
                    zones: viewModel.zones
                ) { name, quantity, unit, dishId, zoneId, note, useBy in
                    Task {
                        await viewModel.addLeftover(
                            name: name,
                            quantity: quantity,
                            unit: unit,
                            dishId: dishId,
                            zoneId: zoneId,
                            note: note,
                            useByDate: useBy
                        )
                        showAddLeftover = false
                    }
                }
            }
            .navigationViewStyle(.stack)
        }
        .sheet(item: $reschedulingTask) { task in
            NavigationView {
                RescheduleTaskView(task: task) { newDate in
                    Task {
                        await viewModel.reschedule(task, to: newDate)
                        reschedulingTask = nil
                    }
                }
            }
            .navigationViewStyle(.stack)
        }
        .sheet(item: $buildingMeal) { entry in
            NavigationView {
                MealTimePickerView(
                    dishName: viewModel.dishName(entry.dishId) ?? "Meal",
                    day: viewModel.selectedDay
                ) { mealTime in
                    Task {
                        await viewModel.buildTimeline(for: entry, mealTime: mealTime)
                        buildingMeal = nil
                    }
                }
            }
            .navigationViewStyle(.stack)
        }
    }

    // MARK: - Shift proposals

    private var shiftProposalCard: some View {
        HarborCard(tint: HarborPalette.sunGold) {
            VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                SectionHeader(
                    title: "Dependent tasks",
                    subtitle: "These follow the task you just changed. Nothing moves until you say so."
                )
                ForEach(viewModel.pendingShifts) { proposal in
                    HStack {
                        Text(proposal.title)
                            .font(HarborFont.body(14))
                            .foregroundColor(HarborColor.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text(HarborFormat.time.string(from: proposal.currentTime))
                            .font(HarborFont.caption(11.5))
                            .foregroundColor(HarborColor.textSecondary)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(HarborColor.textSecondary)
                        Text(HarborFormat.time.string(from: proposal.suggestedTime))
                            .font(HarborFont.caption(12))
                            .foregroundColor(HarborColor.accent)
                    }
                }
                HStack(spacing: HarborMetrics.spacingS) {
                    Button("Apply Times") {
                        Task { await viewModel.applyPendingShifts() }
                    }
                    .buttonStyle(HarborChipButtonStyle(tint: HarborPalette.leaf))
                    Button("Keep As Is") { viewModel.dismissPendingShifts() }
                        .buttonStyle(HarborChipButtonStyle())
                    Spacer()
                }
            }
        }
    }

    // MARK: - Timeline

    private var timelineContent: some View {
        VStack(spacing: HarborMetrics.spacingM) {
            dayPicker

            if viewModel.tasks.isEmpty {
                VStack(spacing: HarborMetrics.spacingM) {
                    EmptyStateView(
                        title: "No prep steps yet",
                        message: "Lay out thawing, prep and cooking so everything is ready when you want to eat.",
                        illustration: .prepClock,
                        illustrationWidth: 140,
                        actionTitle: "Add a Task",
                        action: { showAddTask = true }
                    )
                    if !viewModel.plannedMeals.isEmpty {
                        plannedMealsCard
                    }
                }
            } else {
                ForEach(viewModel.tasks) { task in
                    taskCard(task)
                }
                if !viewModel.plannedMeals.isEmpty {
                    plannedMealsCard
                }
            }

            UserDataNotice(
                text: "Suggested times are a starting point, not a food-safety instruction. Thawing and storage choices are yours."
            )
        }
    }

    private var dayPicker: some View {
        HarborCard(padding: HarborMetrics.spacingM) {
            HStack {
                Button {
                    if let previous = Calendar.current.date(byAdding: .day, value: -1, to: viewModel.selectedDay) {
                        viewModel.selectDay(previous)
                    }
                } label: {
                    Image(systemName: "chevron.left").frame(width: 32, height: 32)
                }
                Spacer()
                Text(HarborFormat.fullDate.string(from: viewModel.selectedDay))
                    .font(HarborFont.headline(15))
                    .foregroundColor(HarborColor.textPrimary)
                Spacer()
                Button {
                    if let next = Calendar.current.date(byAdding: .day, value: 1, to: viewModel.selectedDay) {
                        viewModel.selectDay(next)
                    }
                } label: {
                    Image(systemName: "chevron.right").frame(width: 32, height: 32)
                }
            }
            .foregroundColor(HarborColor.accent)
        }
    }

    private func taskCard(_ task: PrepTask) -> some View {
        HarborAccentCard(accent: accentColor(for: task)) {
            VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                HStack(alignment: .top, spacing: HarborMetrics.spacingM) {
                    VStack(spacing: 2) {
                        Text(HarborFormat.time.string(from: task.scheduledAt))
                            .font(HarborFont.numeric(15))
                            .foregroundColor(HarborColor.textPrimary)
                        Text(HarborFormat.duration(minutes: task.durationMinutes))
                            .font(HarborFont.caption(10.5))
                            .foregroundColor(HarborColor.textSecondary)
                    }
                    .frame(width: 62, alignment: .leading)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(task.title)
                            .font(HarborFont.headline(16))
                            .foregroundColor(HarborColor.textPrimary)
                            .strikethrough(task.isFinished, color: HarborColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 5) {
                            StatusPill(
                                text: task.kind.displayName,
                                systemImage: task.kind.symbolName,
                                color: accentColor(for: task)
                            )
                            if task.status != .pending {
                                StatusPill(text: task.status.displayName, color: HarborColor.textSecondary)
                            }
                        }

                        if let dependency = viewModel.dependencyTitle(task.dependencyId) {
                            Text("After: \(dependency)")
                                .font(HarborFont.caption(11))
                                .foregroundColor(HarborColor.textSecondary)
                        }
                        if let dish = viewModel.dishName(task.linkedDishId) {
                            Text("For: \(dish)")
                                .font(HarborFont.caption(11))
                                .foregroundColor(HarborColor.accent)
                        }
                        if !task.note.isEmpty {
                            Text(task.note)
                                .font(HarborFont.caption(11))
                                .foregroundColor(HarborColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer()
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: HarborMetrics.spacingS) {
                        if task.status == .pending || task.status == .delayed {
                            Button("Start") { Task { await viewModel.start(task) } }
                                .buttonStyle(HarborChipButtonStyle())
                        }
                        if !task.isFinished {
                            Button("Complete") { Task { await viewModel.complete(task) } }
                                .buttonStyle(HarborChipButtonStyle(tint: HarborPalette.leaf))
                            Button("Delay 15m") { Task { await viewModel.delay(task, minutes: 15) } }
                                .buttonStyle(HarborChipButtonStyle(tint: HarborPalette.sunGold))
                            Button("Reschedule") { reschedulingTask = task }
                                .buttonStyle(HarborChipButtonStyle())
                            Button("Remind") { Task { await viewModel.createReminder(for: task) } }
                                .buttonStyle(HarborChipButtonStyle(tint: HarborPalette.sunGold))
                        }
                        Button("Delete") { Task { await viewModel.delete(task) } }
                            .buttonStyle(HarborChipButtonStyle(tint: HarborPalette.coral))
                    }
                }
            }
        }
    }

    private func accentColor(for task: PrepTask) -> Color {
        switch task.status {
        case .completed: return HarborPalette.leaf
        case .inProgress: return HarborColor.accent
        case .delayed: return HarborPalette.sunGold
        case .pending:
            switch task.kind {
            case .thaw: return HarborPalette.aqua
            case .cook: return HarborPalette.coral
            default: return HarborColor.accent
            }
        }
    }

    private var plannedMealsCard: some View {
        HarborCard {
            VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                SectionHeader(
                    title: "Planned for this day",
                    subtitle: "Build a starting timeline from one of these."
                )
                ForEach(viewModel.plannedMeals) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(viewModel.dishName(entry.dishId) ?? "Dish")
                                .font(HarborFont.headline(15))
                                .foregroundColor(HarborColor.textPrimary)
                            Text("\(entry.slotTitle) · \(entry.totalServings) serving\(entry.totalServings == 1 ? "" : "s")")
                                .font(HarborFont.caption(11.5))
                                .foregroundColor(HarborColor.textSecondary)
                        }
                        Spacer()
                        Button("Build Timeline") { buildingMeal = entry }
                            .buttonStyle(HarborChipButtonStyle())
                    }
                }
            }
        }
    }

    // MARK: - Leftovers

    private var leftoversContent: some View {
        VStack(spacing: HarborMetrics.spacingM) {
            if viewModel.leftovers.isEmpty {
                EmptyStateView(
                    title: "No leftovers logged",
                    message: "After a meal, note what is left, where you put it and the date you want to use it by.",
                    illustration: .leftoverLunchbox,
                    illustrationWidth: 130,
                    actionTitle: "Add Leftover",
                    action: { showAddLeftover = true }
                )
            } else {
                if !viewModel.storedLeftovers.isEmpty {
                    HarborCard {
                        VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                            SectionHeader(title: "Stored")
                            ForEach(viewModel.storedLeftovers) { leftover in
                                leftoverRow(leftover)
                            }
                        }
                    }
                }
                if !viewModel.resolvedLeftovers.isEmpty {
                    HarborCard {
                        VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                            SectionHeader(title: "Closed out")
                            ForEach(viewModel.resolvedLeftovers) { leftover in
                                HStack {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(leftover.trimmedName)
                                            .font(HarborFont.body(14))
                                            .foregroundColor(HarborColor.textPrimary)
                                        Text(leftover.status.displayName)
                                            .font(HarborFont.caption(11))
                                            .foregroundColor(HarborColor.textSecondary)
                                    }
                                    Spacer()
                                    Button {
                                        Task { await viewModel.deleteLeftover(leftover) }
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundColor(HarborPalette.coral.opacity(0.75))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }

            UserDataNotice(
                text: "The use-by date on a leftover is the one you choose. Harbor Pantry keeps the note and makes no safety promise."
            )
        }
    }

    private func leftoverRow(_ leftover: Leftover) -> some View {
        VStack(alignment: .leading, spacing: HarborMetrics.spacingS) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(leftover.trimmedName)
                        .font(HarborFont.headline(15))
                        .foregroundColor(HarborColor.textPrimary)
                    HStack(spacing: 5) {
                        Text(HarborFormat.quantity(leftover.quantity, leftover.unit))
                            .font(HarborFont.caption(11.5))
                            .foregroundColor(HarborColor.textSecondary)
                        if let zone = viewModel.zones.first(where: { $0.id == leftover.zoneId }) {
                            Text("· \(zone.name)")
                                .font(HarborFont.caption(11.5))
                                .foregroundColor(HarborColor.textSecondary)
                        }
                    }
                    if let useBy = leftover.useByDate {
                        Text("Use by \(HarborFormat.dayMonth.string(from: useBy))")
                            .font(HarborFont.caption(11))
                            .foregroundColor(HarborPalette.sunGold)
                    }
                    if !leftover.storageNote.isEmpty {
                        Text(leftover.storageNote)
                            .font(HarborFont.caption(11))
                            .foregroundColor(HarborColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
            }

            HStack(spacing: HarborMetrics.spacingS) {
                Button("Mark Used") {
                    Task { await viewModel.resolveLeftover(leftover, status: .used) }
                }
                .buttonStyle(HarborChipButtonStyle(tint: HarborPalette.leaf))
                Button("Discarded") {
                    Task { await viewModel.resolveLeftover(leftover, status: .discarded) }
                }
                .buttonStyle(HarborChipButtonStyle(tint: HarborPalette.coral))
                Spacer()
            }

            Divider().background(HarborColor.separator)
        }
    }
}
