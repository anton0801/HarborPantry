//
//  OnboardingView.swift
//  HarborPantry
//
//  Screens 1–3 — one full-bleed illustration per slide with a light text panel
//  covering the lower portion.
//

import SwiftUI

struct OnboardingView: View {
    @StateObject private var viewModel: OnboardingViewModel
    let onFinish: (OnboardingViewModel.Finish) -> Void

    init(
        profileUseCases: ProfileUseCases,
        onFinish: @escaping (OnboardingViewModel.Finish) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: OnboardingViewModel(profileUseCases: profileUseCases))
        self.onFinish = onFinish
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Full-bleed artwork behind everything.
            Color.clear
                .overlay(
                    HarborIllustrationView(
                        illustration: viewModel.currentPage.illustration,
                        contentMode: .fill
                    )
                    .id(viewModel.currentPage.id)
                    .transition(.opacity)
                )
                .clipped()
                .ignoresSafeArea()

            // The panel sizes itself to its content, so it can never be pushed
            // off a short screen.
            panel
        }
        .overlay(alignment: .topTrailing) { skipButton }
        .background(HarborColor.background.ignoresSafeArea())
    }

    private var skipButton: some View {
        Button("Skip") {
            complete(.skip)
        }
        .font(HarborFont.headline(15))
        .foregroundColor(.white)
        .padding(.horizontal, HarborMetrics.spacingM)
        .padding(.vertical, HarborMetrics.spacingS)
        .frame(minHeight: HarborMetrics.minimumTapTarget)
        .background(Capsule().fill(Color.black.opacity(0.28)))
        .padding(.trailing, HarborMetrics.spacingL)
        .padding(.top, HarborMetrics.spacingS)
        .accessibilityHint("Go to the dashboard without setting up your pantry")
    }

    // MARK: - Text panel

    private var panel: some View {
        VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
            progressDots

            Text(viewModel.currentPage.title)
                .font(HarborFont.display(28))
                .foregroundColor(HarborColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(viewModel.currentPage.message)
                .font(HarborFont.body(15))
                .foregroundColor(HarborColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if viewModel.isLastPage {
                reminderToggle
            }

            controls
        }
        .padding(HarborMetrics.spacingL)
        .padding(.bottom, HarborMetrics.spacingS)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(HarborColor.surface)
                .ignoresSafeArea(edges: .bottom)
        )
        .harborShadow(strength: 1.4)
    }

    private var progressDots: some View {
        HStack(spacing: 7) {
            ForEach(viewModel.pages.indices, id: \.self) { index in
                Capsule()
                    .fill(index == viewModel.index ? HarborColor.accent : HarborColor.separator)
                    .frame(width: index == viewModel.index ? 22 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.25), value: viewModel.index)
            }
            Spacer()
            Text(viewModel.progressText)
                .font(HarborFont.caption(12))
                .foregroundColor(HarborColor.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(viewModel.progressText)")
    }

    private var reminderToggle: some View {
        VStack(alignment: .leading, spacing: HarborMetrics.spacingS) {
            Toggle(isOn: Binding(
                get: { viewModel.remindersEnabled },
                set: { newValue in
                    Task { await viewModel.toggleReminders(newValue) }
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable Reminders")
                        .font(HarborFont.headline(15))
                        .foregroundColor(HarborColor.textPrimary)
                    Text("Optional local nudges for dates you set yourself.")
                        .font(HarborFont.caption(12))
                        .foregroundColor(HarborColor.textSecondary)
                }
            }
            .tint(HarborColor.accent)

            if let message = viewModel.permissionMessage {
                Text(message)
                    .font(HarborFont.caption(11.5))
                    .foregroundColor(HarborColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(HarborMetrics.spacingM)
        .background(
            RoundedRectangle(cornerRadius: HarborMetrics.controlRadius, style: .continuous)
                .fill(HarborColor.surfaceSunken)
        )
    }

    private var controls: some View {
        HStack(spacing: HarborMetrics.spacingM) {
            if !viewModel.isFirstPage {
                Button("Back") {
                    viewModel.back()
                }
                .buttonStyle(HarborSecondaryButtonStyle())
                .frame(maxWidth: 120)
                .disabled(viewModel.isTransitioning)
            }

            Button(viewModel.isLastPage ? "Get Started" : "Next") {
                if viewModel.isLastPage {
                    complete(.setUpProfile)
                } else {
                    viewModel.next()
                }
            }
            .buttonStyle(HarborPrimaryButtonStyle(isEnabled: !viewModel.isTransitioning))
            .disabled(viewModel.isTransitioning)
        }
    }

    private func complete(_ kind: OnboardingViewModel.Finish) {
        Task {
            await viewModel.finish(kind)
            onFinish(kind)
        }
    }
}
