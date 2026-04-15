//
//  IntSliderView.swift
//  TextureLayerView
//
//  Created by Eisuke Kusachi on 2025/08/07.
//

import SwiftUI

struct IntSliderView: View {
    @Binding private var value: Int

    private var range: ClosedRange<Float>

    private var onEditing: ((Int) -> Void)?
    private var onEditingChanged: ((Bool, Int) -> Void)?

    init(
        _ value: Binding<Int>,
        range: ClosedRange<Int>,
        onEditing: ((Int) -> Void)? = nil,
        onEditingChanged: ((Bool, Int) -> Void)? = nil
    ) {
        self._value = value
        self.range = Float(range.lowerBound)...Float(range.upperBound)
        self.onEditing = onEditing
        self.onEditingChanged = onEditingChanged
    }

    var body: some View {
        Slider(
            value: Binding(
                get: { Float(value) },
                set: {
                    value = Int($0)
                    onEditing?(value)
                }
            ),
            in: range,
            step: 1,
            onEditingChanged: { isEditing in
                onEditingChanged?(isEditing, value)
            }
        )
    }
}

private struct PreviewView: View {

    @State var value: Int = 100

    var body: some View {
        IntSliderView(
            $value,
            range: 0...255
        )
        .padding()
    }
}

#Preview {
    PreviewView()
}
