//
//  PaletteEditView
//
//  Created by Eisuke Kusachi on 2026/07/02.
//

import SwiftUI
import UIKit

struct SliderWithStepper: View {
    @Binding var value: Int

    private let title: String

    private let gradientColors: [UIColor]

    private let sliderToControlsSpacing: CGFloat = 8

    init(
        title: String,
        value: Binding<Int>,
        gradientColors: [UIColor]
    ) {
        self.title = title
        self._value = value
        self.gradientColors = gradientColors
    }

    var body: some View {
        VStack(spacing: sliderToControlsSpacing) {
            GradientSlider(
                value: $value,
                gradientColors: gradientColors
            )

            Stepper(value: $value, in: 0...255) {
                HStack(spacing: 0) {
                    Text(title)
                        .frame(width: 64, alignment: .leading)
                    Text(value, format: .number)
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .foregroundStyle(.primary)
        }
    }
}

#if DEBUG
private struct SliderWithStepperPreview: View {
    @State private var value = 128

    var body: some View {
        SliderWithStepper(
            title: "Red",
            value: $value,
            gradientColors: [
                UIColor(red: 0, green: 0, blue: 0, alpha: 255),
                UIColor(red: 255, green: 0, blue: 0, alpha: 255)
            ]
        )
        .padding()
    }
}

#Preview {
    SliderWithStepperPreview()
}
#endif
