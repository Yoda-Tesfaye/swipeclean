import SwiftUI
import UIKit

/// Renders photos through `UIImageView` so HDR gain maps can be shown in EDR
/// when the photo HDR setting is on, and tone-mapped to SDR when it is off.
struct HDRImageView: UIViewRepresentable {
    let image: UIImage
    var hdr: Bool
    var contentMode: UIView.ContentMode

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.backgroundColor = .clear
        view.clipsToBounds = true
        view.contentMode = contentMode
        apply(to: view)
        return view
    }

    func updateUIView(_ view: UIImageView, context: Context) {
        view.contentMode = contentMode
        apply(to: view)
    }

    /// Without this the image view reports its intrinsic (pixel) size and the
    /// card shows a 1:1 crop instead of the whole photo.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIImageView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? uiView.intrinsicContentSize.width,
               height: proposal.height ?? uiView.intrinsicContentSize.height)
    }

    private func apply(to view: UIImageView) {
        view.image = image
        if #available(iOS 17.0, *) {
            view.preferredImageDynamicRange = hdr ? .high : .standard
        }
    }
}
