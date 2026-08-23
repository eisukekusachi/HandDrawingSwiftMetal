//
//  SliderWithStepper.swift
//  TextureLayerView
//
//  Created by Eisuke Kusachi on 2026/08/23.
//

import SwiftUI

struct SliderWithStepper: View {
    @Binding var value: Int

    private let title: String

    private let onEditingChanged: ((Bool) -> Void)?

    private let sliderToControlsSpacing: CGFloat = 8

    init(
        title: String,
        value: Binding<Int>,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self.title = title
        self._value = value
        self.onEditingChanged = onEditingChanged
    }

    var body: some View {
        VStack(spacing: sliderToControlsSpacing) {
            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { value = Int($0.rounded()) }
                ),
                in: 0...255,
                step: 1,
                onEditingChanged: { isEditing in
                    onEditingChanged?(isEditing)
                }
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
            title: "Alpha",
            value: $value
        )
        .padding()
    }
}

#Preview {
    SliderWithStepperPreview()
}
#endif
