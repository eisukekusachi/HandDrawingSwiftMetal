//
//  DefaultCanvasGrayscaleTexturePointIterator.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/28.
//

import UIKit

final class DefaultCanvasGrayscaleTexturePointIterator: CanvasGrayscaleTexturePointIterator {
    var iterator = Iterator<GrayscaleTexturePoint>()

    // TODO: Delete it once actual values are used instead of estimated ones.
    private var tmpBrightness: CGFloat?
    private var startDrawing: Bool = false
    private var stopProcessing: Bool = false

}

extension DefaultCanvasGrayscaleTexturePointIterator {

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

    func reset() {
        iterator.clear()

        // TODO: Delete it once actual values are used instead of estimated ones.
        tmpBrightness = nil
        startDrawing = false
        stopProcessing = false
    }

}

extension DefaultCanvasGrayscaleTexturePointIterator {

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
