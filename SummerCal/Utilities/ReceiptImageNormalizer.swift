import Foundation
import UIKit

enum ReceiptImageNormalizer {
    private static let maxDimension: CGFloat = 1800
    private static let maxByteCount = 1_500_000

    static func jpegData(from data: Data) throws -> Data {
        guard let image = UIImage(data: data) else {
            throw makeError("Could not read this photo. Choose a JPEG, PNG, or HEIC image.")
        }
        return try jpegData(from: image)
    }

    static func jpegData(from image: UIImage) throws -> Data {
        let rendered = renderForReceiptScan(image, maxDimension: maxDimension)
        var quality: CGFloat = 0.88

        guard var data = rendered.jpegData(compressionQuality: quality), !data.isEmpty else {
            throw makeError("Could not convert this photo to JPEG.")
        }

        while data.count > maxByteCount && quality > 0.35 {
            quality -= 0.08
            if let compressed = rendered.jpegData(compressionQuality: quality), !compressed.isEmpty {
                data = compressed
            } else {
                break
            }
        }

        if data.count > maxByteCount {
            let smaller = renderForReceiptScan(image, maxDimension: maxDimension * 0.75)
            if let compressed = smaller.jpegData(compressionQuality: 0.55), !compressed.isEmpty {
                data = compressed
            }
        }

        return data
    }

    private static func renderForReceiptScan(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let width = image.size.width
        let height = image.size.height
        guard width > 0, height > 0 else { return image }

        let scale = min(1, maxDimension / max(width, height))
        let size = CGSize(width: width * scale, height: height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private static func makeError(_ message: String) -> NSError {
        NSError(domain: "ReceiptImageNormalizer", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
