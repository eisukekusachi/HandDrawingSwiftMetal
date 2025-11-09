//
//  ProjectMetaDataArchiveModel.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/09/22.
//

import Foundation

public struct ProjectMetaDataArchiveModel: Codable, Sendable {

    let projectName: String
    let createdAt: Date
    let updatedAt: Date

    public init(
        projectName: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.projectName = projectName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension ProjectMetaDataArchiveModel: LocalFileConvertible {
    public static var fileName: String { "project" }
}
