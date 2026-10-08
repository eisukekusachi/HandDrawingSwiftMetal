//
//  Created by Eisuke Kusachi
//

import SwiftUI

/// Pen-width control: vertical slider, numeric value, and vertical stepper in one column.
struct VerticalDiameterSlider: View {

    @Binding var value: Int

    private let range: ClosedRange<Int>

    private let onEditingChanged: ((Bool) -> Void)?

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
        GeometryReader { geometry in
            let layout = LayoutMetrics(availableHeight: geometry.size.height)

            VStack(
                alignment: .center,
                spacing: LayoutMetrics.controlSpacing
            ) {
                slider(length: layout.sliderLength)
                valueLabel
                stepper
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .bottomLeading
            )
        }
    }
}

private extension VerticalDiameterSlider {
    struct LayoutMetrics {
        /// Vertical track length when there is enough space (e.g. portrait).
        static let preferredSliderLength: CGFloat = 256
        /// Shortest slider track; keeps the thumb reachable on compact heights (e.g. landscape).
        static let minSliderLength: CGFloat = 72
        /// Fixed vertical size of the rotated system stepper (+/−); not scaled with height.
        static let stepperLength: CGFloat = 96
        /// Width of the rotated slider after layout (touch target along the screen horizontal axis).
        static let sliderThickness: CGFloat = 44
        /// Width of the rotated stepper after layout.
        static let stepperThickness: CGFloat = 36
        /// Gap between slider, value label, and stepper in the column.
        static let controlSpacing: CGFloat = 8
        /// Reserved height for the monospaced diameter number between slider and stepper.
        static let valueLabelHeight: CGFloat = 22

        let sliderLength: CGFloat

        init(availableHeight: CGFloat) {
            guard availableHeight.isFinite, availableHeight > 0 else {
                sliderLength = Self.minSliderLength
                return
            }

            let spacingTotal = Self.controlSpacing * 2
            let fixedChrome =
                spacingTotal + Self.valueLabelHeight + Self.stepperLength

            sliderLength = min(
                Self.preferredSliderLength,
                max(Self.minSliderLength, availableHeight - fixedChrome)
            )
        }
    }

    func slider(length: CGFloat) -> some View {
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
        .frame(width: length, height: LayoutMetrics.sliderThickness)
        .frame(width: LayoutMetrics.sliderThickness, height: length)
    }

    var valueLabel: some View {
        Text(value, format: .number)
            .monospacedDigit()
            .foregroundStyle(.primary)
            .frame(height: LayoutMetrics.valueLabelHeight)
    }

    var stepper: some View {
        Stepper(value: $value, in: range) {
            Text(verbatim: "")
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
        .foregroundStyle(.primary)
        .rotationEffect(.degrees(-90))
        .frame(width: LayoutMetrics.stepperLength, height: LayoutMetrics.stepperThickness)
        .frame(width: LayoutMetrics.stepperThickness, height: LayoutMetrics.stepperLength)
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

private struct VerticalDiameterSliderCompactPreview: View {

    @State private var value = 32

    var body: some View {
        VerticalDiameterSlider(value: $value)
            .frame(width: 44, height: 287)
            .padding()
    }
}

#Preview("Regular height") {
    VerticalDiameterSliderPreview()
}

#Preview("Landscape height") {
    VerticalDiameterSliderCompactPreview()
}
#endif
