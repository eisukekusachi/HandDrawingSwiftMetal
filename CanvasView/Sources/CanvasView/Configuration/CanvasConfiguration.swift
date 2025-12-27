//
//  CanvasConfiguration.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/09/06.
//

import Foundation
import UIKit

@MainActor
public struct CanvasConfiguration {
    let textureSize: CGSize
    let projectConfiguration: ProjectConfiguration
    let environmentConfiguration: EnvironmentConfiguration

    public init(
        textureSize: CGSize? = nil,
        projectConfiguration: ProjectConfiguration = .init(),
        environmentConfiguration: EnvironmentConfiguration = .init()
    ) {
        self.textureSize = textureSize ?? CanvasView.defaultTextureSize
        self.projectConfiguration = projectConfiguration
        self.environmentConfiguration = environmentConfiguration
    }
}
