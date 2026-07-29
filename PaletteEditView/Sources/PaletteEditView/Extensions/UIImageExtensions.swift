//
//  PaletteEditView
//
//  Created by Eisuke Kusachi on 2026/07/02.
//

import UIKit

extension UIImage {
    /// Returns the color of the image pixel corresponding to a point in `viewSize`.
    func pixelColor(
        at location: CGPoint,
        in viewSize: CGSize
    ) -> UIColor? {
        guard
            viewSize.width > 0,
            viewSize.height > 0,
            let cgImage
        else {
            return nil
        }

        let pixelWidth = cgImage.width
        let pixelHeight = cgImage.height
        guard pixelWidth > 0, pixelHeight > 0 else { return nil }

        let pixelX = Int((location.x / viewSize.width) * CGFloat(pixelWidth))
        let pixelY = Int((location.y / viewSize.height) * CGFloat(pixelHeight))
        guard
            pixelX >= 0,
            pixelY >= 0,
            pixelX < pixelWidth,
            pixelY < pixelHeight
        else {
            return nil
        }

        var pixel = [UInt8](repeating: 0, count: 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo =
            CGImageAlphaInfo.premultipliedLast.rawValue |
            CGBitmapInfo.byteOrder32Big.rawValue

        // A tiny 1x1 context for sampling one pixel's color.
        let sample = pixel.withUnsafeMutableBytes { rawBuffer -> Bool in
            guard let baseAddress = rawBuffer.baseAddress else { return false }
            guard let context = CGContext(
                data: baseAddress,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else {
                return false
            }

            context.interpolationQuality = .none
            // Shift the drawn image so the target pixel lands in this 1x1 context.
            let sampleY = pixelHeight - 1 - pixelY
            context.translateBy(x: -CGFloat(pixelX), y: -CGFloat(sampleY))
            context.draw(
                cgImage,
                in: CGRect(
                    x: 0,
                    y: 0,
                    width: pixelWidth,
                    height: pixelHeight
                )
            )
            return true
        }
        guard sample else { return nil }

        return UIColor(
            red: CGFloat(pixel[0]) / 255.0,
            green: CGFloat(pixel[1]) / 255.0,
            blue: CGFloat(pixel[2]) / 255.0,
            alpha: CGFloat(pixel[3]) / 255.0
        )
    }
}
