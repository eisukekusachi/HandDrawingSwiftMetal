//
//  PaletteEditView
//
//  Created by Eisuke Kusachi on 2026/07/25.
//

import SwiftUI
import UIKit

struct AlphaEditSection: View {
    @Binding private var alpha: Int

    private let gradientColors: [UIColor]
    private let onRemove: (() -> Void)?
    private let onDuplicate: (() -> Void)?

    private let spacing: CGFloat = 16

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

            BottomActionToolbar(
                onRemove: { onRemove?() },
                onDuplicate: { onDuplicate?() }
            )
        }
    }
}

#if DEBUG
#Preview {
    AlphaEditSectionPreview()
}

private struct AlphaEditSectionPreview: View {
    @State private var alpha = 128

    var body: some View {
        AlphaEditSection(
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
