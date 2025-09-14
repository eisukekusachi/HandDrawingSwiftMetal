//
//  ProjectConfiguration.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/09/14.
//

import Foundation

public struct ProjectConfiguration {

    let projectName: String
    let createdAt: Date?
    let updatedAt: Date?

    public init(
        projectName: String = Calendar.currentDate,
        createdAt: Date? = Date(),
        updatedAt: Date? = Date()
    ) {
        self.projectName = projectName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
