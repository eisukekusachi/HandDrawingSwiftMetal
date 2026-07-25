//
//  PaletteEditView
//
//  Created by Eisuke Kusachi on 2026/07/02.
//

import UIKit

extension UIImage {
    func paletteColor(
        at location: CGPoint,
        in viewSize: CGSize
    ) -> UIColor? {
        guard viewSize.width > 0, viewSize.height > 0 else { return nil }

        let imageLocation = CGPoint(
            x: location.x * (size.width / viewSize.width),
            y: location.y * (size.height / viewSize.height)
        )

        guard
            imageLocation.x >= 0,
            imageLocation.y >= 0,
            imageLocation.x < size.width,
            imageLocation.y < size.height,
            let cgImage,
            let dataProvider = cgImage.dataProvider,
            let providerData = dataProvider.data
        else {
            return nil
        }

        let data = CFDataGetBytePtr(providerData)
        let pixelInfo = (Int(imageLocation.x) + Int(imageLocation.y) * Int(size.width)) * 4

        guard let data else { return nil }

        let red = CGFloat(data[pixelInfo]) / 255.0
        let green = CGFloat(data[pixelInfo + 1]) / 255.0
        let blue = CGFloat(data[pixelInfo + 2]) / 255.0
        let alpha = CGFloat(data[pixelInfo + 3]) / 255.0

        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}
