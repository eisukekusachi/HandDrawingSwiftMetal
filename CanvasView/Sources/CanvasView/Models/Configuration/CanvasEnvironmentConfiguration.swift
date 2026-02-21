//
//  EnvironmentConfiguration.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/07/28.
//

import UIKit

public struct EnvironmentConfiguration: Sendable {
    /// The background color of the canvas
    let backgroundColor: UIColor

    /// The base background color of the canvas. this color that appears when the canvas is rotated or moved.
    let baseBackgroundColor: UIColor

    /// The duration in seconds that must pass to recognize a drawing gesture
    let drawingGestureRecognitionSecond: TimeInterval

    /// The duration in seconds that must pass to recognize a transforming gesture
    let transformingGestureRecognitionSecond: TimeInterval

    public init(
        backgroundColor: UIColor = .white,
        baseBackgroundColor: UIColor = UIColor(230, 230, 230),
        drawingGestureRecognitionSecond: TimeInterval = 0.1,
        transformingGestureRecognitionSecond: TimeInterval = 0.05
    ) {
        self.backgroundColor = backgroundColor
        self.baseBackgroundColor = baseBackgroundColor
        self.drawingGestureRecognitionSecond = drawingGestureRecognitionSecond
        self.transformingGestureRecognitionSecond = transformingGestureRecognitionSecond
    }
}
