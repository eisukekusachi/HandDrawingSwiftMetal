//
//  File.swift
//  TextureLayerView
//
//  Created by Eisuke Kusachi on 2025/08/07.
//

import SwiftUI

public struct IntSliderView: View {
    @Binding private var value: Int
    private var range: ClosedRange<Float>
    private var onEditingChanged: ((Bool) -> Void)?

    init(
        _ value: Binding<Int>,
        range: ClosedRange<Int>,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self._value = value
        self.range = Float(range.lowerBound)...Float(range.upperBound)
        self.onEditingChanged = onEditingChanged
    }

    var body: some View {
        Slider(
            value: Binding(
                get: { Float(value) },
                set: { value = Int($0) }
            ),
            in: range,
            step: 1,
            onEditingChanged: { isEditing in
                onEditingChanged?(isEditing)
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
