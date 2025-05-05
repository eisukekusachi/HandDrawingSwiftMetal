//
//  TextureLayerView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/31.
//

import SwiftUI

struct TextureLayerView: View {

    @ObservedObject var viewModel: TextureLayerViewModel

    @ObservedObject var roundedRectangleWithArrow: RoundedRectangleWithArrow

    @State private var isTextFieldPresented: Bool = false
    @State private var textFieldTitle: String = ""

    private let range = 0 ... 255

    var body: some View {
        ZStack {
            roundedRectangleWithArrow.viewWithTopArrow(
                arrowSize: roundedRectangleWithArrow.arrowSize,
                roundedCorner: roundedRectangleWithArrow.roundedCorner
            )

            VStack {
                toolbar(
                    viewModel,
                    changeTitle: { layer, title in
                        viewModel.updateLayer(id: layer.id, title: title)
                    }
                )

                TextureLayerListView(
                    viewModel: viewModel
                )

                TwoRowsSliderView(
                    value: $viewModel.selectedLayerAlpha,
                    isPressed: $viewModel.isSliderHandleDragging,
                    title: "Alpha",
                    range: range
                )
                .padding(.top, 4)
                .padding([.leading, .trailing, .bottom], 8)
            }
            .padding(roundedRectangleWithArrow.edgeInsets())
        }
    }

}

extension TextureLayerView {

    private func toolbar(
        _ viewModel: TextureLayerViewModel,
        changeTitle: ((TextureLayerModel, String) -> Void)? = nil
    ) -> some View {
        let buttonSize: CGFloat = 20

        return HStack {
            Button(
                action: {
                    viewModel.insertLayer(
                        textureSize: viewModel.textureSize,
                        at: viewModel.newInsertIndex
                    )
                },
                label: {
                    Image(systemName: "plus.circle")
                        .buttonModifier(diameter: buttonSize)
                }
            )

            Spacer().frame(width: 16)

            Button(
                action: {
                    viewModel.removeLayer()
                },
                label: {
                    Image(systemName: "minus.circle")
                        .buttonModifier(diameter: buttonSize)
                }
            )

            Spacer().frame(width: 16)

            Button(
                action: {
                    textFieldTitle = viewModel.selectedLayer?.title ?? ""
                    isTextFieldPresented = true
                },
                label: {
                    Image(systemName: "pencil")
                        .buttonModifier(diameter: buttonSize)
                }
            )
            .alert("Enter a title", isPresented: $isTextFieldPresented) {
                TextField("Enter a title", text: $textFieldTitle)
                Button("OK", action: {
                    guard let selectedLayer = viewModel.selectedLayer else { return }
                    changeTitle?(selectedLayer, textFieldTitle)
                })
                Button("Cancel", action: {})
            }
            Spacer()
        }
        .padding(8)
    }

}

#Preview {
    PreviewView()
}

private struct PreviewView: View {
    let canvasState = CanvasState(
        .init(
            textureSize: .init(width: 44, height: 44),
            layerIndex: 1,
            layers: [
                .init(title: "Layer0", alpha: 255),
                .init(title: "Layer1", alpha: 200),
                .init(title: "Layer2", alpha: 150),
                .init(title: "Layer3", alpha: 100),
                .init(title: "Layer4", alpha: 50),
            ]
        )
    )
    let viewModel: TextureLayerViewModel

    @StateObject var roundedRectangle = RoundedRectangleWithArrow()

    init() {
        viewModel = .init(
            canvasState: canvasState,
            textureRepository: TextureMockRepository()
        )
    }
    var body: some View {
        TextureLayerView(
            viewModel: viewModel,
            roundedRectangleWithArrow: roundedRectangle
        )
        .frame(width: 320, height: 300)
    }

}
