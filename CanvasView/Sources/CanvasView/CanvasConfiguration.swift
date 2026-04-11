//
//  CanvasConfiguration.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/09/06.
//

import UIKit

@MainActor
public struct CanvasConfiguration {

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
        textureSize: CGSize? = nil,
        backgroundColor: UIColor = .white,
        baseBackgroundColor: UIColor = UIColor(230, 230, 230),
        drawingGestureRecognitionSecond: TimeInterval = 0.1,
        transformingGestureRecognitionSecond: TimeInterval = 0.05
    ) {
        // The screen size is used when the value is nil
        self.textureSize = textureSize ?? Self.screenSize
        self.backgroundColor = backgroundColor
        self.baseBackgroundColor = baseBackgroundColor
        self.drawingGestureRecognitionSecond = drawingGestureRecognitionSecond
        self.transformingGestureRecognitionSecond = transformingGestureRecognitionSecond
    }

    public func newTextureSize(_ textureSize: CGSize) -> Self {
        .init(
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
