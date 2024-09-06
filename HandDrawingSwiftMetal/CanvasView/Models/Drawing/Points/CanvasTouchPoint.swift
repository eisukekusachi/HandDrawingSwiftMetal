//
//  CanvasTouchPoint.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2022/11/19.
//

import UIKit

struct CanvasTouchPoint: Equatable {

    let location: CGPoint
    let phase: UITouch.Phase
    let force: CGFloat
    let maximumPossibleForce: CGFloat
    /// Index for identifying the estimated value
    var estimationUpdateIndex: NSNumber? = nil

    let timestamp: TimeInterval
}

extension CanvasTouchPoint {

    init(
        touch: UITouch,
        view: UIView
    ) {
        self.location = touch.preciseLocation(in: view)
        self.phase = touch.phase
        self.force = touch.force
        self.maximumPossibleForce = touch.maximumPossibleForce
        self.estimationUpdateIndex = touch.estimationUpdateIndex
        self.timestamp = touch.timestamp
    }

}

extension CanvasTouchPoint {

    func convertToTextureCoordinatesAndApplyMatrix(
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
            phase: phase,
            force: force,
            maximumPossibleForce: maximumPossibleForce,
            estimationUpdateIndex: estimationUpdateIndex,
            timestamp: timestamp
        )
    }

}

extension Array where Element == CanvasTouchPoint {

    var currentTouchPhase: UITouch.Phase {
        if self.last?.phase == .cancelled {
            .cancelled
        } else if self.last?.phase == .ended {
            .ended
        } else if self.first?.phase == .began {
            .began
        } else {
            .moved
        }
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
