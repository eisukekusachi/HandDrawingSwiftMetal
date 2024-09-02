//
//  CanvasTouchPoint.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2022/11/19.
//

import UIKit

struct CanvasTouchPoint: Equatable {

    let location: CGPoint
    let force: CGFloat
    let maximumPossibleForce: CGFloat
    let phase: UITouch.Phase
    let type: UITouch.TouchType

}

extension CanvasTouchPoint {

    init(
        touch: UITouch,
        view: UIView
    ) {
        self.location = touch.preciseLocation(in: view)
        self.force = touch.force
        self.maximumPossibleForce = touch.maximumPossibleForce
        self.phase = touch.phase
        self.type = touch.type
    }

}

extension CanvasTouchPoint {

    func convertLocationToTextureScaleAndApplyMatrix(
        matrix: CGAffineTransform,
        frameSize: CGSize,
        drawableSize: CGSize,
        textureSize: CGSize
    ) -> Self {
        // Calculate the matrix.
        let drawableScale = ScaleManager.getAspectFitFactor(
            sourceSize: textureSize,
            destinationSize: drawableSize
        )
        let adjustmentScaleFactor = max(
            drawableSize.width / (textureSize.width * drawableScale),
            drawableSize.height / (textureSize.height * drawableScale)
        )
        let offsetScale = ScaleManager.getAspectFitFactor(
            sourceSize: frameSize,
            destinationSize: textureSize
        )
        var inverseMatrix = matrix.inverted(flipY: true)
        inverseMatrix.tx *= (offsetScale * adjustmentScaleFactor)
        inverseMatrix.ty *= (offsetScale * adjustmentScaleFactor)

        // Calculate the location.
        let aspectFitFactor = ScaleManager.getAspectFitFactor(
            sourceSize: frameSize,
            destinationSize: drawableSize
        )
        var locationOnTexture: CGPoint = .init(
            x: location.x * aspectFitFactor,
            y: location.y * aspectFitFactor
        )
        if textureSize != drawableSize {
            let aspectFillFactor = ScaleManager.getAspectFillFactor(
                sourceSize: drawableSize,
                destinationSize: textureSize
            )
            locationOnTexture = .init(
                x: locationOnTexture.x * aspectFillFactor + (textureSize.width - drawableSize.width * aspectFillFactor) * 0.5,
                y: locationOnTexture.y * aspectFillFactor + (textureSize.height - drawableSize.height * aspectFillFactor) * 0.5
            )
        }

        return .init(
            location: locationOnTexture.apply(
                with: inverseMatrix,
                textureSize: textureSize
            ),
            force: force,
            maximumPossibleForce: maximumPossibleForce,
            phase: phase,
            type: type
        )
    }

}

extension Dictionary where Key: Hashable, Value == [CanvasTouchPoint] {

    func containsPhases(
        _ phases: [UITouch.Phase]
    ) -> Bool {
        for key in self.keys {
            guard let points = self[key] else {
                continue
            }
            for point in points {
                if phases.contains(point.phase) {
                    return true
                }
            }
        }
        return false
    }

}
