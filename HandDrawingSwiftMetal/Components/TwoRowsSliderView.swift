//
//  TwoRowsSliderView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/01/02.
//

import SwiftUI

struct TwoRowsSliderView: View {

    let title: String
    @Binding var value: Int
    let style: SliderStyle
    var range = 0 ... 255
    var completion: ((Int) -> Void)?

    var buttonSize: CGFloat = 20
    var valueLabelWidth: CGFloat = 64

    var body: some View {
        VStack(spacing: 4) {
            buttons
            IntSlider(value: $value, in: range, completion: completion)
                .environment(\.sliderStyle, style)
        }
    }

    private var buttons: some View {
        HStack(spacing: 0) {
            minusButton
            Spacer()
            valueLabel
            Spacer()
            plusButton
        }
    }

    private var minusButton: some View {
        Button(action: {
            value = max(value - 1, range.lowerBound)
            completion?(value)
        },
               label: {
            Image(systemName: "minus")
                .frame(width: buttonSize, height: buttonSize)
                .foregroundColor(Color(uiColor: .systemBlue))
        })
    }

    private var plusButton: some View {
        Button(action: {
            value = min(value + 1, range.upperBound)
            completion?(value)
        },
               label: {
            Image(systemName: "plus")
                .frame(width: buttonSize, height: buttonSize)
                .foregroundColor(Color(uiColor: .systemBlue))
        })
    }

    private var valueLabel: some View {
        HStack {
            Spacer()
            Text("\(title):")
                .font(.footnote)
                .foregroundColor(Color(uiColor: .gray))
                .frame(width: valueLabelWidth, alignment: .trailing)

            Spacer()
                .frame(width: 12)

            Text("\(value)")
                .font(.footnote)
                .foregroundColor(Color(uiColor: .gray))
                .frame(width: valueLabelWidth, alignment: .leading)
            Spacer()
        }
    }
}

#Preview {
    @State var alpha: Int = 125
    let sliderStyle = SliderStyleImpl(
        trackLeftColor: UIColor(named: "trackColor")!)

    return TwoRowsSliderView(title: "Alpha",
                             value: $alpha,
                             style: sliderStyle)
}
