//
//  LayerView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/31.
//

import SwiftUI

struct LayerView: View {

    @ObservedObject var layerManager: LayerManager
    @ObservedObject var layerViewPresentation: LayerViewPresentation

    @State var isTextFieldPresented: Bool = false
    @State var textFieldTitle: String = ""

    var didTapLayer: (LayerEntity) -> Void
    var didTapAddButton: () -> Void
    var didTapRemoveButton: () -> Void
    var didTapVisibility: (LayerEntity, Bool) -> Void
    var didChangeAlpha: (LayerEntity, Int) -> Void
    var didEditTitle: (LayerEntity, String) -> Void
    var didMove: (LayerEntity, IndexSet, Int) -> Void

    let arrowSize: CGSize = .init(width: 18, height: 14)
    let roundedCorner: CGFloat = 12

    let sliderStyle = SliderStyleImpl(
        trackLeftColor: UIColor(named: "trackColor")!
    )
    let range = 0 ... 255

    var body: some View {
        let edgeInsets: EdgeInsets = .init(top: roundedCorner + arrowSize.height,
                                           leading: roundedCorner,
                                           bottom: roundedCorner,
                                           trailing: roundedCorner)
        ZStack {
            viewWithTopArrow(
                presentation: layerViewPresentation,
                arrowSize: arrowSize,
                roundedCorner: roundedCorner
            )

            VStack {
                toolbar(
                    layerManager: layerManager,
                    didTapAddButton: didTapAddButton,
                    didTapRemoveButton: didTapRemoveButton,
                    didEditTitle: didEditTitle
                )

                LayerListView(
                    layerManager: layerManager,
                    didTapLayer: { layer in
                        didTapLayer(layer)
                    },
                    didTapVisibility: { layer, isVisibility in
                        didTapVisibility(layer, isVisibility)
                    },
                    didMove: { layer, source, destination in
                        didMove(layer, source, destination)
                    }
                )

                TwoRowsSliderView(
                    title: "Alpha",
                    value: layerManager.selectedLayerAlpha,
                    style: sliderStyle,
                    range: range,
                    didChange: { value in
                        guard let selectedLayer = layerManager.selectedLayer else { return }
                        didChangeAlpha(selectedLayer, value)
                    }
                )
                .padding(.top, 4)
                .padding([.leading, .trailing, .bottom], 8)
            }
            .padding(edgeInsets)
        }
    }

}

extension LayerView {

    func toolbar(
        layerManager: LayerManager,
        didTapAddButton: @escaping () -> Void,
        didTapRemoveButton: @escaping () -> Void,
        didEditTitle: @escaping (LayerEntity, String) -> Void
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
                    textFieldTitle = layerManager.selectedLayer?.title ?? ""
                    isTextFieldPresented = true
                },
                label: {
                    Image(systemName: "pencil").buttonModifier(diameter: buttonSize)
                }
            )
            .alert("Enter a title", isPresented: $isTextFieldPresented) {
                TextField("Enter a title", text: $textFieldTitle)
                Button("OK", action: {
                    guard let selectedLayer = layerManager.selectedLayer else { return }
                    layerManager.updateTitle(selectedLayer,
                                             $textFieldTitle.wrappedValue)
                })
                Button("Cancel", action: {})
            }
            Spacer()
        }
        .padding(8)
    }

    func viewWithTopArrow(
        presentation: LayerViewPresentation,
        arrowSize: CGSize,
        roundedCorner: CGFloat
    ) -> some View {
        GeometryReader { geometry in
            let minX0 = 0.0
            let minX1 = roundedCorner
            let maxX1 = geometry.size.width - roundedCorner
            let maxX0 = geometry.size.width

            let minY0 = arrowSize.height
            let minY1 = arrowSize.height + roundedCorner
            let maxY1 = geometry.size.height - roundedCorner
            let maxY0 = geometry.size.height

            let pointMinX = minX1 + arrowSize.width * 0.5
            let pointMaxX = maxX1 - arrowSize.width * 0.5
            let pointX = min(max(pointMinX, presentation.arrowPointX), pointMaxX)

            let arrowStartX = pointX - arrowSize.width * 0.5
            let arrowEndX = pointX + arrowSize.width * 0.5

            let minX0minY1: CGPoint = .init(x: minX0, y: minY1)
            let minX1minY0: CGPoint = .init(x: minX1, y: minY0)
            let maxX1minY0: CGPoint = .init(x: maxX1, y: minY0)
            let maxX0minY1: CGPoint = .init(x: maxX0, y: minY1)

            let maxX0maxY1: CGPoint = .init(x: maxX0, y: maxY1)
            let maxX1maxY0: CGPoint = .init(x: maxX1, y: maxY0)
            let minX1maxY0: CGPoint = .init(x: minX1, y: maxY0)
            let minX0maxY1: CGPoint = .init(x: minX0, y: maxY1)

            Path { path in
                path.move(to: minX0minY1)
                path.addQuadCurve(to: minX1minY0,
                                  control: .init(x: minX0, y: minY0))

                path.addLine(to: .init(x: arrowStartX, y: minY0))
                path.addLine(to: .init(x: pointX, y: 0.0))
                path.addLine(to: .init(x: arrowEndX, y: minY0))

                path.addLine(to: maxX1minY0)
                path.addQuadCurve(to: maxX0minY1,
                                  control: .init(x: maxX0, y: minY0))
                path.addLine(to: maxX0maxY1)
                path.addQuadCurve(to: maxX1maxY0,
                                  control: .init(x: maxX0, y: maxY0))
                path.addLine(to: minX1maxY0)
                path.addQuadCurve(to: minX0maxY1,
                                  control: .init(x: minX0, y: maxY0))
                path.closeSubpath()
            }
            .fill(Color.white.opacity(0.9))

            // For iOS 15 compatibility
            Path { path in
                path.move(to: minX0minY1)
                path.addQuadCurve(to: minX1minY0,
                                  control: .init(x: minX0, y: minY0))

                path.addLine(to: .init(x: arrowStartX, y: minY0))
                path.addLine(to: .init(x: pointX, y: 0.0))
                path.addLine(to: .init(x: arrowEndX, y: minY0))

                path.addLine(to: maxX1minY0)
                path.addQuadCurve(to: maxX0minY1,
                                  control: .init(x: maxX0, y: minY0))
                path.addLine(to: maxX0maxY1)
                path.addQuadCurve(to: maxX1maxY0,
                                  control: .init(x: maxX0, y: maxY0))
                path.addLine(to: minX1maxY0)
                path.addQuadCurve(to: minX0maxY1,
                                  control: .init(x: minX0, y: maxY0))
                path.closeSubpath()
            }
            .stroke(lineWidth: 0.5)
            .fill(Color.black)
        }
    }

}

#Preview {

    LayerView(
        layerManager: LayerManager(),
        layerViewPresentation: LayerViewPresentation(),
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
        didChangeAlpha: { layer, value in
            print("Change alpha")
        },
        didEditTitle: { layer, value in
            print("Change title")
        },
        didMove: { layer, source, destination in
            print("Moved")
        }
    )

}
