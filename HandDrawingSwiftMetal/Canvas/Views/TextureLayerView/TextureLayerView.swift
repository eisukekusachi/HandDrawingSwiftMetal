//
//  TextureLayerView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/31.
//

import SwiftUI

struct TextureLayerView: View {

    @ObservedObject var textureLayers: TextureLayers

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
                    textureLayers,
                    changeTitle: { layer, title in
                        textureLayers.updateLayer(id: layer.id, title: title)
                    }
                )

                TextureLayerListView(
                    textureLayers: textureLayers,
                    didTapLayer: { layer in
                        textureLayers.selectLayer(layer.id)
                    },
                    didTapVisibility: { layer, isVisible in
                        textureLayers.updateLayer(id: layer.id, isVisible: isVisible)
                    },
                    didMove: { source, destination in
                        textureLayers.moveLayer(fromListOffsets: source, toListOffset: destination)
                    }
                )

                TwoRowsSliderView(
                    title: "Alpha",
                    value: textureLayers.selectedLayer?.alpha ?? 0,
                    style: sliderStyle,
                    range: range,
                    didChange: { value in
                        guard let selectedLayer = textureLayers.selectedLayer else { return }
                        textureLayers.updateLayer(id: selectedLayer.id, alpha: value)
                    }
                )
                .padding(.top, 4)
                .padding([.leading, .trailing, .bottom], 8)
            }
            .padding(roundedRectangleWithArrow.edgeInsets)
        }
    }

}

extension TextureLayerView {

    func toolbar(
        _ textureLayers: TextureLayers,
        changeTitle: ((TextureLayerModel, String) -> Void)? = nil
    ) -> some View {
        let buttonSize: CGFloat = 20

        return HStack {
            Button(
                action: {
                    textureLayers.insertLayer(
                        at: textureLayers.newIndex
                    )
                },
                label: {
                    Image(systemName: "plus.circle").buttonModifier(diameter: buttonSize)
                }
            )

            Spacer().frame(width: 16)

            Button(
                action: {
                    textureLayers.removeLayer()
                },
                label: {
                    Image(systemName: "minus.circle").buttonModifier(diameter: buttonSize)
                }
            )

            Spacer().frame(width: 16)

            Button(
                action: {
                    textFieldTitle = textureLayers.selectedLayer?.title ?? ""
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
                    guard let selectedLayer = textureLayers.selectedLayer else { return }
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
    let textureLayers: TextureLayers

    init() {
        textureLayers = .init(
            canvasState: canvasState,
            textureRepository: TextureMockRepository()
        )
    }
    var body: some View {
        TextureLayerView(
            textureLayers: textureLayers,
            roundedRectangleWithArrow: RoundedRectangleWithArrow()
        )
        .frame(width: 320, height: 300)
    }

}
