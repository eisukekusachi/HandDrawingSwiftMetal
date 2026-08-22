//
//  PaletteView
//
//  Created by Eisuke Kusachi on 2026/08/10.
//

import SwiftUI
import UIKit

struct ColorCircle: View {

    let color: UIColor
    let checkeredImage: UIImage?
    let size: CGFloat
    let selected: Bool

    let tapCircle: (() -> Void)?

    init(
        color: UIColor,
        checkeredImage: UIImage? = nil,
        size: CGFloat,
        selected: Bool = false,
        tapCircle: (() -> Void)? = nil
    ) {
        self.color = color
        self.checkeredImage = checkeredImage
        self.size = size
        self.selected = selected
        self.tapCircle = tapCircle
    }

    var body: some View {
        ZStack {
            if let checkeredImage {
                Image(uiImage: checkeredImage)
                    .cornerRadius(size * 0.5)
            }

            Circle()
                .fill(Color(uiColor: color))
                .frame(width: size, height: size)

            if selected {
                DoubleStrokeCircle(size: size)
            }
        }
        .frame(width: size, height: size)
        .onTapGesture {
            tapCircle?()
        }
    }
}

#Preview {
    VStack {
        ColorCircle(color: UIColor.red, size: 44, selected: true)
        ColorCircle(color: UIColor.blue, size: 44)
        ColorCircle(color: UIColor.green, size: 44)
        ColorCircle(color: UIColor.yellow, size: 44)
    }
}
