//
//  ViewSize.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/09/06.
//

import Foundation

enum ViewSize {

    static func getScaleToFit(_ source: CGSize, to destination: CGSize) -> CGFloat {
        let widthRatio = destination.width / source.width
        let heightRatio = destination.height / source.height

        return min(widthRatio, heightRatio)
    }

    static func getScaleToFill(_ source: CGSize, to destination: CGSize) -> CGFloat {
        let widthRatio = destination.width / source.width
        let heightRatio = destination.height / source.height

        return max(widthRatio, heightRatio)
    }

    static func convertScreenMatrixToTextureMatrix(
        matrix: CGAffineTransform,
        drawableSize: CGSize,
        textureSize: CGSize,
        frameSize: CGSize
    ) -> CGAffineTransform {

        let drawableScale = ViewSize.getScaleToFit(textureSize, to: drawableSize)
        let drawableTextureSize: CGSize = .init(
            width: textureSize.width * drawableScale,
            height: textureSize.height * drawableScale
        )

        let frameToTextureFitScale = ViewSize.getScaleToFit(frameSize, to: textureSize)
        let drawableTextureToDrawableFillScale = ViewSize.getScaleToFill(drawableTextureSize, to: drawableSize)

        var matrix = matrix
        matrix.tx *= (frameToTextureFitScale * drawableTextureToDrawableFillScale)
        matrix.ty *= (frameToTextureFitScale * drawableTextureToDrawableFillScale)
        return matrix
    }

    static func convertScreenLocationToTextureLocation(
        touchLocation: CGPoint,
        frameSize: CGSize,
        drawableSize: CGSize,
        textureSize: CGSize
    ) -> CGPoint {
        if textureSize != drawableSize {
            let drawableToTextureFillScale = ViewSize.getScaleToFill(drawableSize, to: textureSize)
            let drawableLocation: CGPoint = .init(
                x: touchLocation.x * (drawableSize.width / frameSize.width),
                y: touchLocation.y * (drawableSize.width / frameSize.width)
            )
            return .init(
                x: drawableLocation.x * drawableToTextureFillScale + (textureSize.width - drawableSize.width * drawableToTextureFillScale) * 0.5,
                y: drawableLocation.y * drawableToTextureFillScale + (textureSize.height - drawableSize.height * drawableToTextureFillScale) * 0.5
            )
        } else {
            return .init(
                x: touchLocation.x * (textureSize.width / frameSize.width),
                y: touchLocation.y * (textureSize.width / frameSize.width)
            )
        }
    }

}
