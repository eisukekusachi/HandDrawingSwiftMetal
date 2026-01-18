//
//  ProjectMetaData.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/09/21.
//

import Foundation

public final class ProjectMetaData: ProjectMetaDataProtocol {

    @Published public var projectName: String
    @Published public var createdAt: Date
    @Published public var updatedAt: Date

    public init(
        projectName: String = Calendar.currentDate,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.projectName = projectName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(
        model: ProjectMetaDataArchiveModel
    ) {
        self.projectName = model.projectName
        self.createdAt = model.createdAt
        self.updatedAt = model.updatedAt
    }

    public func updateAll(newProjectName: String) {
        self.projectName = newProjectName
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    public func updateUpdatedAt() {
        self.updatedAt = Date()
    }
}
