//
//  PaletteView
//
//  Created by Eisuke Kusachi on 2026/08/10.
//

import SwiftUI

struct DoubleStrokeCircle: View {
    let size: CGFloat
    let outerColor: Color
    let innerColor: Color
    let outerWidth: CGFloat
    let innerWidth: CGFloat

    init(
        size: CGFloat,
        outerColor: Color = .black,
        innerColor: Color = .white,
        outerWidth: CGFloat = 4,
        innerWidth: CGFloat = 3
    ) {
        self.size = size
        self.outerColor = outerColor
        self.innerColor = innerColor
        self.outerWidth = outerWidth
        self.innerWidth = innerWidth
    }

    var body: some View {
        Circle()
            .strokeBorder(outerColor, lineWidth: outerWidth)
            .overlay(
                Circle()
                    .inset(by: outerWidth - innerWidth)
                    .strokeBorder(innerColor, lineWidth: innerWidth)
            )
            .frame(width: size, height: size)
    }
}

#Preview {
    let size: CGFloat = 44

    VStack {
        ZStack {
            Circle()
                .fill(Color(uiColor: .red))
                .frame(width: size, height: size)

            DoubleStrokeCircle(size: size)
        }

        ZStack {
            Circle()
                .fill(Color(uiColor: .blue))
                .frame(width: size, height: size)

            DoubleStrokeCircle(size: size)
        }

        ZStack {
            Circle()
                .fill(Color(uiColor: .green))
                .frame(width: size, height: size)

            DoubleStrokeCircle(size: size)
        }
    }
}
