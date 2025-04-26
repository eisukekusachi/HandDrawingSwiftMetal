//
//  TwoRowsSliderView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/01/02.
//

import SwiftUI

struct TwoRowsSliderView: View {

    @Binding var value: Int
    @Binding var isPressed: Bool

    let title: String
    let range: ClosedRange<Int>

    var buttonSize: CGFloat = 20
    var valueLabelWidth: CGFloat = 64

    var body: some View {
        VStack(spacing: 4) {
            buttons
            IntSlider(
                value: $value,
                isPressed: $isPressed,
                in: range
            )
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
                .frame(width: valueLabelWidth, alignment: .trailing)

            Spacer()
                .frame(width: 8)

            Text("\(value)")
                .font(.footnote)
                .foregroundColor(Color(uiColor: .gray))
                .frame(width: valueLabelWidth, alignment: .leading)
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
                    .foregroundColor(Color(uiColor: .systemBlue))
            }
        )
    }
}

#Preview {
    PreviewView()
}

private struct PreviewView: View {

    @State var alpha: Int = 125
    @State var isPressed: Bool = false

    @State var alphaArray: [Int] = [25, 125, 225]
    @State var isPressedArray: [Bool] = [false, false, false]

    let sliderStyle = DefaultSliderStyle(
        trackLeftColor: UIColor(named: "trackColor")
    )

    var body: some View {
        ForEach(alphaArray.indices, id: \.self) { index in
            TwoRowsSliderView(
                value: $alphaArray[index],
                isPressed: $isPressedArray[index],
                title: "Alpha",
                range: 0 ... 255
            )
            .padding()
        }

    }
}
