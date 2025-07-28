//
//  GrayscaleDotPoint.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/28.
//

import UIKit

@MainActor
struct GrayscaleDotPoint: DotPoint {

    let location: CGPoint
    let diameter: CGFloat

    /// Grayscale brightness (0.0 ~ 1.0)
    let brightness: CGFloat

    var blurSize: CGFloat = 2.0
}

extension GrayscaleDotPoint {

    @MainActor
    init(
        touchPoint: TouchPoint,
        diameter: CGFloat
    ) {
        self.location = touchPoint.location
        self.diameter = diameter
        self.brightness = touchPoint.maximumPossibleForce != 0 ? min(touchPoint.force, 1.0) : 1.0
    }

    @MainActor
    init(
        matrix: CGAffineTransform,
        touchPoint: TouchPoint,
        textureSize: CGSize,
        drawableSize: CGSize,
        frameSize: CGSize,
        diameter: CGFloat
    ) {
        let textureMatrix = ViewSize.convertScreenMatrixToTextureMatrix(
            matrix: matrix,
            drawableSize: drawableSize,
            textureSize: textureSize,
            frameSize: frameSize
        )
        let textureLocation = ViewSize.convertScreenLocationToTextureLocation(
            touchLocation: touchPoint.location,
            frameSize: frameSize,
            drawableSize: drawableSize,
            textureSize: textureSize
        )

        let touchPoint: TouchPoint = .init(
            location: textureLocation.apply(
                with: textureMatrix,
                textureSize: textureSize
            ),
            touch: touchPoint
        )

        self.location = touchPoint.location
        self.diameter = diameter
        self.brightness = touchPoint.maximumPossibleForce != 0 ? min(touchPoint.force, 1.0) : 1.0
    }
}

extension GrayscaleDotPoint {

    static func average(_ left: Self, _ right: Self) -> Self {
        .init(
            location: left.location == right.location ? left.location : CGPoint(
                x: (left.location.x + right.location.x) * 0.5,
                y: (left.location.y + right.location.y) * 0.5
            ),
            diameter: left.diameter == right.diameter ? left.diameter : (left.diameter + right.diameter) * 0.5,
            brightness: left.brightness == right.brightness ? left.brightness : (left.brightness + right.brightness) * 0.5
        )
    }

    /// Interpolates the values to match the number of elements in `targetPoints` array with that of the other elements array
    static func interpolateToMatchPointCount(
        targetPoints: [CGPoint],
        interpolationStart: Self,
        interpolationEnd: Self,
        shouldIncludeEndPoint: Bool
    ) -> [Self] {
        var curve: [Self] = []

        var numberOfInterpolations = targetPoints.count

        if shouldIncludeEndPoint {
            // Subtract 1 from `numberOfInterpolations` because the last point will be added to the arrays
            numberOfInterpolations = numberOfInterpolations - 1
        }

        let brightnessArray = Interpolator.getLinearInterpolationValues(
            begin: interpolationStart.brightness,
            change: interpolationEnd.brightness,
            duration: numberOfInterpolations,
            shouldIncludeEndPoint: shouldIncludeEndPoint
        )

        let diameterArray = Interpolator.getLinearInterpolationValues(
            begin: interpolationStart.diameter,
            change: interpolationEnd.diameter,
            duration: numberOfInterpolations,
            shouldIncludeEndPoint: shouldIncludeEndPoint
        )

        let blurArray = Interpolator.getLinearInterpolationValues(
            begin: interpolationStart.blurSize,
            change: interpolationEnd.blurSize,
            duration: numberOfInterpolations,
            shouldIncludeEndPoint: shouldIncludeEndPoint
        )

        for i in 0 ..< targetPoints.count {
            curve.append(
                .init(
                    location: targetPoints[i],
                    diameter: diameterArray[i],
                    brightness: brightnessArray[i],
                    blurSize: blurArray[i]
                )
            )
        }

        return curve
    }

}
