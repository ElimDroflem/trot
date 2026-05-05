import UIKit

extension UIImage {
    /// Downscales the image so its longest edge is at most `maxLongEdge` points,
    /// then encodes as JPEG at the given compression quality.
    /// Per decisions.md: 1024px long edge, 80% JPEG, ~150-300KB target.
    func downscaledJPEGData(maxLongEdge: CGFloat = 1024, quality: CGFloat = 0.8) -> Data? {
        let longEdge = max(size.width, size.height)
        let scale = min(1.0, maxLongEdge / max(longEdge, 1))
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let downscaled = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
        return downscaled.jpegData(compressionQuality: quality)
    }
}
