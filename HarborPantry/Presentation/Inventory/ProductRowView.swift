//
//  ProductRowView.swift
//  HarborPantry
//
//  The inventory card. Photos come from the user; no decorative art here.
//

import SwiftUI

struct ProductRowView: View {
    let product: Product
    let zoneName: String
    let bucket: FreshnessBucket
    let daysText: String
    var isSelected: Bool = false
    var isSelecting: Bool = false
    var photoStore: PhotoStoring?

    var body: some View {
        HStack(spacing: HarborMetrics.spacingM) {
            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? HarborColor.accent : HarborColor.separator)
            }

            thumbnail

            VStack(alignment: .leading, spacing: 3) {
                Text(product.trimmedName)
                    .font(HarborFont.headline(16))
                    .foregroundColor(HarborColor.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Text(HarborFormat.quantity(product.quantity, product.unit))
                        .font(HarborFont.caption(12))
                        .foregroundColor(HarborColor.textSecondary)
                    Text("·")
                        .foregroundColor(HarborColor.textSecondary)
                    Text(zoneName)
                        .font(HarborFont.caption(12))
                        .foregroundColor(HarborColor.textSecondary)
                        .lineLimit(1)
                }

                HStack(spacing: 5) {
                    StatusPill(
                        text: daysText,
                        systemImage: bucket.symbolName,
                        color: HarborColor.bucket(bucket)
                    )
                    if product.isOpened {
                        StatusPill(text: "Opened", color: HarborPalette.sunGold)
                    }
                }
            }

            Spacer(minLength: 4)

            if !isSelecting {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(HarborColor.textSecondary.opacity(0.6))
            }
        }
        .padding(HarborMetrics.spacingM)
        .background(
            RoundedRectangle(cornerRadius: HarborMetrics.cardRadius, style: .continuous)
                .fill(HarborColor.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HarborMetrics.cardRadius, style: .continuous)
                .strokeBorder(
                    isSelected ? HarborColor.accent : HarborColor.separator,
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .harborShadow(strength: 0.5)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let photoStore = photoStore,
           let fileName = product.photoFileName,
           let data = photoStore.loadData(named: fileName),
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(HarborColor.bucket(bucket).opacity(0.14))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: product.category.symbolName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(HarborColor.bucket(bucket))
                )
        }
    }
}
