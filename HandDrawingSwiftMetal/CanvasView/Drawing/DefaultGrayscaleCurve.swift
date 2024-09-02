//
//  DefaultGrayscaleCurve.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/28.
//

import UIKit

final class DefaultGrayscaleCurve: GrayscaleCurve {
    var iterator = Iterator<GrayscaleTexturePoint>()

    var currentDictionaryKey: TouchHashValue?

    var startAfterPoint: TouchPoint?

    // TODO: Delete it once actual values are used instead of estimated ones.
    private var tmpBrightness: CGFloat?
    private var startDrawing: Bool = false
    private var stopProcessing: Bool = false

    func reset() {
        iterator.clear()

        startAfterPoint = nil
        currentDictionaryKey = nil

        // TODO: Delete it once actual values are used instead of estimated ones.
        tmpBrightness = nil
        startDrawing = false
        stopProcessing = false
    }

}

extension DefaultGrayscaleCurve {

    func appendToIterator(
        points: [GrayscaleTexturePoint],
        touchPhase: UITouch.Phase
    ) {
        iterator.append(points)

        // TODO: Delete it once actual values are used instead of estimated ones.
        if !stopProcessing {
            setInaccurateAlphaToZero()
        }
    }

}

extension DefaultGrayscaleCurve {

    // TODO: Delete it once actual values are used instead of estimated ones. This process is almost meaningless.
    func setInaccurateAlphaToZero() {
        if tmpBrightness == nil {
            tmpBrightness = iterator.array.first?.brightness
        }

        if let tmpBrightness {

            var index: Int = 0
            while index < iterator.array.count - 1 {
                if !startDrawing && iterator.array[index].brightness != iterator.array[index + 1].brightness {
                    iterator.replace(
                        index: index,
                        element: .init(
                            location: iterator.array[index].location,
                            diameter: iterator.array[index].diameter,
                            brightness: 0.0
                        )
                    )
                    startDrawing = true

                } else if iterator.array[index + 1].brightness == tmpBrightness {
                    iterator.replace(
                        index: index,
                        element: .init(
                            location: iterator.array[index].location,
                            diameter: iterator.array[index].diameter,
                            brightness: 0.0
                        )
                    )
                    stopProcessing = true
                }

                index += 1
            }
        }
    }

}
