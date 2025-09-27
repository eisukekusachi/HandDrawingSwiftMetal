//
//  TwoRowsSliderView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/01/02.
//

import SwiftUI

public struct TwoRowsSliderView: View {

    @Binding private var value : Int

    @Binding private var isDragging : Bool

    private let title: String
    private let range: ClosedRange<Int>

    private var buttonSize: CGFloat

    public init(
        value: Binding<Int>,
        isDragging: Binding<Bool>,
        title: String,
        range: ClosedRange<Int>,
        buttonSize: CGFloat = 20
    ) {
        self._value = value
        self._isDragging = isDragging
        self.title = title
        self.range = range
        self.buttonSize = buttonSize
    }

    public var body: some View {
        VStack(spacing: 4) {
            HStack {
                minusButton
                Spacer()
                valueLabel
                Spacer()
                plusButton
            }
            IntSliderView(
                $value,
                range: range
            ) { dragging in
                self.isDragging = dragging
            }
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

private struct PreviewView: View {

    @State var value: Int = 0
    @State var isDragging: Bool = false

    var body: some View {
        TwoRowsSliderView(
            value: $value,
            isDragging: $isDragging,
            title: "Alpha",
            range: 0...255
        )
        .padding()
    }
}

#Preview {
    PreviewView()
}
