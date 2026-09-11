//
//  HarborFormComponents.swift
//  HarborPantry
//
//  Presentation layer — form controls. Forms stay free of heavy decoration so
//  the fields are always the focus.
//

import SwiftUI

/// A labelled row wrapper used by every form field.
struct FormRow<Content: View>: View {
    let label: String
    var isRequired: Bool = false
    var hint: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 3) {
                Text(label)
                    .font(HarborFont.caption(12.5))
                    .foregroundColor(HarborColor.textSecondary)
                if isRequired {
                    Text("*")
                        .font(HarborFont.caption(12.5))
                        .foregroundColor(HarborPalette.coral)
                }
            }
            content()
            if let hint = hint {
                Text(hint)
                    .font(HarborFont.caption(11.5))
                    .foregroundColor(HarborColor.textSecondary.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Text field with the app's field styling.
struct HarborTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences

    var body: some View {
        TextField(placeholder, text: $text)
            .font(HarborFont.body(15))
            .foregroundColor(HarborColor.textPrimary)
            .keyboardType(keyboard)
            .textInputAutocapitalization(autocapitalization)
            .disableAutocorrection(keyboard == .decimalPad || keyboard == .numberPad)
            .padding(.horizontal, HarborMetrics.spacingM)
            .frame(minHeight: HarborMetrics.minimumTapTarget)
            .background(
                RoundedRectangle(cornerRadius: HarborMetrics.controlRadius, style: .continuous)
                    .fill(HarborColor.fieldBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HarborMetrics.controlRadius, style: .continuous)
                    .strokeBorder(HarborColor.separator, lineWidth: 1)
            )
    }
}

/// Multi-line note field.
struct HarborTextEditor: View {
    @Binding var text: String
    var minHeight: CGFloat = 92
    var placeholder: String = ""

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: HarborMetrics.controlRadius, style: .continuous)
                .fill(HarborColor.fieldBackground)
            RoundedRectangle(cornerRadius: HarborMetrics.controlRadius, style: .continuous)
                .strokeBorder(HarborColor.separator, lineWidth: 1)

            if text.isEmpty && !placeholder.isEmpty {
                Text(placeholder)
                    .font(HarborFont.body(15))
                    .foregroundColor(HarborColor.textSecondary.opacity(0.7))
                    .padding(.horizontal, HarborMetrics.spacingM + 4)
                    .padding(.vertical, HarborMetrics.spacingM)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $text)
                .font(HarborFont.body(15))
                .foregroundColor(HarborColor.textPrimary)
                .padding(.horizontal, HarborMetrics.spacingM)
                .padding(.vertical, HarborMetrics.spacingS)
                .frame(minHeight: minHeight)
                .background(Color.clear)
                .onAppear { UITextView.appearance().backgroundColor = .clear }
        }
        .frame(minHeight: minHeight)
    }
}

/// A menu-backed picker styled like the rest of the fields.
struct HarborMenuPicker<Item: Hashable>: View {
    let items: [Item]
    let title: (Item) -> String
    var symbol: ((Item) -> String?)? = nil
    @Binding var selection: Item

    var body: some View {
        Menu {
            ForEach(items, id: \.self) { item in
                Button {
                    selection = item
                } label: {
                    if let symbol = symbol?(item) {
                        Label(title(item), systemImage: symbol)
                    } else {
                        Text(title(item))
                    }
                }
            }
        } label: {
            HStack {
                Text(title(selection))
                    .font(HarborFont.body(15))
                    .foregroundColor(HarborColor.textPrimary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(HarborColor.textSecondary)
            }
            .padding(.horizontal, HarborMetrics.spacingM)
            .frame(minHeight: HarborMetrics.minimumTapTarget)
            .background(
                RoundedRectangle(cornerRadius: HarborMetrics.controlRadius, style: .continuous)
                    .fill(HarborColor.fieldBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HarborMetrics.controlRadius, style: .continuous)
                    .strokeBorder(HarborColor.separator, lineWidth: 1)
            )
        }
    }
}

/// Optional-date field: dates are never filled in on the user's behalf.
struct OptionalDateField: View {
    let label: String
    @Binding var date: Date?
    var addTitle: String = "Add date"

    @State private var draft = Date()

    var body: some View {
        Group {
            if let bound = date {
                HStack(spacing: HarborMetrics.spacingS) {
                    DatePicker(
                        label,
                        selection: Binding(
                            get: { bound },
                            set: { date = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .font(HarborFont.body(15))

                    Spacer()

                    Button {
                        date = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(HarborColor.textSecondary)
                    }
                    .accessibilityLabel("Clear \(label)")
                }
                .padding(.horizontal, HarborMetrics.spacingM)
                .frame(minHeight: HarborMetrics.minimumTapTarget)
                .background(
                    RoundedRectangle(cornerRadius: HarborMetrics.controlRadius, style: .continuous)
                        .fill(HarborColor.fieldBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: HarborMetrics.controlRadius, style: .continuous)
                        .strokeBorder(HarborColor.separator, lineWidth: 1)
                )
            } else {
                Button {
                    date = draft
                } label: {
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                        Text(addTitle)
                        Spacer()
                    }
                    .font(HarborFont.body(15))
                    .foregroundColor(HarborColor.accent)
                    .padding(.horizontal, HarborMetrics.spacingM)
                    .frame(minHeight: HarborMetrics.minimumTapTarget)
                    .background(
                        RoundedRectangle(cornerRadius: HarborMetrics.controlRadius, style: .continuous)
                            .fill(HarborColor.fieldBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: HarborMetrics.controlRadius, style: .continuous)
                            .strokeBorder(HarborColor.separator, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Stepper for whole-number counts with a wide tap target.
struct CountStepper: View {
    @Binding var value: Int
    var range: ClosedRange<Int> = 1...50
    var label: String = ""

    var body: some View {
        HStack(spacing: HarborMetrics.spacingM) {
            stepButton(symbol: "minus", enabled: value > range.lowerBound) {
                value = max(range.lowerBound, value - 1)
            }
            VStack(spacing: 0) {
                Text("\(value)")
                    .font(HarborFont.numeric(20))
                    .foregroundColor(HarborColor.textPrimary)
                if !label.isEmpty {
                    Text(label)
                        .font(HarborFont.caption(11))
                        .foregroundColor(HarborColor.textSecondary)
                }
            }
            .frame(minWidth: 58)
            stepButton(symbol: "plus", enabled: value < range.upperBound) {
                value = min(range.upperBound, value + 1)
            }
        }
        .padding(.horizontal, HarborMetrics.spacingS)
        .frame(minHeight: HarborMetrics.minimumTapTarget)
        .background(
            RoundedRectangle(cornerRadius: HarborMetrics.controlRadius, style: .continuous)
                .fill(HarborColor.fieldBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HarborMetrics.controlRadius, style: .continuous)
                .strokeBorder(HarborColor.separator, lineWidth: 1)
        )
    }

    private func stepButton(symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(enabled ? HarborColor.accent : HarborColor.textSecondary.opacity(0.4))
                .frame(width: 38, height: 38)
                .background(Circle().fill(HarborColor.surface))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

/// Editable list of free-text tags.
struct TagEditor: View {
    @Binding var tags: [String]
    var placeholder: String = "Add a tag"

    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: HarborMetrics.spacingS) {
            if !tags.isEmpty {
                FlowLayoutView(items: tags) { tag in
                    HStack(spacing: 5) {
                        Text(tag)
                            .font(HarborFont.caption(12))
                        Button {
                            tags.removeAll { $0 == tag }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                    }
                    .foregroundColor(HarborColor.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(HarborColor.accent.opacity(0.12)))
                }
            }

            HStack(spacing: HarborMetrics.spacingS) {
                HarborTextField(placeholder: placeholder, text: $draft)
                Button {
                    addTag()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: HarborMetrics.minimumTapTarget, height: HarborMetrics.minimumTapTarget)
                        .background(
                            RoundedRectangle(cornerRadius: HarborMetrics.controlRadius, style: .continuous)
                                .fill(HarborGradient.ocean)
                        )
                }
                .buttonStyle(.plain)
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(draft.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            }
        }
    }

    private func addTag() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
        tags.append(trimmed)
        draft = ""
    }
}

/// Simple wrapping row layout (iOS 15 has no `Layout` protocol).
struct FlowLayoutView<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: HarborMetrics.spacingS) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: HarborMetrics.spacingS) {
                    ForEach(row, id: \.self) { item in
                        content(item)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    /// Chunks into fixed-size rows: without `Layout` this is the predictable
    /// option, and tags here are short.
    private var rows: [[Item]] {
        stride(from: 0, to: items.count, by: 3).map { start in
            Array(items[start..<min(start + 3, items.count)])
        }
    }
}
