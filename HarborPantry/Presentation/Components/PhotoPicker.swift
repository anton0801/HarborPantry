//
//  PhotoPicker.swift
//  HarborPantry
//
//  Presentation layer — camera and library access for product photos.
//  `PhotosPicker` needs iOS 16, so this wraps `UIImagePickerController`.
//

import SwiftUI
import UIKit

struct PhotoPicker: UIViewControllerRepresentable {
    enum Source {
        case camera
        case library

        var sourceType: UIImagePickerController.SourceType {
            switch self {
            case .camera: return .camera
            case .library: return .photoLibrary
            }
        }

        /// Falls back to the library when no camera exists (e.g. Simulator).
        var isAvailable: Bool {
            UIImagePickerController.isSourceTypeAvailable(sourceType)
        }
    }

    let source: Source
    let onPicked: (Data) -> Void
    @Environment(\.presentationMode) private var presentationMode

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = source.isAvailable ? source.sourceType : .photoLibrary
        controller.allowsEditing = true
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked) {
            presentationMode.wrappedValue.dismiss()
        }
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onPicked: (Data) -> Void
        private let dismiss: () -> Void

        init(onPicked: @escaping (Data) -> Void, dismiss: @escaping () -> Void) {
            self.onPicked = onPicked
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)
            if let data = image?.downscaled(maxDimension: 1200)?.jpegData(compressionQuality: 0.82) {
                onPicked(data)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

extension UIImage {
    /// Keeps stored photos small — the app never needs full-resolution images.
    func downscaled(maxDimension: CGFloat) -> UIImage? {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

/// Renders a stored product photo, or the neutral crate placeholder.
struct ProductPhotoView: View {
    let fileName: String?
    let photoStore: PhotoStoring
    var height: CGFloat = 160
    var cornerRadius: CGFloat = HarborMetrics.controlRadius

    var body: some View {
        Group {
            if let fileName = fileName,
               let data = photoStore.loadData(named: fileName),
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    HarborColor.surfaceSunken
                    HarborIllustrationView(illustration: .productCrate)
                        .frame(height: height * 0.78)
                }
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
