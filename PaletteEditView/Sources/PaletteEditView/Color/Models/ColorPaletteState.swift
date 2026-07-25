//
//  PaletteEditView
//
//  Created by Eisuke Kusachi on 2026/07/02.
//

import UIKit

@MainActor
public final class ColorPaletteState: ObservableObject {
    @Published public var selectedSegment: ColorPaletteSegment = .grid

    @Published public var rgbColor: UIColor = .black
    @Published public var alpha: Int = 255

    public var color: UIColor {
        UIColor(
            paletteColor: rgbColor,
            alpha: alpha
        )
    }

    private let onChanged: ((UIColor) -> Void)?

    public init(onChanged: ((UIColor) -> Void)? = nil) {
        self.onChanged = onChanged
    }

    public func setColor(_ color: UIColor) {
        let components = color.paletteRGBAComponents()
        rgbColor = UIColor(
            paletteRed: components.red,
            green: components.green,
            blue: components.blue,
            alpha: 255
        )
        alpha = components.alpha
    }

    public func updateAlpha(_ value: Int) {
        alpha = min(max(0, value), 255)
        onChanged?(color)
    }

    public func updateColor() {
        onChanged?(color)
    }
}
