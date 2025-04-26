//
//  TextureLayerView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/31.
//

import SwiftUI

struct TextureLayerView: View {

    @ObservedObject var viewModel: TextureLayerViewModel

    @State var isTextFieldPresented: Bool = false
    @State var textFieldTitle: String = ""

    var roundedRectangleWithArrow: RoundedRectangleWithArrow

    let sliderStyle = SliderStyleImpl(
        trackLeftColor: UIColor(named: "trackColor")!)
    let range = 0 ... 255

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
                    viewModel: viewModel,
                    didTapLayer: { layer in
                        viewModel.selectLayer(layer.id)
                    },
                    didTapVisibility: { layer, isVisible in
                        viewModel.updateLayer(id: layer.id, isVisible: isVisible)
                    },
                    didMove: { source, destination in
                        viewModel.moveLayer(fromListOffsets: source, toListOffset: destination)
                    }
                )

                TwoRowsSliderView(
                    title: "Alpha",
                    value: viewModel.selectedLayer?.alpha ?? 0,
                    style: sliderStyle,
                    range: range,
                    didChange: { value in
                        guard let selectedLayer = viewModel.selectedLayer else { return }
                        viewModel.updateLayer(id: selectedLayer.id, alpha: value)
                    }
                )
                .padding(.top, 4)
                .padding([.leading, .trailing, .bottom], 8)
            }
            .padding(roundedRectangleWithArrow.edgeInsets())
        }
    }

}

extension TextureLayerView {

    func toolbar(
        _ viewModel: TextureLayerViewModel,
        changeTitle: ((TextureLayerModel, String) -> Void)? = nil
    ) -> some View {
        let buttonSize: CGFloat = 20

        return HStack {
            Button(
                action: {
                    viewModel.insertLayer(
                        at: viewModel.newIndex
                    )
                },
                label: {
                    Image(systemName: "plus.circle").buttonModifier(diameter: buttonSize)
                }
            )

            Spacer().frame(width: 16)

            Button(
                action: {
                    viewModel.removeLayer()
                },
                label: {
                    Image(systemName: "minus.circle").buttonModifier(diameter: buttonSize)
                }
            )

            Spacer().frame(width: 16)

            Button(
                action: {
                    textFieldTitle = viewModel.selectedLayer?.title ?? ""
                    isTextFieldPresented = true
                },
                label: {
                    Image(systemName: "pencil").buttonModifier(diameter: buttonSize)
                }
            )
            .hidden()
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
        CanvasModel(
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

    init() {
        viewModel = .init(
            canvasState: canvasState,
            textureRepository: TextureMockRepository()
        )
    }
    var body: some View {
        TextureLayerView(
            viewModel: viewModel,
            roundedRectangleWithArrow: RoundedRectangleWithArrow()
        )
        .frame(width: 320, height: 300)
    }

}
