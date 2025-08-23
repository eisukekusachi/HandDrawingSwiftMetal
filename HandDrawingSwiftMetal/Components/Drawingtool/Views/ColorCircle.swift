//
//  ColorCircle.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/23.
//

import SwiftUI

public struct ColorCircle: View {

    let color: UIColor
    let checkeredImage: UIImage?
    let size: CGFloat
    let selected: Bool

    let tapCircle: (() -> Void)?

    public init(
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

    public var body: some View {
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
        ColorCircle(color: .red, size: 44, selected: true)
        ColorCircle(color: .blue, size: 44)
        ColorCircle(color: .green, size: 44)
        ColorCircle(color: .yellow, size: 44)
    }
}
