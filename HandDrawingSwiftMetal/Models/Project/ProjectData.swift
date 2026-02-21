//
//  ProjectData.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/01/23.
//

import Foundation

public final class ProjectData {

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

    func update(
        projectName: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        if let projectName {
            self.projectName = projectName
        }
        if let createdAt {
            self.createdAt = createdAt
        }
        if let updatedAt {
            self.updatedAt = updatedAt
        }
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
