//
//  ProductFormView.swift
//  HarborPantry
//
//  Screen 7 — add or edit a product. No large decoration here: the fields are
//  the whole point of this screen.
//

import SwiftUI

struct ProductFormView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var viewModel: ProductFormViewModel

    private let onSaved: (Product?) -> Void

    @State private var photoSource: PhotoPicker.Source?
    @State private var showPhotoOptions = false
    @State private var showDeleteConfirmation = false
    @State private var savedBanner: String?

    init(
        dependencies: AppDependencies,
        mode: ProductFormViewModel.Mode,
        onSaved: @escaping (Product?) -> Void
    ) {
        self.onSaved = onSaved
        _viewModel = StateObject(
            wrappedValue: ProductFormViewModel(dependencies: dependencies, mode: mode)
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: HarborMetrics.spacingM) {
                if let savedBanner = savedBanner {
                    HStack(spacing: HarborMetrics.spacingS) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(HarborPalette.leaf)
                        Text(savedBanner)
                            .font(HarborFont.caption(13))
                            .foregroundColor(HarborColor.textPrimary)
                        Spacer()
                    }
                    .padding(HarborMetrics.spacingM)
                    .background(
                        RoundedRectangle(cornerRadius: HarborMetrics.controlRadius, style: .continuous)
                            .fill(HarborPalette.leaf.opacity(0.14))
                    )
                }

                basicsCard
                storageCard
                datesCard
                extrasCard

                if let error = viewModel.errorMessage {
                    ErrorStateView(message: error)
                }

                actions
            }
            .padding(.horizontal, HarborMetrics.spacingL)
            .padding(.vertical, HarborMetrics.spacingM)
        }
        .harborScreenBackground()
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { cancel() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.isEditing {
                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(HarborPalette.coral)
                    }
                }
            }
        }
        .confirmationDialog("Add a photo", isPresented: $showPhotoOptions, titleVisibility: .visible) {
            Button("Take Photo") { photoSource = .camera }
            Button("Choose from Library") { photoSource = .library }
            if viewModel.draft.photoFileName != nil {
                Button("Remove Photo", role: .destructive) { viewModel.removePhoto() }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $photoSource) { source in
            PhotoPicker(source: source) { data in
                viewModel.attachPhoto(data)
            }
            .ignoresSafeArea()
        }
        .alert("Delete this product?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    if await viewModel.delete() {
                        onSaved(nil)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        } message: {
            Text("The product and its photo are removed. Its history entries stay in your archive.")
        }
    }

    // MARK: - Cards

    private var basicsCard: some View {
        HarborCard {
            VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                FormRow(label: "Product Name", isRequired: true) {
                    HarborTextField(placeholder: "Salmon fillet", text: $viewModel.draft.name)
                }

                FormRow(label: "Category", isRequired: true) {
                    HarborMenuPicker(
                        items: ProductCategory.allCases,
                        title: { $0.displayName },
                        symbol: { $0.symbolName },
                        selection: $viewModel.draft.category
                    )
                }

                HStack(alignment: .top, spacing: HarborMetrics.spacingM) {
                    FormRow(label: "Quantity", isRequired: true) {
                        HarborTextField(
                            placeholder: "1",
                            text: $viewModel.draft.quantityText,
                            keyboard: .decimalPad
                        )
                    }
                    FormRow(label: "Unit", isRequired: true) {
                        HarborMenuPicker(
                            items: MeasurementUnit.allCases,
                            title: { $0.shortLabel },
                            selection: $viewModel.draft.unit
                        )
                    }
                    .frame(width: 116)
                }
            }
        }
    }

    private var storageCard: some View {
        HarborCard {
            VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                SectionHeader(title: "Storage")

                if viewModel.zones.isEmpty {
                    Text("You have no storage zones yet. Add one from Inventory → Zones before saving a product.")
                        .font(HarborFont.body(14))
                        .foregroundColor(HarborPalette.coral)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    FormRow(label: "Storage Zone", isRequired: true) {
                        HarborMenuPicker(
                            items: viewModel.zones.map(\.id),
                            title: { id in
                                viewModel.zones.first { $0.id == id }?.name ?? "Choose a zone"
                            },
                            selection: Binding(
                                get: { viewModel.draft.zoneId ?? viewModel.zones[0].id },
                                set: { viewModel.draft.zoneId = $0 }
                            )
                        )
                    }
                }
            }
        }
    }

    private var datesCard: some View {
        HarborCard {
            VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                SectionHeader(
                    title: "Dates",
                    subtitle: "All optional, and all yours to decide."
                )

                FormRow(label: "Purchase Date") {
                    OptionalDateField(label: "Purchase date", date: $viewModel.draft.purchaseDate)
                }

                FormRow(label: "Use-By Date (yours)") {
                    OptionalDateField(label: "Use-by date", date: $viewModel.draft.useByDate)
                }

                FormRow(label: "Opened Date") {
                    OptionalDateField(label: "Opened date", date: $viewModel.draft.openedDate)
                }

                if !viewModel.warnings.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(viewModel.warnings, id: \.self) { warning in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "exclamationmark.circle")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(HarborPalette.sunGold)
                                Text(warning)
                                    .font(HarborFont.caption(11.5))
                                    .foregroundColor(HarborColor.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(HarborMetrics.spacingM)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: HarborMetrics.controlRadius, style: .continuous)
                            .fill(HarborPalette.sunGold.opacity(0.12))
                    )
                }

                UserDataNotice(
                    text: "Harbor Pantry stores the dates exactly as you enter them and never decides whether something is still good."
                )
            }
        }
        .onChange(of: viewModel.draft.useByDate) { _ in viewModel.refreshWarnings() }
        .onChange(of: viewModel.draft.purchaseDate) { _ in viewModel.refreshWarnings() }
        .onChange(of: viewModel.draft.openedDate) { _ in viewModel.refreshWarnings() }
    }

    private var extrasCard: some View {
        HarborCard {
            VStack(alignment: .leading, spacing: HarborMetrics.spacingM) {
                SectionHeader(title: "Details")

                FormRow(label: "Price (\(viewModel.currency.symbol))") {
                    HarborTextField(
                        placeholder: "Optional",
                        text: $viewModel.draft.priceText,
                        keyboard: .decimalPad
                    )
                }

                FormRow(label: "Photo") {
                    Button {
                        showPhotoOptions = true
                    } label: {
                        if let data = viewModel.photoData, let image = UIImage(data: data) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 150)
                                .frame(maxWidth: .infinity)
                                .clipShape(
                                    RoundedRectangle(cornerRadius: HarborMetrics.controlRadius, style: .continuous)
                                )
                        } else {
                            photoPlaceholder
                        }
                    }
                    .buttonStyle(.plain)
                }

                FormRow(label: "Notes") {
                    HarborTextEditor(text: $viewModel.draft.notes, placeholder: "Anything worth remembering.")
                }

                FormRow(label: "Tags") {
                    TagEditor(tags: $viewModel.draft.tags)
                }
            }
        }
    }

    /// The one small illustration this screen allows: the empty photo slot.
    private var photoPlaceholder: some View {
        HStack(spacing: HarborMetrics.spacingM) {
            HarborIllustrationView(illustration: .productCrate)
                .frame(width: 72, height: 72)
            VStack(alignment: .leading, spacing: 2) {
                Text("Add a photo")
                    .font(HarborFont.headline(15))
                    .foregroundColor(HarborColor.accent)
                Text("Take one now or pick from your library.")
                    .font(HarborFont.caption(11.5))
                    .foregroundColor(HarborColor.textSecondary)
            }
            Spacer()
        }
        .padding(HarborMetrics.spacingM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: HarborMetrics.controlRadius, style: .continuous)
                .fill(HarborColor.fieldBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HarborMetrics.controlRadius, style: .continuous)
                .strokeBorder(HarborColor.separator, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        )
    }

    private var actions: some View {
        VStack(spacing: HarborMetrics.spacingS) {
            Button(viewModel.isEditing ? "Save Changes" : "Save Product") {
                Task {
                    if let product = await viewModel.save() {
                        onSaved(product)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .buttonStyle(HarborPrimaryButtonStyle(isEnabled: viewModel.canSave))
            .disabled(!viewModel.canSave)

            if !viewModel.isEditing {
                Button("Save & Add Another") {
                    Task {
                        if await viewModel.saveAndAddAnother() {
                            savedBanner = "Saved. The form is ready for the next product."
                            Task {
                                try? await Task.sleep(nanoseconds: 2_500_000_000)
                                savedBanner = nil
                            }
                        }
                    }
                }
                .buttonStyle(HarborSecondaryButtonStyle())
                .disabled(!viewModel.canSave)
                .opacity(viewModel.canSave ? 1 : 0.5)
            }
        }
    }

    private func cancel() {
        // An unfinished new product is parked rather than thrown away.
        viewModel.storeDraftIfNeeded()
        onSaved(nil)
        presentationMode.wrappedValue.dismiss()
    }
}

extension PhotoPicker.Source: Identifiable {
    public var id: String {
        switch self {
        case .camera: return "camera"
        case .library: return "library"
        }
    }
}
