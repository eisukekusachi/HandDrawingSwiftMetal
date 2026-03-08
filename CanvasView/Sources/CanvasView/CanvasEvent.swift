//
//  CanvasEvent.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2026/03/07.
//

import Foundation

/// Events emitted by the canvas to notify about rendering updates or state changes
public enum CanvasEvent {

    /// Indicates that the canvas has been created
    case canvasCreated(CGSize)

    /// Indicates that the current texture should be displayed
    case displayCurrentTexture

    /// Indicates that the realtime drawing texture should be displayed
    case displayRealtimeDrawingTexture
}
