//
//  CanvasConfiguration.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/09/06.
//

import UIKit

@MainActor
public struct CanvasConfiguration {

    public let textureMinimumLength: Int

    public let textureSize: CGSize

    /// The background color of the canvas
    let backgroundColor: UIColor

    /// The base background color of the canvas. this color that appears when the canvas is rotated or moved.
    let baseBackgroundColor: UIColor

    /// The duration in seconds that must pass to recognize a drawing gesture
    let drawingGestureRecognitionSecond: TimeInterval

    /// The duration in seconds that must pass to recognize a transforming gesture
    let transformingGestureRecognitionSecond: TimeInterval

    public init(
        textureMinimumLength: Int = 16,
        textureSize: CGSize? = nil,
        backgroundColor: UIColor = .white,
        baseBackgroundColor: UIColor = UIColor(230, 230, 230),
        drawingGestureRecognitionSecond: TimeInterval = 0.1,
        transformingGestureRecognitionSecond: TimeInterval = 0.05
    ) {
        let resolvedTextureMinimumLength = max(textureMinimumLength, 16)
        let sourceTextureSize = textureSize ?? Self.screenSize
        self.textureMinimumLength = resolvedTextureMinimumLength
        self.textureSize = CGSize(
            width: max(Int(sourceTextureSize.width), resolvedTextureMinimumLength),
            height: max(Int(sourceTextureSize.height), resolvedTextureMinimumLength)
        )
        self.backgroundColor = backgroundColor
        self.baseBackgroundColor = baseBackgroundColor
        self.drawingGestureRecognitionSecond = drawingGestureRecognitionSecond
        self.transformingGestureRecognitionSecond = transformingGestureRecognitionSecond
    }

    public func newTextureSize(_ textureSize: CGSize) -> Self {
        .init(
            textureMinimumLength: textureMinimumLength,
            textureSize: textureSize,
            backgroundColor: backgroundColor,
            baseBackgroundColor: baseBackgroundColor,
            drawingGestureRecognitionSecond: drawingGestureRecognitionSecond,
            transformingGestureRecognitionSecond: transformingGestureRecognitionSecond
        )
    }

    /// The size of the screen
    public static var screenSize: CGSize {
        let scale = UIScreen.main.scale
        let size = UIScreen.main.bounds.size
        return .init(
            width: size.width * scale,
            height: size.height * scale
        )
    }
}
