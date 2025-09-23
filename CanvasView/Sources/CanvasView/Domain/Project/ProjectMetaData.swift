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

    var zipFileURL: URL {
        FileManager.documentsFileURL(
            projectName: projectName,
            suffix: ProjectMetaData.fileSuffix
        )
    }

    public static var fileSuffix: String {
        "zip"
    }

    public init(
        projectName: String = Calendar.currentDate,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.projectName = projectName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public func refresh(_ projectName: String = Calendar.currentDate) {
        self.projectName = projectName
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    public func refreshUpdatedAt() {
        self.updatedAt = Date()
    }
}
