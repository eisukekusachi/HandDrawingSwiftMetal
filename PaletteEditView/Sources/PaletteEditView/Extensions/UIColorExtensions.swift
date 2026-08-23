//
//  PaletteEditView
//
//  Created by Eisuke Kusachi on 2026/07/02.
//

import UIKit

extension UIColor {

    convenience init(color: UIColor, alpha: Int) {
        let components = color.rgbaComponents()
        self.init(
            intRed: components.red,
            green: components.green,
            blue: components.blue,
            alpha: alpha
        )
    }

    convenience init(intRed: Int, green: Int, blue: Int, alpha: Int) {
        self.init(
            red: CGFloat(min(max(0, intRed), 255)) / 255.0,
            green: CGFloat(min(max(0, green), 255)) / 255.0,
            blue: CGFloat(min(max(0, blue), 255)) / 255.0,
            alpha: CGFloat(min(max(0, alpha), 255)) / 255.0
        )
    }

    func rgbaComponents() -> RGBAComponents {
        guard
            let converted = cgColor.converted(
                to: CGColorSpaceCreateDeviceRGB(),
                intent: .defaultIntent,
                options: nil
            ),
            let values = converted.components
        else {
            return .init(
                red: 0,
                green: 0,
                blue: 0,
                alpha: 255
            )
        }

        switch values.count {
        case 2:
            let white = component255(values[0])
            let alpha = component255(values[1])
            return .init(
                red: white,
                green: white,
                blue: white,
                alpha: alpha
            )
        case 4:
            return .init(
                red: component255(values[0]),
                green: component255(values[1]),
                blue: component255(values[2]),
                alpha: component255(values[3])
            )
        default:
            return .init(
                red: 0,
                green: 0,
                blue: 0,
                alpha: 255
            )
        }
    }
}

public struct RGBAComponents: Equatable {
    public let red: Int
    public let green: Int
    public let blue: Int
    public let alpha: Int

    public init(red: Int, green: Int, blue: Int, alpha: Int) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public var alphaCGFloat: CGFloat {
        CGFloat(alpha) / 255.0
    }
}

private func component255(_ value: CGFloat) -> Int {
    Int(min(max(value * 255.0, 0), 255).rounded())
}
