//
//  PaletteEditView
//
//  Created by Eisuke Kusachi on 2026/07/02.
//

import SwiftUI
import UIKit

/// A toolbar with an alpha slider and remove / duplicate action buttons.
struct BottomActionToolbar: View {
    @Binding private var alpha: Int

    private let gradientColors: [UIColor]
    private let onRemove: (() -> Void)?
    private let onDuplicate: (() -> Void)?

    private let spacing: CGFloat = 16
    private let buttonSize: CGFloat = 22
    private let buttonSpacing: CGFloat = 16
    private let toolbarHeight: CGFloat = 38

    init(
        alpha: Binding<Int>,
        gradientColors: [UIColor],
        onRemove: (() -> Void)? = nil,
        onDuplicate: (() -> Void)? = nil
    ) {
        self._alpha = alpha
        self.gradientColors = gradientColors
        self.onRemove = onRemove
        self.onDuplicate = onDuplicate
    }

    var body: some View {
        VStack(spacing: spacing) {
            SliderWithStepper(
                title: "Alpha",
                value: $alpha,
                gradientColors: gradientColors
            )

            HStack(alignment: .center, spacing: buttonSpacing) {
                Button(action: { onRemove?() }) {
                    Image(systemName: "trash")
                        .toolbarIcon(size: buttonSize, color: .systemRed)
                }

                Button(action: { onDuplicate?() }) {
                    Image(systemName: "plus.rectangle.on.rectangle")
                        .toolbarIcon(size: buttonSize)
                }

                Spacer()
            }
            .padding(8)
            .frame(height: toolbarHeight)
        }
    }
}

private extension Image {
    func toolbarIcon(size: CGFloat, color: UIColor = .systemBlue) -> some View {
        resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundColor(Color(uiColor: color))
    }
}

#if DEBUG
#Preview {
    BottomActionToolbarPreview()
}

private struct BottomActionToolbarPreview: View {
    @State private var alpha = 128

    var body: some View {
        BottomActionToolbar(
            alpha: $alpha,
            gradientColors: [
                UIColor.black.withAlphaComponent(0),
                UIColor.black.withAlphaComponent(1)
            ],
            onRemove: {},
            onDuplicate: {}
        )
        .padding()
    }
}
#endif
