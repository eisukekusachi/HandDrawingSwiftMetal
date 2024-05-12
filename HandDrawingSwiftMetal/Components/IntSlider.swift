//
//  IntSlider.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/01/02.
//

import SwiftUI

struct IntSlider: View {
    @Environment(\.sliderStyle) var style
    @State private var knobOffsetX: CGFloat?

    private var value: Int
    private let closedRange: ClosedRange<Int>
    private let didChange: ((Int) -> Void)?

    init(
        value: Int,
        in range: ClosedRange<Int>,
        didChange: ((Int) -> Void)? = nil
    ) {
        self.value = value
        self.closedRange = range
        self.didChange = didChange
    }

    var body: some View {
        GeometryReader { geometry in
            let geometryWidth = geometry.size.width
            let leftWidth = getTrackLeftWidth(sliderValue: value, trackWidth: geometryWidth, range: closedRange)
            let rightWidth = getTrackRightWidth(sliderValue: value, trackWidth: geometryWidth, range: closedRange)

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
                    RoundedRectangle(cornerRadius: style.trackCornerRadius)
                        .strokeBorder(style.trackBorderColor, lineWidth: style.trackBorderWidth)
                        .foregroundColor(.clear)
                )

                style.thumb
                    .frame(width: style.thumbThickness, height: style.thumbThickness)
                    .cornerRadius(style.thumbCornerRadius)
                    .foregroundColor(style.thumbColor)
                    .shadow(color: style.thumbShadowColor,
                            radius: style.thumbShadowRadius,
                            x: style.thumbShadowX,
                            y: style.thumbShadowY)
                    .overlay(
                        RoundedRectangle(cornerRadius: style.thumbCornerRadius)
                            .strokeBorder(style.thumbBorderColor, lineWidth: style.thumbBorderWidth)
                    )
                    .offset(x: convertToPositionX(sliderValue: value,
                                                  width: geometryWidth,
                                                  range: closedRange))
                    .gesture(
                        DragGesture()
                            .onChanged { dragGestureValue in
                                dragging(
                                    geometry: geometry,
                                    dragGestureValue: dragGestureValue,
                                    sliderValue: value,
                                    didChange: { value in
                                        didChange?(Int(value))
                                    }
                                )
                            }
                            .onEnded { _ in
                                knobOffsetX = nil
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
            let positionX = convertToPositionX(sliderValue: sliderValue,
                                               width: geometry.size.width,
                                               range: closedRange)
            knobOffsetX = dragGestureValue.startLocation.x - positionX
        }

        let relativeValue: CGFloat = (dragGestureValue.location.x - (knobOffsetX ?? 0)) / (geometry.size.width - style.thumbThickness)
        let newValue = Int(CGFloat(closedRange.lowerBound) + (relativeValue * CGFloat(closedRange.upperBound - closedRange.lowerBound)))

        didChange(min(closedRange.upperBound, max(closedRange.lowerBound, newValue)))
    }

    private func getTrackLeftWidth(sliderValue: Int, trackWidth: CGFloat, range: ClosedRange<Int>) -> CGFloat {
        convertToPositionX(sliderValue: sliderValue,
                           width: trackWidth,
                           range: range) + style.trackThickness * 0.5
    }

    private func getTrackRightWidth(sliderValue: Int, trackWidth: CGFloat, range: ClosedRange<Int>) -> CGFloat {
        trackWidth - getTrackLeftWidth(sliderValue: sliderValue, trackWidth: trackWidth, range: range)
    }

    private func convertToPositionX(sliderValue: Int, width: CGFloat, range: ClosedRange<Int>) -> CGFloat {
        let upperBound: CGFloat = CGFloat(range.upperBound)
        let lowerBound: CGFloat = CGFloat(range.lowerBound)
        let value: CGFloat = CGFloat(sliderValue)
        let ratio = ((value - lowerBound) / (upperBound - lowerBound))
        return max(0.0, (width - style.thumbThickness) * ratio)
    }
}

#Preview {

    var alpha: Int = 125
    return IntSlider(value: alpha, in: 0 ... 255)

}
