//
//  TwoRowsSliderView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/01/02.
//

import SwiftUI

public struct TwoRowsSliderView: View {

    @ObservedObject var viewModel: TextureLayerViewModel

    private let title: String
    private let range: ClosedRange<Int>

    private var buttonSize: CGFloat

    public init(
        viewModel: TextureLayerViewModel,
        title: String,
        range: ClosedRange<Int>,
        buttonSize: CGFloat = 20
    ) {
        self.viewModel = viewModel
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
                $viewModel.currentAlpha,
                range: range,
                onEditing: { alpha in
                    viewModel.onChangeCurrentAlpha(alpha)
                },
                onEditingChanged: { dragging, alpha in
                    viewModel.isAlphaSliderDragging = dragging
                    viewModel.onChangeCurrentAlpha(alpha)
                }
            )
        }
    }

    private var minusButton: some View {
        Button(
            action: {
                viewModel.onChangeCurrentAlpha(
                    max(viewModel.currentAlpha - 1, range.lowerBound)
                )
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

            Text("\(viewModel.currentAlpha)")
                .font(.footnote)
                .foregroundColor(Color(uiColor: .gray))
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
        }
    }

    private var plusButton: some View {
        Button(
            action: {
                viewModel.onChangeCurrentAlpha(
                    min(viewModel.currentAlpha + 1, range.upperBound)
                )
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

    private let viewModel = TextureLayerViewModel()

    var body: some View {
        TwoRowsSliderView(
            viewModel: viewModel,
            title: "Alpha",
            range: 0...255
        )
        .padding()
    }
}

#Preview {
    PreviewView()
}
