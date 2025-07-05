//
//  IntSlider.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/01/02.
//

import SwiftUI

struct IntSlider: View {

    @Binding var value: Int
    @Binding var isHandleDragging: Bool

    @State private var knobOffsetX: CGFloat?
    @State private var isDragging: Bool = false

    private let closedRange: ClosedRange<Int>

    private let style: SliderStyleProtocol

    init(
        value: Binding<Int>,
        isHandleDragging: Binding<Bool>,
        in range: ClosedRange<Int>,
        style: SliderStyleProtocol = DefaultSliderStyle(
            trackLeftColor: UIColor(named: "trackColor")
        )
    ) {
        self._value = value
        self._isHandleDragging = isHandleDragging
        self.closedRange = range
        self.style = style
    }

    var body: some View {
        GeometryReader { geometry in
            let geometryWidth = geometry.size.width

            let leftWidth = getTrackLeftWidth(
                sliderValue: value,
                trackWidth: geometryWidth,
                range: closedRange
            )
            let rightWidth = getTrackRightWidth(
                sliderValue: value,
                trackWidth: geometryWidth,
                range: closedRange
            )

            ZStack(alignment: .leading) {
                ZStack(alignment: .leading) {
                    style.track

                    style.trackLeft
                        .foregroundColor(style.trackLeftColor)
                        .frame(width: leftWidth)

                    style.trackRight
                        .foregroundColor(style.trackRightColor)
                        .offset(x: leftWidth)
                        .frame(width: rightWidth)
                }
                .frame(height: style.trackThickness)
                .cornerRadius(style.trackCornerRadius)
                .overlay(
                    RoundedRectangle(
                        cornerRadius: style.trackCornerRadius
                    )
                    .strokeBorder(style.trackBorderColor, lineWidth: style.trackBorderWidth)
                    .foregroundColor(.clear)
                )

                style.thumb
                    .frame(width: style.thumbThickness, height: style.thumbThickness)
                    .cornerRadius(style.thumbCornerRadius)
                    .foregroundColor(style.thumbColor)
                    .shadow(
                        color: style.thumbShadowColor,
                        radius: style.thumbShadowRadius,
                        x: style.thumbShadowX,
                        y: style.thumbShadowY
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: style.thumbCornerRadius)
                            .strokeBorder(
                                style.thumbBorderColor,
                                lineWidth: style.thumbBorderWidth
                            )
                    )
                    .offset(x: convertToPositionX(
                        sliderValue: value,
                        width: geometryWidth,
                        range: closedRange
                    ))
                    .gesture(
                        DragGesture()
                            .onChanged { dragGestureValue in
                                if !isDragging {
                                    isDragging = true
                                    isHandleDragging = true
                                }
                                dragging(
                                    geometry: geometry,
                                    dragGestureValue: dragGestureValue,
                                    sliderValue: value,
                                    didChange: { resultValue in
                                        value = resultValue
                                    }
                                )
                            }
                            .onEnded { _ in
                                isDragging = false
                                knobOffsetX = nil
                                isHandleDragging = false
                            }
                    )
            }
        }
        .frame(height: style.height)
    }
}

extension IntSlider {
    private func dragging(
        geometry: GeometryProxy,
        dragGestureValue: DragGesture.Value,
        sliderValue: Int,
        didChange: (Int) -> Void
    ) {
        if knobOffsetX == nil {
            let positionX = convertToPositionX(
                sliderValue: sliderValue,
                width: geometry.size.width,
                range: closedRange
            )
            knobOffsetX = dragGestureValue.startLocation.x - positionX
        }

        guard let knobOffsetX else { return }

        let availableWidth = geometry.size.width - style.thumbThickness
        let adjustedLocationX = dragGestureValue.location.x - knobOffsetX
        let relativePosition = adjustedLocationX / availableWidth

        let rangeSpan = CGFloat(closedRange.upperBound - closedRange.lowerBound)
        let calculatedValue = CGFloat(closedRange.lowerBound) + (relativePosition * rangeSpan)
        let clampedValue = min(closedRange.upperBound, max(closedRange.lowerBound, Int(calculatedValue)))

        didChange(clampedValue)
    }

    private func getTrackLeftWidth(
        sliderValue: Int,
        trackWidth: CGFloat,
        range: ClosedRange<Int>
    ) -> CGFloat {
        convertToPositionX(
            sliderValue: sliderValue,
            width: trackWidth,
            range: range
        ) + style.trackThickness * 0.5
    }

    private func getTrackRightWidth(
        sliderValue: Int,
        trackWidth: CGFloat,
        range: ClosedRange<Int>
    ) -> CGFloat {
        trackWidth - getTrackLeftWidth(sliderValue: sliderValue, trackWidth: trackWidth, range: range)
    }

    private func convertToPositionX(
        sliderValue: Int,
        width: CGFloat,
        range: ClosedRange<Int>
    ) -> CGFloat {
        let upperBound: CGFloat = CGFloat(range.upperBound)
        let lowerBound: CGFloat = CGFloat(range.lowerBound)
        let value: CGFloat = CGFloat(sliderValue)
        let ratio = ((value - lowerBound) / (upperBound - lowerBound))
        return max(0.0, (width - style.thumbThickness) * ratio)
    }
}

#Preview {
    PreviewView()
}

private struct PreviewView: View {

    @State var alphaArray: [Int] = [25, 125, 225]
    @State var isPressedArray: [Bool] = [false, false, false]

    var body: some View {
        ForEach(alphaArray.indices, id: \.self) { index in
            IntSlider(
                value: $alphaArray[index],
                isHandleDragging: $isPressedArray[index],
                in: 0...255
            )
            .padding()
        }
    }
}
