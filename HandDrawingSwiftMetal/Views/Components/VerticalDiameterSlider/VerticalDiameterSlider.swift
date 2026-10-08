//
//  Created by Eisuke Kusachi
//

import SwiftUI

/// Pen-width control: vertical slider, numeric value, and vertical stepper in one column.
struct VerticalDiameterSlider: View {

    @Binding var value: Int

    private let range: ClosedRange<Int>

    private let onEditingChanged: ((Bool) -> Void)?

    private let sliderLength: CGFloat = 256

    private let sliderThickness: CGFloat = 44

    private let stepperLength: CGFloat = 96

    private let stepperThickness: CGFloat = 36

    private let controlSpacing: CGFloat = 8

    init(
        value: Binding<Int>,
        in range: ClosedRange<Int> = 1...64,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self._value = value
        self.range = range
        self.onEditingChanged = onEditingChanged
    }

    var body: some View {
        VStack(
            alignment: .center,
            spacing: controlSpacing
        ) {
            verticalSlider
            valueLabel
            verticalStepper
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .bottomLeading
        )
    }
}

private extension VerticalDiameterSlider {

    var verticalSlider: some View {
        Slider(
            value: Binding(
                get: { Double(value) },
                set: { value = Int($0.rounded()) }
            ),
            in: Double(range.lowerBound)...Double(range.upperBound),
            step: 1,
            onEditingChanged: { isEditing in
                onEditingChanged?(isEditing)
            }
        )
        .rotationEffect(.degrees(-90))
        .frame(width: sliderLength, height: sliderThickness)
        .frame(width: sliderThickness, height: sliderLength)
    }

    var valueLabel: some View {
        Text(value, format: .number)
            .monospacedDigit()
            .foregroundStyle(.primary)
    }

    var verticalStepper: some View {
        Stepper(value: $value, in: range) {
            Text(verbatim: "")
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
        .foregroundStyle(.primary)
        .rotationEffect(.degrees(-90))
        .frame(width: stepperLength, height: stepperThickness)
        .frame(width: stepperThickness, height: stepperLength)
    }
}

#if DEBUG
private struct VerticalDiameterSliderPreview: View {

    @State private var value = 8

    var body: some View {
        VerticalDiameterSlider(value: $value)
            .frame(width: 44, height: 380)
            .padding()
    }
}

#Preview {
    VerticalDiameterSliderPreview()
}
#endif
