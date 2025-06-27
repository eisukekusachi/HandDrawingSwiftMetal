//
//  TwoRowsSliderView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/01/02.
//

import SwiftUI

struct TwoRowsSliderView: View {

    @ObservedObject var sliderValue: SliderValue

    let title: String
    let range: ClosedRange<Int>

    var buttonSize: CGFloat = 20

    var body: some View {
        VStack(spacing: 4) {
            buttons
            IntSlider(
                value: $sliderValue.value,
                isHandleDragging: $sliderValue.isHandleDragging,
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
                sliderValue.value = (max(sliderValue.value - 1, range.lowerBound))
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

            Text("\(sliderValue.value)")
                .font(.footnote)
                .foregroundColor(Color(uiColor: .gray))
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
        }
    }

    private var plusButton: some View {
        Button(
            action: {
                sliderValue.value = (min(sliderValue.value + 1, range.upperBound))
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
    var sliderValues: [SliderValue] = [
        .init(value: 25),
        .init(value: 125),
        .init(value: 225)
    ]
    var body: some View {
        ForEach(sliderValues.indices, id: \.self) { index in
            TwoRowsSliderView(
                sliderValue: sliderValues[index],
                title: "Alpha",
                range: 0 ... 255
            )
            .padding()
        }

    }
}

