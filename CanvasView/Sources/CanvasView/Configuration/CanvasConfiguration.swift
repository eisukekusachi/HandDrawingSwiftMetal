//
//  CanvasConfiguration.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/09/06.
//

import Foundation

public struct CanvasConfiguration {
    let projectConfiguration: ProjectConfiguration
    let environmentConfiguration: EnvironmentConfiguration

    public init(
        projectConfiguration: ProjectConfiguration,
        environmentConfiguration: EnvironmentConfiguration
    ) {
        self.projectConfiguration = projectConfiguration
        self.environmentConfiguration = environmentConfiguration
    }
}
