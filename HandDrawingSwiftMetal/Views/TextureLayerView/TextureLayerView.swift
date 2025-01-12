//
//  TextureLayerView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/31.
//

import SwiftUI

struct TextureLayerView<T: TextureLayerProtocol>: View {

    @ObservedObject var textureLayers: Layers<T>
    @ObservedObject var roundedRectangleWithArrow: RoundedRectangleWithArrow

    @State var isTextFieldPresented: Bool = false
    @State var textFieldTitle: String = ""

    var didTapLayer: (T) -> Void
    var didTapAddButton: () -> Void
    var didTapRemoveButton: () -> Void
    var didTapVisibility: (T, Bool) -> Void
    var didStartChangingAlpha: (T) -> Void
    var didChangeAlpha: (T, Int) -> Void
    var didFinishChangingAlpha: (T) -> Void
    var didEditTitle: (T, String) -> Void
    var didMove: (IndexSet, Int) -> Void

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
                    textureLayers: textureLayers,
                    didTapAddButton: didTapAddButton,
                    didTapRemoveButton: didTapRemoveButton,
                    didEditTitle: didEditTitle
                )

                TextureLayerListView<T>(
                    textureLayers: textureLayers,
                    didTapLayer: { layer in
                        didTapLayer(layer)
                    },
                    didTapVisibility: { layer, isVisibility in
                        didTapVisibility(layer, isVisibility)
                    },
                    didMove: { source, destination in
                        didMove(source, destination)
                    }
                )

                TwoRowsSliderView(
                    title: "Alpha",
                    value: textureLayers.selectedLayer?.alpha ?? 0,
                    style: sliderStyle,
                    range: range,
                    didStartChanging: {
                        guard let selectedLayer = textureLayers.selectedLayer else { return }
                        didStartChangingAlpha(selectedLayer)
                    },
                    didChange: { value in
                        guard let selectedLayer = textureLayers.selectedLayer else { return }
                        didChangeAlpha(selectedLayer, value)
                    },
                    didFinishChanging: {
                        guard let selectedLayer = textureLayers.selectedLayer else { return }
                        didFinishChangingAlpha(selectedLayer)
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
        textureLayers: Layers<T>,
        didTapAddButton: @escaping () -> Void,
        didTapRemoveButton: @escaping () -> Void,
        didEditTitle: @escaping (T, String) -> Void
    ) -> some View {
        let buttonSize: CGFloat = 20

        return HStack {
            Button(
                action: {
                    didTapAddButton()
                },
                label: {
                    Image(systemName: "plus.circle").buttonModifier(diameter: buttonSize)
                }
            )

            Spacer().frame(width: 16)

            Button(
                action: {
                    didTapRemoveButton()
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
                    didEditTitle(selectedLayer, textFieldTitle)
                })
                Button("Cancel", action: {})
            }
            Spacer()
        }
        .padding(8)
    }

}

#Preview {

    TextureLayerView(
        textureLayers: TextureLayers(),
        roundedRectangleWithArrow: RoundedRectangleWithArrow(),
        didTapLayer: { layer in
            print("Tap layer")
        },
        didTapAddButton: {
            print("Add")
        },
        didTapRemoveButton: {
            print("Remove")
        },
        didTapVisibility: { layer, value in
            print("Change visibility")
        },
        didStartChangingAlpha: { layer in
            print("Start changing alpha")
        },
        didChangeAlpha: { layer, value in
            print("Change alpha")
        },
        didFinishChangingAlpha: { layer in
            print("Finish changing alpha")
        },
        didEditTitle: { layer, value in
            print("Change title")
        },
        didMove: { source, destination in
            print("Moved")
        }
    )

}
