//
//  ProjectConfiguration.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/09/06.
//

import Foundation

public struct ProjectConfiguration {
    let canvasConfiguration: CanvasConfiguration
    let environmentConfiguration: EnvironmentConfiguration

    public init(
        canvasConfiguration: CanvasConfiguration = .init(),
        environmentConfiguration: EnvironmentConfiguration = .init()
    ) {
        self.canvasConfiguration = canvasConfiguration
        self.environmentConfiguration = environmentConfiguration
    }
}
