//
//  TwoRowsSliderView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/01/02.
//

import SwiftUI

public struct TwoRowsSliderView: View {

    @Binding var value : Float

    let title: String
    let range: ClosedRange<Float>

    var buttonSize: CGFloat

    public init(
        value: Binding<Float>,
        title: String,
        range: ClosedRange<Float>,
        buttonSize: CGFloat = 20
    ) {
        self._value = value
        self.title = title
        self.range = range
        self.buttonSize = buttonSize
    }

    public var body: some View {
        VStack(spacing: 4) {
            buttons
            Slider(value: $value, in: range)
        }
    }

    private var buttons: some View {
        HStack {
            minusButton
            Spacer()
            valueLabel
            Spacer()
            plusButton
        }
    }

    private var minusButton: some View {
        Button(
            action: {
                value = (max(value - 1, range.lowerBound))
            },
            label: {
                Image(systemName: "minus")
                    .frame(width: buttonSize, height: buttonSize)
                    .foregroundColor(Color(uiColor: .systemBlue))
            }
        )
    }

    private var valueLabel: some View {
        HStack {
            Spacer()
            Text("\(title):")
                .font(.footnote)
                .foregroundColor(Color(uiColor: .gray))
                .frame(maxWidth: .infinity, alignment: .trailing)

            Spacer()
                .frame(width: 8)

            Text("\(value)")
                .font(.footnote)
                .foregroundColor(Color(uiColor: .gray))
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
        }
    }

    private var plusButton: some View {
        Button(
            action: {
                value = (min(value + 1, range.upperBound))
            },
            label: {
                Image(systemName: "plus")
                    .frame(width: buttonSize, height: buttonSize)
                    .foregroundColor(.init(uiColor: .systemBlue))
            }
        )
    }
}

#Preview {
    PreviewView()
}

private struct PreviewView: View {

    @State var value: Float = 0

    var body: some View {
        TwoRowsSliderView(
            value: $value,
            title: "Alpha",
            range: 0 ... 255
        )
        .padding()
    }
}
