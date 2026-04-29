//
//  ProjectData.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/01/23.
//

import Foundation

final class ProjectData {

    @Published public var currentProjectName: String
    @Published public var createdAt: Date
    @Published public var updatedAt: Date

    init(
        projectName: String = Calendar.currentDate,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.currentProjectName = projectName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func update(
        projectName: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        if let projectName {
            self.currentProjectName = projectName
        }
        if let createdAt {
            self.createdAt = createdAt
        }
        if let updatedAt {
            self.updatedAt = updatedAt
        }
    }

    func updateAll(newProjectName: String) {
        self.currentProjectName = newProjectName
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    func updateUpdatedAt() {
        self.updatedAt = Date()
    }
}
